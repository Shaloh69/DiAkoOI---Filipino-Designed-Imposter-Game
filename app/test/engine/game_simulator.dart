import 'package:diakooi/engine/engine.dart';

/// Drives full games through the engine so the A1 properties can be asserted
/// over many seeds rather than a handful of hand-built rounds.
///
/// Everything it does goes through the public engine API and the injected
/// [SeededRng]. It adds no rules of its own beyond standing in for the players
/// and the host — which is exactly the part a unit test cannot supply.
///
/// **Interference is rolled by [InterferenceRoller], the production code.**
/// It used to be rolled by a copy living here, which meant the A1 properties
/// were asserted against the simulator's idea of §9 rather than the app's. A
/// simulation that reimplements what it is testing proves only that the copy
/// agrees with itself.

/// One simulated game.
class SimulatedGame {
  SimulatedGame({
    required this.rounds,
    required this.players,
    required this.transcript,
    required this.perRoundDeltas,
    required this.suddenDeathRounds,
    required this.roundModifiers,
    required this.playerPickEvents,
  });

  final List<Round> rounds;
  final List<Player> players;

  /// A stable, human-readable record of everything that happened. Two runs of
  /// the same seed must produce byte-identical transcripts (A1).
  final String transcript;

  /// Life deltas per round, in round order.
  final List<List<LifeDelta>> perRoundDeltas;

  /// Indices of rounds where Sudden Death was the modifier — the sole
  /// legitimate way to lose more than 2 lives (§7b).
  final Set<int> suddenDeathRounds;

  /// The §9c modifier each round drew, null where nothing fired.
  final List<String?> roundModifiers;

  /// The §9b events each round landed, in round order.
  final List<List<PlayerPickEvent>> playerPickEvents;

  /// Lives at the end. Named so a test does not have to know that [players]
  /// is already the final state.
  List<Player> get finalPlayers => players;
}

