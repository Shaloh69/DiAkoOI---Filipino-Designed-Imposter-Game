import 'package:diakooi/engine/engine.dart';
import 'package:test/test.dart';

import 'game_simulator.dart';
import 'support.dart';

/// The A1 property tests.
///
/// Deliberately imports `package:test`, not `package:flutter_test`: these run
/// against the engine with no Flutter binding anywhere in scope, which is the
/// Phase 1 exit criterion stated as a test rather than as a claim.
void main() {
  final bank = makeBank(['pagkain', 'aktor'], perTopic: 60);

  group('A1 property: damage cap holds across many seeded games (§7b)', () {
    test('no player loses more than 2 in a round except via Sudden Death', () {
      const games = 10000;
      var roundsChecked = 0;
      var suddenDeathRounds = 0;

      for (var seed = 0; seed < games; seed++) {
        // Every round-start event is listed explicitly, INCLUDING Sudden
        // Death. It is defaultEnabled: false (§9c), so leaving the list empty
        // would mean the one documented cap bypass never fires and the
        // property would pass without ever exercising its own exception.
        final settings = settingsFor(
          6,
          lives: 5,
          totalRounds: 4,
          interference: InterferenceSettings(
            enabled: true,
            playerPickEnabled: true,
            roundStartEnabled: true,
            playerPickProbability: 0.6,
            enabledEventIds: [
              for (final e in InterferenceCatalogue.roundStartEvents) e.id,
            ],
          ),
        );
        final game = simulateGame(seed: seed, settings: settings, bank: bank);

        for (var i = 0; i < game.perRoundDeltas.length; i++) {
          roundsChecked++;
          final isSuddenDeath = game.suddenDeathRounds.contains(i);
          if (isSuddenDeath) suddenDeathRounds++;
          for (final delta in game.perRoundDeltas[i]) {
            if (delta.delta >= 0) continue;
            if (isSuddenDeath) continue;
            expect(
              delta.delta,
              greaterThanOrEqualTo(-2),
              reason:
                  'seed $seed round $i: ${delta.playerId} lost '
                  '${-delta.delta} with no Sudden Death (§7b)',
            );
          }
        }
      }

      expect(roundsChecked, greaterThan(0));
      // The property is only meaningful if its exception was actually
      // reached. Without this, disabling Sudden Death everywhere would make
      // the test pass while proving strictly less.
      expect(
        suddenDeathRounds,
        greaterThan(0),
        reason:
            'no Sudden Death round occurred across $games games, so the cap '
            'bypass was never exercised',
      );
    });

    test('Sudden Death can exceed the cap, so the exemption is real', () {
      final players = makePlayers(5, lives: 5);
      final result = resolveRound(
        votes: votesFrom({'p0': 'p3', 'p1': 'p3'}),
        roles: makeRoles(players, ['p4']),
        modifiers: const RoundModifiers(
          roundModifier: InterferenceCatalogue.suddenDeath,
        ),
        itemUsages: const [],
        currentLives: makeLives(players),
      );
      expect(result.deltaFor('p3'), lessThan(-2));
    });
  });

  group('A1 property: word distribution (§5)', () {
    test('crew always receive the real word; imposters never do', () {
      for (var seed = 0; seed < 2000; seed++) {
        final settings = settingsFor(8, totalRounds: 5, imposters: 3);
        final game = simulateGame(seed: seed, settings: settings, bank: bank);

        for (final round in game.rounds) {
          expect(
            round.imposterPlayerIds,
            isNotEmpty,
            reason: 'seed $seed round ${round.roundIndex} had no imposter',
          );
          expect(
            round.imposterPlayerIds.length,
            lessThan(settings.playerCount),
            reason: 'every player was an imposter, leaving no crew',
          );

          for (var i = 0; i < settings.playerCount; i++) {
            final id = 'p$i';
            final reveal = round.revealFor(id);
            if (round.isImposter(id)) {
              expect(
                reveal,
                round.imposterClue,
                reason: 'imposter $id got something other than the clue',
              );
              expect(
                reveal,
                isNot(round.word),
                reason: 'imposter $id received the real word',
              );
            } else {
              expect(
                reveal,
                round.word,
                reason: 'crew $id did not receive the real word',
              );
            }
          }
        }
      }
    });
  });

  group('A1 property: turn rotation (§6a)', () {
    test('every seat closes a lap within ±1 of uniform over 1000 rounds', () {
      for (final playerCount in [5, 7, 10]) {
        const rounds = 1000;
        const lapsPerRound = 2;
        final counts = List<int>.filled(playerCount, 0);

        for (var round = 0; round < rounds; round++) {
          for (var lap = 0; lap < lapsPerRound; lap++) {
            final last = TurnOrder.lastSpeakerIndex(
              roundIndex: round,
              lapIndex: lap,
              playerCount: playerCount,
            );
            counts[last]++;
          }
        }

        final expected = (rounds * lapsPerRound) / playerCount;
        for (var seat = 0; seat < playerCount; seat++) {
          expect(
            (counts[seat] - expected).abs(),
            lessThanOrEqualTo(1),
            reason:
                'seat $seat closed ${counts[seat]} laps at $playerCount '
                'players, expected about $expected',
          );
        }
      }
    });

    test('each lap in a round is closed by a different seat', () {
      const playerCount = 6;
      for (var round = 0; round < 50; round++) {
        final closers = {
          for (var lap = 0; lap < 3; lap++)
            TurnOrder.lastSpeakerIndex(
              roundIndex: round,
              lapIndex: lap,
              playerCount: playerCount,
            ),
        };
        expect(
          closers.length,
          3,
          reason: 'round $round had the same seat close more than one lap',
        );
      }
    });
  });

  group('A1 property: topic draw (§13b)', () {
    test('converges to host weights within 2% over 10000 rounds', () {
      const draws = 10000;
      final settings = RoomSettings.validated(
        playerCount: 6,
        topicWeights: const [
          TopicWeight(topicId: 'kpop', weightPercent: 60),
          TopicWeight(topicId: 'opm', weightPercent: 20),
          TopicWeight(topicId: 'internet', weightPercent: 20),
        ],
      );

      final rng = SeededRng(20260823);
      final history = <String>[];
      final counts = <String, int>{};

      for (var i = 0; i < draws; i++) {
        final topic = TopicSelector.draw(
          settings: settings,
          topicHistory: history,
          rng: rng,
        );
        history.add(topic);
        counts[topic] = (counts[topic] ?? 0) + 1;
      }

      for (final weight in settings.topicWeights) {
        final actual = (counts[weight.topicId] ?? 0) / draws * 100;
        expect(
          (actual - weight.weightPercent).abs(),
          lessThanOrEqualTo(2),
          reason:
              '${weight.topicId} drew ${actual.toStringAsFixed(2)}%, '
              'host set ${weight.weightPercent}%',
        );
      }
    });

    test('the no-repeat window is never violated', () {
      final settings = RoomSettings.validated(
        playerCount: 6,
        topicWeights: const [
          // A 90% weight is exactly the case that produces streaks a table
          // reads as broken (§13b).
          TopicWeight(topicId: 'kpop', weightPercent: 90),
          TopicWeight(topicId: 'opm', weightPercent: 10),
        ],
      );

      final rng = SeededRng(7);
      final history = <String>[];

      for (var i = 0; i < 20000; i++) {
        final topic = TopicSelector.draw(
          settings: settings,
          topicHistory: history,
          rng: rng,
        );
        expect(
          TopicSelector.isDrawable(topic, history),
          isTrue,
          reason: 'draw $i produced $topic against the window',
        );
        history.add(topic);

        if (history.length >= 3) {
          final tail = history.sublist(history.length - 3);
          expect(
            tail.toSet().length,
            greaterThan(1),
            reason: 'three consecutive draws of ${tail.first} at draw $i',
          );
        }
      }
    });

    test('a word never repeats within a session', () {
      for (var seed = 0; seed < 500; seed++) {
        final settings = settingsFor(6, totalRounds: 20);
        final game = simulateGame(seed: seed, settings: settings, bank: bank);
        final words = game.rounds.map((r) => r.word).toList();
        expect(
          words.toSet().length,
          words.length,
          reason: 'seed $seed repeated a word within the session (§13b)',
        );
      }
    });
  });

  group('A1: determinism', () {
    test('same seed produces byte-identical transcripts', () {
      final settings = settingsFor(
        7,
        totalRounds: 10,
        interference: const InterferenceSettings(
          enabled: true,
          playerPickEnabled: true,
          roundStartEnabled: true,
        ),
      );

      for (final seed in [0, 1, 42, 20260823]) {
        final first = simulateGame(seed: seed, settings: settings, bank: bank);
        final second = simulateGame(seed: seed, settings: settings, bank: bank);
        expect(
          second.transcript,
          first.transcript,
          reason: 'seed $seed replayed differently',
        );
      }
    });

    test('different seeds produce different transcripts', () {
      final settings = settingsFor(7, totalRounds: 10);
      final a = simulateGame(seed: 1, settings: settings, bank: bank);
      final b = simulateGame(seed: 2, settings: settings, bank: bank);
      expect(a.transcript, isNot(b.transcript));
    });
  });

  group('Phase 1 exit criterion', () {
    test('a 10-round game simulates end to end', () {
      final settings = settingsFor(6, totalRounds: 10);
      final game = simulateGame(seed: 99, settings: settings, bank: bank);

      expect(game.rounds, hasLength(10));
      expect(game.players, hasLength(6));
      for (final player in game.players) {
        expect(player.currentLives, greaterThanOrEqualTo(0));
        expect(player.currentLives, lessThanOrEqualTo(settings.livesPerPlayer));
      }
      expect(game.transcript, contains('r9 '));
    });
  });
}
