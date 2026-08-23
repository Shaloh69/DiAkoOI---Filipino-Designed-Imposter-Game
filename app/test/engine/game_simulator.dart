import 'package:diakooi/engine/engine.dart';

/// Drives full games through the engine so the A1 properties can be asserted
/// over many seeds rather than a handful of hand-built rounds.
///
/// Everything it does goes through the public engine API and the injected
/// [SeededRng]. It adds no rules of its own beyond standing in for the players
/// and the host — which is exactly the part a unit test cannot supply.

/// One simulated game.
class SimulatedGame {
  SimulatedGame({
    required this.rounds,
    required this.players,
    required this.transcript,
    required this.perRoundDeltas,
    required this.suddenDeathRounds,
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

    // Interference is suppressed during round 1 (§3, §9f).
    String? modifier;
    if (GameMachine.interferenceAllowed(
      roundIndex: roundIndex,
      settings: settings,
    )) {
      if (forcedRoundModifiers != null) {
        modifier =
            forcedRoundModifiers[roundIndex % forcedRoundModifiers.length];
      } else if (settings.interference.roundStartEnabled) {
        final pool = [
          for (final e in InterferenceCatalogue.roundStartEvents)
            if (settings.interference.isEventEnabled(
              e.id,
              defaultEnabled: e.defaultEnabled,
            ))
              e.id,
        ];
        if (pool.isNotEmpty) modifier = rng.pick(pool);
      }
    }
    if (modifier == InterferenceCatalogue.suddenDeath) {
      suddenDeathRounds.add(roundIndex);
    }

    final imposterCount = ImposterAssigner.countForRound(
      settings: settings,
      roundModifier: modifier,
    );
    final imposters = ImposterAssigner.assign(
      players: players,
      count: imposterCount,
      rng: rng,
    );

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
      roundaboutsRequired: settings.effectiveRoundabouts,
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

    // A player-pick event on a random player, when the toggle is on.
    final pickEvents = <PlayerPickEvent>[];
    if (settings.interference.playerPickEnabled &&
        GameMachine.interferenceAllowed(
          roundIndex: roundIndex,
          settings: settings,
        )) {
      for (final player in players) {
        if (rng.nextDouble() >= settings.interference.playerPickProbability) {
          continue;
        }
        var pool = InterferenceCatalogue.playerPickEvents;
        // §9f suppression: No Roundabouts removes every lap-dependent event.
        if (modifier == InterferenceCatalogue.noRoundabouts) {
          pool = [
            for (final e in pool)
              if (!e.requiresRoundabout) e,
          ];
        }
        pickEvents.add(
          PlayerPickEvent(playerId: player.id, eventId: rng.pick(pool).id),
        );
      }
    }

    // Steal a Life needs a victim resolved before the pure function runs.
    final steals = <String, String>{};
    for (final event in pickEvents) {
      if (event.eventId != InterferenceCatalogue.stealLife) continue;
      final candidates = [
        for (final p in players)
          if (p.id != event.playerId) p,
      ];
      if (candidates.isNotEmpty) {
        steals[event.playerId] = rng.pick(candidates).id;
      }
    }

    // Bodyguard picks a random crew member, who is never told (§9c).
    String? bodyguard;
    if (modifier == InterferenceCatalogue.bodyguard) {
      final crew = [
        for (final p in players)
          if (!imposters.contains(p.id)) p,
      ];
      if (crew.isNotEmpty) bodyguard = rng.pick(crew).id;
    }

    final resolution = resolveRound(
      votes: votes,
      roles: {for (final p in players) p.id: round.roleOf(p.id)},
      modifiers: RoundModifiers(
        roundModifier: modifier,
        playerPickEvents: pickEvents,
        bodyguardPlayerId: bodyguard,
        stealTargets: steals,
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
  );
}