/// Simulates a whole game.
///
/// `forcedRoundModifiers` lets a test pin specific §9c modifiers; left null,
/// modifiers are rolled from the enabled pool.
SimulatedGame simulateGame({
  required int seed,
  required RoomSettings settings,
  required List<WordBankEntry> bank,
  List<String>? forcedRoundModifiers,
}) {
  final rng = SeededRng(seed);
  var players = [
    for (var i = 0; i < settings.playerCount; i++)
      Player(
        id: 'p$i',
        name: 'P$i',
        seatOrder: i,
        currentLives: settings.livesPerPlayer,
      ),
  ];

  final mayorId = rng.pick(players).id;
  final buffer = StringBuffer()
    ..writeln('seed=$seed players=${settings.playerCount} mayor=$mayorId');

  final rounds = <Round>[];
  final perRoundDeltas = <List<LifeDelta>>[];
  final suddenDeathRounds = <int>{};
  final roundModifiers = <String?>[];
  final playerPickEvents = <List<PlayerPickEvent>>[];
  final usedWords = <String>[];
  final topicHistory = <String>[];

  for (var roundIndex = 0; roundIndex < settings.totalRounds; roundIndex++) {
    final topicId = TopicSelector.draw(
      settings: settings,
      topicHistory: topicHistory,
      rng: rng,
    );
    topicHistory.add(topicId);

    final entry = WordSelector.draw(
      topicId: topicId,
      bank: bank,
      usedWords: usedWords,
      rng: rng,
    );
    usedWords.add(entry.word);

    // §9c phase one, through the production roller. `forcedRoundModifiers`
    // still pins a modifier for tests that need one specific event.
    final modifier =
        forcedRoundModifiers != null &&
            GameMachine.interferenceAllowed(
              roundIndex: roundIndex,
              settings: settings,
            )
        ? forcedRoundModifiers[roundIndex % forcedRoundModifiers.length]
        : InterferenceRoller.rollModifier(
            settings: settings,
            roundIndex: roundIndex,
            rng: rng,
          );
    if (modifier == InterferenceCatalogue.suddenDeath) {
      suddenDeathRounds.add(roundIndex);
    }
    roundModifiers.add(modifier);

    final imposters = ImposterAssigner.assign(
      players: players,
      count: InterferenceRoller.imposterCountFor(
        settings: settings,
        roundModifier: modifier,
      ),
      rng: rng,
    );

    // §9c phase two: everything that needs to know the roles.
    final roll = InterferenceRoller.rollDetails(
      settings: settings,
      players: players,
      imposterIds: imposters,
      roundIndex: roundIndex,
      roundModifier: modifier,
      rng: rng,
      tabooWordPool: [
        for (final e in bank)
          if (e.topicId == topicId) e.word,
      ],
    );
    playerPickEvents.add(roll.playerPickEvents);

    final clue = WordSelector.clueFor(entry: entry, settings: settings);

    final round = Round(
      id: 'r$roundIndex',
      roundIndex: roundIndex,
      startingPlayerIndex: TurnOrder.startingIndex(
        roundIndex: roundIndex,
        playerCount: settings.playerCount,
      ),
      topicId: topicId,
      word: entry.word,
      imposterClue: clue.clue,
      clueTierUsed: clue.tier,
      imposterPlayerIds: imposters,
      roundModifier: modifier,
      roundaboutsRequired: switch (modifier) {
        InterferenceCatalogue.noRoundabouts => 0,
        InterferenceCatalogue.extraRoundabout =>
          settings.effectiveRoundabouts + 1,
        _ => settings.effectiveRoundabouts,
      },
    );

    // Stand in for the table: everyone names somebody who is not themselves.
    final votes = <Vote>[
      for (final voter in players)
        Vote(
          voterId: voter.id,
          accusedId: rng.pick([
            for (final other in players)
              if (other.id != voter.id) other,
          ]).id,
        ),
    ];

    // A slice of Taboo players are adjudicated as having slipped, so the
    // retroactive path is exercised rather than always coming back Clean.
    final tabooSlips = [
      for (final id in roll.tabooWords.keys)
        if (rng.nextDouble() < 0.5) id,
    ];

    final resolution = resolveRound(
      votes: votes,
      roles: {for (final p in players) p.id: round.roleOf(p.id)},
      modifiers: RoundModifiers(
        roundModifier: modifier,
        playerPickEvents: roll.playerPickEvents,
        bodyguardPlayerId: roll.bodyguardPlayerId,
        tabooSlips: tabooSlips,
        stealTargets: roll.stealTargets,
      ),
      itemUsages: const [],
      currentLives: {for (final p in players) p.id: p.currentLives},
      mayorPlayerId: mayorId,
    );

    final check = LifeCheck.apply(
      players: players,
      resolution: resolution,
      settings: settings,
      roundModifier: modifier,
    );
    players = check.players;

    // Serve any forfeits immediately, restoring to 1 once all are served (§8).
    for (final forfeit in check.pendingForfeits) {
      final index = players.indexWhere((p) => p.id == forfeit.playerId);
      for (var n = forfeit.count; n > 0; n--) {
        players[index] = LifeCheck.serveForfeit(
          player: players[index],
          roundIndex: roundIndex,
          description: 'forfeit',
          servedAt: DateTime.utc(2026),
          remainingAfterThis: n - 1,
        );
      }
    }

    rounds.add(round.copyWith(votes: votes, resolution: resolution));
    perRoundDeltas.add(resolution.lifeDeltas);

    final deltaText = resolution.lifeDeltas
        .map((d) => '${d.playerId}:${d.delta}')
        .join(' ');

    buffer
      ..writeln(
        'r$roundIndex topic=$topicId word=${entry.word} '
        'tier=${clue.tier.name} mod=${modifier ?? '-'} '
        'imposters=${imposters.join(',')} '
        'start=${round.startingPlayerIndex}',
      )
      ..writeln(
        '  votes=${votes.map((v) => '${v.voterId}>${v.accusedId}').join(' ')}',
      )
      ..writeln(
        '  target=${resolution.targetPlayerId ?? '-'} '
        'wash=${resolution.wasWash} '
        'deltas=$deltaText '
        'capped=${resolution.cappedPlayerIds.join(',')}',
      )
      ..writeln(
        '  lives=${players.map((p) => '${p.id}=${p.currentLives}').join(' ')}',
      );
  }

  return SimulatedGame(
    rounds: rounds,
    players: players,
    transcript: buffer.toString(),
    perRoundDeltas: perRoundDeltas,
    suddenDeathRounds: suddenDeathRounds,
    roundModifiers: roundModifiers,
    playerPickEvents: playerPickEvents,
  );
}
