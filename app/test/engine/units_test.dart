import 'package:diakooi/engine/engine.dart';
import 'package:test/test.dart';

import 'support.dart';

/// Unit coverage for the pieces the property tests exercise only indirectly:
/// setup validation (§2), selection (§13b, §14), lives (§8) and the FSM (§3).
void main() {
  group('RoomSettings.validated (§2, §13b)', () {
    test('accepts a well-formed configuration', () {
      final settings = settingsFor(6);
      expect(settings.playerCount, 6);
      expect(settings.imposterCount, 1);
      expect(settings.largeGroupMode, isFalse);
    });

    test('derives Large Group Mode at 13 and caps roundabouts (§2a)', () {
      final small = settingsFor(12);
      expect(small.largeGroupMode, isFalse);
      expect(small.effectiveRoundabouts, 2);

      final large = settingsFor(13);
      expect(large.largeGroupMode, isTrue);
      expect(
        large.effectiveRoundabouts,
        1,
        reason: '20 players x 2 laps is 60 handoffs before voting (§2a)',
      );
    });

    test('nudges the clue tier one tighter in Large Group Mode (§14)', () {
      final small = RoomSettings.validated(
        playerCount: 6,
        topicWeights: const [
          TopicWeight(topicId: 'pagkain', weightPercent: 100),
        ],
        clueDifficulty: ClueTier.loose,
      );
      expect(small.effectiveClueTier, ClueTier.loose);

      final large = RoomSettings.validated(
        playerCount: 14,
        topicWeights: const [
          TopicWeight(topicId: 'pagkain', weightPercent: 100),
        ],
        clueDifficulty: ClueTier.loose,
      );
      expect(
        large.effectiveClueTier,
        ClueTier.standard,
        reason: 'at 12+ there is far more info on the table (§14)',
      );
    });

    test('scales the default imposter count with table size (§2)', () {
      expect(RoomSettings.defaultImposterCount(3), 1);
      expect(RoomSettings.defaultImposterCount(6), 1);
      expect(RoomSettings.defaultImposterCount(7), 2);
      expect(RoomSettings.defaultImposterCount(11), 2);
      expect(RoomSettings.defaultImposterCount(12), 3);
      expect(RoomSettings.defaultImposterCount(16), 3);
      expect(RoomSettings.defaultImposterCount(17), 4);
      expect(RoomSettings.defaultImposterCount(20), 4);
    });

    test('rejects weights that do not total 100 (§13b)', () {
      expect(
        () => RoomSettings.validated(
          playerCount: 6,
          topicWeights: const [
            TopicWeight(topicId: 'a', weightPercent: 50),
            TopicWeight(topicId: 'b', weightPercent: 30),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('rejects out-of-range setup values (§2)', () {
      List<TopicWeight> weights() => const [
        TopicWeight(topicId: 'a', weightPercent: 100),
      ];

      expect(
        () => RoomSettings.validated(playerCount: 2, topicWeights: weights()),
        throwsArgumentError,
        reason: 'below the 3-player minimum',
      );
      expect(
        () => RoomSettings.validated(playerCount: 21, topicWeights: weights()),
        throwsArgumentError,
        reason: 'above the 20-player maximum',
      );
      expect(
        () => RoomSettings.validated(
          playerCount: 6,
          topicWeights: weights(),
          livesPerPlayer: 6,
        ),
        throwsArgumentError,
      );
      expect(
        () => RoomSettings.validated(
          playerCount: 6,
          topicWeights: weights(),
          imposterCount: 6,
        ),
        throwsArgumentError,
        reason: 'must leave at least one crew member',
      );
      expect(
        () => RoomSettings.validated(
          playerCount: 6,
          topicWeights: weights(),
          roundaboutsPerRound: 4,
        ),
        throwsArgumentError,
      );
      expect(
        () => RoomSettings.validated(
          playerCount: 6,
          topicWeights: weights(),
          earlyEndConsequenceThreshold: 4,
        ),
        throwsArgumentError,
      );
      expect(
        () => RoomSettings.validated(
          playerCount: 6,
          topicWeights: const [
            TopicWeight(topicId: 'a', weightPercent: 50),
            TopicWeight(topicId: 'a', weightPercent: 50),
          ],
        ),
        throwsArgumentError,
        reason: 'duplicate topic id',
      );
    });

    test('a topic at 0% is excluded entirely (§13b)', () {
      final settings = RoomSettings.validated(
        playerCount: 6,
        topicWeights: const [
          TopicWeight(topicId: 'a', weightPercent: 100),
          TopicWeight(topicId: 'b', weightPercent: 0),
        ],
      );
      expect(settings.eligibleTopics.map((w) => w.topicId), ['a']);

      final rng = SeededRng(1);
      for (var i = 0; i < 200; i++) {
        expect(
          TopicSelector.draw(settings: settings, topicHistory: [], rng: rng),
          'a',
        );
      }
    });
  });

  group('SeededRng', () {
    test('is reproducible and does not mutate its input', () {
      final source = [1, 2, 3, 4, 5];
      final a = SeededRng(7).shuffled(source);
      final b = SeededRng(7).shuffled(source);
      expect(a, b);
      expect(source, [1, 2, 3, 4, 5]);
    });

    test('sample returns distinct elements and rejects impossible counts', () {
      final rng = SeededRng(3);
      final sample = rng.sample([1, 2, 3, 4, 5], 3);
      expect(sample, hasLength(3));
      expect(sample.toSet(), hasLength(3));
      expect(() => rng.sample([1, 2], 3), throwsArgumentError);
      expect(() => rng.sample([1, 2], -1), throwsArgumentError);
    });

    test('rejects degenerate draws rather than returning something wrong', () {
      final rng = SeededRng(0);
      expect(() => rng.nextInt(0), throwsArgumentError);
      expect(() => rng.pick<int>([]), throwsArgumentError);
    });
  });

  group('ImposterAssigner (§3)', () {
    test('assigns the requested count and always leaves crew', () {
      final players = makePlayers(8);
      final rng = SeededRng(11);
      for (var count = 1; count <= 4; count++) {
        final imposters = ImposterAssigner.assign(
          players: players,
          count: count,
          rng: rng,
        );
        expect(imposters, hasLength(count));
        expect(imposters.toSet(), hasLength(count));
        expect(imposters.length, lessThan(players.length));
      }
    });

    test('refuses a count that would leave no crew', () {
      final players = makePlayers(4);
      expect(
        () => ImposterAssigner.assign(
          players: players,
          count: 4,
          rng: SeededRng(1),
        ),
        throwsArgumentError,
      );
      expect(
        () => ImposterAssigner.assign(
          players: players,
          count: 0,
          rng: SeededRng(1),
        ),
        throwsArgumentError,
      );
    });

    test('re-rolls fresh each round rather than persisting', () {
      final players = makePlayers(10);
      final rng = SeededRng(5);
      final draws = {
        for (var round = 0; round < 40; round++)
          ImposterAssigner.assign(
            players: players,
            count: 2,
            rng: rng,
          ).join(','),
      };
      expect(
        draws.length,
        greaterThan(1),
        reason: 'the same pair every round would not be a fresh roll',
      );
    });
  });

  group('WordSelector (§13b, §14)', () {
    final bank = makeBank(['pagkain'], perTopic: 3);

    test('never draws a word already used this session', () {
      final drawn = <String>[];
      final rng = SeededRng(2);
      for (var i = 0; i < 3; i++) {
        final entry = WordSelector.draw(
          topicId: 'pagkain',
          bank: bank,
          usedWords: drawn,
          rng: rng,
        );
        expect(drawn, isNot(contains(entry.word)));
        drawn.add(entry.word);
      }
      expect(drawn.toSet(), hasLength(3));
    });

    test('throws rather than repeating when the topic is exhausted', () {
      expect(
        () => WordSelector.draw(
          topicId: 'pagkain',
          bank: bank,
          usedWords: bank.map((e) => e.word).toList(),
          rng: SeededRng(1),
        ),
        throwsStateError,
      );
    });

    test('serves the host tier, and one tighter with Reword (§9d)', () {
      final entry = bank.first;
      final settings = RoomSettings.validated(
        playerCount: 6,
        topicWeights: const [
          TopicWeight(topicId: 'pagkain', weightPercent: 100),
        ],
        clueDifficulty: ClueTier.loose,
      );

      final plain = WordSelector.clueFor(entry: entry, settings: settings);
      expect(plain.tier, ClueTier.loose);
      expect(plain.clue, entry.clues.loose);

      final reworded = WordSelector.clueFor(
        entry: entry,
        settings: settings,
        rewordUsed: true,
      );
      expect(reworded.tier, ClueTier.standard);
      expect(reworded.clue, entry.clues.standard);
    });

    test('tightening a tight clue stays tight rather than throwing', () {
      expect(ClueTier.tight.oneTighter, ClueTier.tight);
      expect(ClueTier.standard.oneTighter, ClueTier.tight);
      expect(ClueTier.loose.oneTighter, ClueTier.standard);
    });
  });

  group('TurnOrder (§6a)', () {
    test('the starting seat rotates every round', () {
      for (var round = 0; round < 12; round++) {
        expect(
          TurnOrder.startingIndex(roundIndex: round, playerCount: 5),
          round % 5,
        );
      }
    });

    test('a lap visits every seat exactly once', () {
      final order = TurnOrder.lapOrder(
        roundIndex: 3,
        lapIndex: 1,
        playerCount: 6,
      );
      expect(order, hasLength(6));
      expect(order.toSet(), hasLength(6));
    });

    test('Reverse Order inverts the direction (§9c)', () {
      final forward = TurnOrder.lapOrder(
        roundIndex: 0,
        lapIndex: 0,
        playerCount: 5,
      );
      final backward = TurnOrder.lapOrder(
        roundIndex: 0,
        lapIndex: 0,
        playerCount: 5,
        reversed: true,
      );
      expect(backward.first, forward.first);
      expect(backward, isNot(forward));
      expect(backward.toSet(), hasLength(5));
      expect(backward.every((i) => i >= 0), isTrue);
    });

    test('rejects a non-positive player count', () {
      expect(
        () => TurnOrder.startingIndex(roundIndex: 0, playerCount: 0),
        throwsArgumentError,
      );
    });
  });

  group('LifeCheck (§8)', () {
    test('clamps lives to the configured range', () {
      final settings = settingsFor(4);
      final players = makePlayers(4);

      final result = LifeCheck.apply(
        players: players,
        resolution: const RoundResolution(
          lifeDeltas: [
            LifeDelta(playerId: 'p0', delta: 5),
            LifeDelta(playerId: 'p1', delta: -9),
          ],
        ),
        settings: settings,
      );

      expect(
        result.players.firstWhere((p) => p.id == 'p0').currentLives,
        3,
        reason: 'Bonus Life is capped at the game max (§9b)',
      );
      expect(
        result.players.firstWhere((p) => p.id == 'p1').currentLives,
        0,
        reason: 'nothing drives a total below 0',
      );
    });

    test('a player reaching 0 owes exactly one forfeit', () {
      final settings = settingsFor(4, lives: 1);
      final result = LifeCheck.apply(
        players: makePlayers(4, lives: 1),
        resolution: const RoundResolution(
          lifeDeltas: [LifeDelta(playerId: 'p2', delta: -1)],
        ),
        settings: settings,
      );
      expect(result.pendingForfeits, hasLength(1));
      expect(result.pendingForfeits.single.playerId, 'p2');
      expect(result.pendingForfeits.single.count, 1);
    });

    test('High Stakes makes forfeits come in pairs (§9c)', () {
      final settings = settingsFor(4, lives: 1);
      final result = LifeCheck.apply(
        players: makePlayers(4, lives: 1),
        resolution: const RoundResolution(
          lifeDeltas: [LifeDelta(playerId: 'p2', delta: -1)],
        ),
        settings: settings,
        roundModifier: InterferenceCatalogue.highStakes,
      );
      expect(result.pendingForfeits.single.count, 2);
    });

    test('a player already at 0 does not accrue another forfeit', () {
      final settings = settingsFor(4);
      final players = [
        ...makePlayers(3),
        const Player(id: 'p3', name: 'P3', seatOrder: 3, currentLives: 0),
      ];
      final result = LifeCheck.apply(
        players: players,
        resolution: const RoundResolution(),
        settings: settings,
      );
      expect(result.pendingForfeits, isEmpty);
    });

    test('serving restores to 1 life and logs the consequence', () {
      const player = Player(
        id: 'p0',
        name: 'P0',
        seatOrder: 0,
        currentLives: 0,
      );
      final served = LifeCheck.serveForfeit(
        player: player,
        roundIndex: 2,
        description: 'sang the chorus',
        servedAt: DateTime.utc(2026),
      );
      expect(served.currentLives, 1);
      expect(served.consequenceLog, hasLength(1));
      expect(served.forfeitsServed, 1);
    });

    test('two forfeits restore once, after the second (§8)', () {
      const player = Player(
        id: 'p0',
        name: 'P0',
        seatOrder: 0,
        currentLives: 0,
      );

      final afterFirst = LifeCheck.serveForfeit(
        player: player,
        roundIndex: 2,
        description: 'first',
        servedAt: DateTime.utc(2026),
        remainingAfterThis: 1,
      );
      expect(
        afterFirst.currentLives,
        0,
        reason: 'restoration is a floor, not a per-forfeit reward (§8)',
      );

      final afterSecond = LifeCheck.serveForfeit(
        player: afterFirst,
        roundIndex: 2,
        description: 'second',
        servedAt: DateTime.utc(2026),
      );
      expect(afterSecond.currentLives, 1);
      expect(afterSecond.consequenceLog, hasLength(2));
    });

    test('rejects a negative remaining count', () {
      const player = Player(
        id: 'p0',
        name: 'P0',
        seatOrder: 0,
        currentLives: 0,
      );
      expect(
        () => LifeCheck.serveForfeit(
          player: player,
          roundIndex: 0,
          description: 'x',
          remainingAfterThis: -1,
        ),
        throwsArgumentError,
      );
    });

    test('the early-end threshold counts players, not forfeits (§8)', () {
      final settings = settingsFor(5, earlyEnd: 2);
      final players = makePlayers(5);

      expect(
        LifeCheck.earlyEndReached(players: players, settings: settings),
        isFalse,
      );

      // One player serving twice is still one player.
      players[0] = LifeCheck.serveForfeit(
        player: players[0],
        roundIndex: 0,
        description: 'a',
        servedAt: DateTime.utc(2026),
      );
      players[0] = LifeCheck.serveForfeit(
        player: players[0],
        roundIndex: 1,
        description: 'b',
        servedAt: DateTime.utc(2026),
      );
      expect(
        LifeCheck.earlyEndReached(players: players, settings: settings),
        isFalse,
      );

      players[1] = LifeCheck.serveForfeit(
        player: players[1],
        roundIndex: 1,
        description: 'c',
        servedAt: DateTime.utc(2026),
      );
      expect(
        LifeCheck.earlyEndReached(players: players, settings: settings),
        isTrue,
      );
    });

    test('no threshold means the game never ends early', () {
      final settings = settingsFor(5);
      final players = [
        for (final p in makePlayers(5))
          LifeCheck.serveForfeit(
            player: p,
            roundIndex: 0,
            description: 'x',
            servedAt: DateTime.utc(2026),
          ),
      ];
      expect(
        LifeCheck.earlyEndReached(players: players, settings: settings),
        isFalse,
      );
    });
  });

  group('GameMachine (§3)', () {
    test('walks the §3 diagram from lobby to the first vote', () {
      var phase = GamePhase.lobby;
      final visited = <GamePhase>[phase];

      for (var i = 0; i < 5; i++) {
        final next = GameMachine.next(
          phase,
          roundIndex: 0,
          hasRoundabouts: true,
        );
        expect(GameMachine.canTransition(phase, next), isTrue);
        phase = next;
        visited.add(phase);
      }

      expect(visited, [
        GamePhase.lobby,
        GamePhase.vibeRoll,
        GamePhase.playerOnboarding,
        GamePhase.roundStart,
        GamePhase.discussionPhase,
        GamePhase.votingPhase,
      ]);
    });

    test('rounds 2+ distribute words as their own phase', () {
      expect(
        GameMachine.next(
          GamePhase.roundStart,
          roundIndex: 1,
          hasRoundabouts: true,
        ),
        GamePhase.wordDistribution,
      );
    });

    test('No Roundabouts goes straight to voting (§9c)', () {
      expect(
        GameMachine.next(
          GamePhase.wordDistribution,
          roundIndex: 1,
          hasRoundabouts: false,
        ),
        GamePhase.votingPhase,
      );
    });

    test('every declared transition is reachable and legal', () {
      for (final entry in GameMachine.transitions.entries) {
        for (final target in entry.value) {
          expect(
            GameMachine.canTransition(entry.key, target),
            isTrue,
            reason: '${entry.key} -> $target',
          );
        }
      }
      expect(
        GameMachine.canTransition(GamePhase.lobby, GamePhase.votingPhase),
        isFalse,
        reason: 'the machine must reject a jump the diagram does not draw',
      );
    });

    test('branching phases refuse a single successor', () {
      expect(
        () => GameMachine.next(
          GamePhase.roundEndCheck,
          roundIndex: 0,
          hasRoundabouts: true,
        ),
        throwsStateError,
      );
    });

    test('roundEndCheck ends the game at the round limit', () {
      final settings = settingsFor(5, totalRounds: 3);
      expect(
        GameMachine.afterRoundEndCheck(
          completedRounds: 2,
          settings: settings,
          playersWhoServedForfeit: 0,
        ),
        GamePhase.roundStart,
      );
      expect(
        GameMachine.afterRoundEndCheck(
          completedRounds: 3,
          settings: settings,
          playersWhoServedForfeit: 0,
        ),
        GamePhase.gameSummary,
      );
    });

    test('roundEndCheck honours the early-end threshold and host command', () {
      final settings = settingsFor(5, totalRounds: 10, earlyEnd: 2);
      expect(
        GameMachine.afterRoundEndCheck(
          completedRounds: 1,
          settings: settings,
          playersWhoServedForfeit: 2,
        ),
        GamePhase.gameSummary,
      );
      expect(
        GameMachine.afterRoundEndCheck(
          completedRounds: 1,
          settings: settings,
          playersWhoServedForfeit: 0,
          hostEnded: true,
        ),
        GamePhase.gameSummary,
      );
    });

    test('interference is suppressed during round 1 (§3, §9f)', () {
      final on = settingsFor(
        5,
        interference: const InterferenceSettings(enabled: true),
      );
      expect(
        GameMachine.interferenceAllowed(roundIndex: 0, settings: on),
        isFalse,
        reason: 'round 1 is folded into onboarding and stays clean',
      );
      expect(
        GameMachine.interferenceAllowed(roundIndex: 1, settings: on),
        isTrue,
      );

      final off = settingsFor(5);
      expect(
        GameMachine.interferenceAllowed(roundIndex: 3, settings: off),
        isFalse,
      );
    });
  });

  group('model behaviour', () {
    test('Room reports completion and early end (§8, §10)', () {
      final settings = settingsFor(4, totalRounds: 2, earlyEnd: 1);
      final room = Room(
        id: 'r',
        settings: settings,
        players: makePlayers(4),
      );
      expect(room.isComplete, isFalse);
      expect(room.copyWith(currentRoundIndex: 2).isComplete, isTrue);

      final withForfeit = room.copyWith(
        players: [
          LifeCheck.serveForfeit(
            player: room.players.first,
            roundIndex: 0,
            description: 'x',
            servedAt: DateTime.utc(2026),
          ),
          ...room.players.skip(1),
        ],
      );
      expect(withForfeit.earlyEndReached, isTrue);
      expect(withForfeit.isComplete, isTrue);
    });

    test('Room looks players up and orders them by seat', () {
      final room = Room(
        id: 'r',
        settings: settingsFor(3),
        players: [
          const Player(id: 'c', name: 'C', seatOrder: 2, currentLives: 3),
          const Player(id: 'a', name: 'A', seatOrder: 0, currentLives: 3),
          const Player(id: 'b', name: 'B', seatOrder: 1, currentLives: 3),
        ],
      );
      expect(room.seated.map((p) => p.id), ['a', 'b', 'c']);
      expect(room.playerById('b')?.name, 'B');
      expect(room.playerById('zzz'), isNull);
      expect(room.currentRound, isNull);
    });

    test('PlayerStats reports accusation accuracy for Sharpest Read (§10)', () {
      const none = PlayerStats();
      expect(none.accusationAccuracy, 0);

      const some = PlayerStats(accusationsMade: 4, accusationsCorrect: 3);
      expect(some.accusationAccuracy, closeTo(0.75, 1e-9));
    });

    test('a selfie is never serialised (§4b, ADR 0005)', () {
      const player = Player(
        id: 'p0',
        name: 'P0',
        seatOrder: 0,
        currentLives: 3,
      );
      final json = player.toJson();
      expect(
        json.containsKey('selfieBytes'),
        isFalse,
        reason: 'selfie bytes must not reach any serialised form',
      );
    });
  });
}
