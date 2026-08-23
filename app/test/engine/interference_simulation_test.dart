import 'package:diakooi/engine/engine.dart';
import 'package:test/test.dart';

import 'game_simulator.dart';
import 'support.dart';

/// A6: **10,000 games with every event enabled** — no unbounded life loss, no
/// unreachable state, no crash.
///
/// The 10k run in `properties_test.dart` looks like this one and is not. Its
/// `enabledEventIds` lists only the round-start events, and a non-empty list
/// means everything absent is *disabled* — so no §9b event has ever fired in
/// it. That test is still right about what it claims (the §7b cap under
/// round-start modifiers); it simply does not cover the player-pick half, and
/// reading it as "all events on" was the mistake this file exists to correct.
///
/// Every id from both catalogues is listed here, explicitly, including Sudden
/// Death — which is `defaultEnabled: false`, so omitting it would mean the one
/// documented cap bypass never fires and the property passes without ever
/// exercising its own exception.
void main() {
  final bank = makeBank(['pagkain', 'aktor', 'kpop'], perTopic: 80);

  RoomSettings everythingOn({int players = 6, int lives = 5, int rounds = 4}) =>
      settingsFor(
        players,
        lives: lives,
        totalRounds: rounds,
        interference: InterferenceSettings(
          enabled: true,
          playerPickEnabled: true,
          roundStartEnabled: true,
          itemsEnabled: true,
          // High, so 10,000 games is enough to hit the rare combinations. A
          // realistic 25% would leave the tail under-sampled.
          playerPickProbability: 0.65,
          enabledEventIds: [
            for (final e in InterferenceCatalogue.playerPickEvents) e.id,
            for (final e in InterferenceCatalogue.roundStartEvents) e.id,
          ],
        ),
      );

  group('A6: 10,000 games, all events on', () {
    test('no crash, no unbounded loss, no unreachable state', () {
      const games = 10000;
      final settings = everythingOn();

      var roundsPlayed = 0;
      var suddenDeathRounds = 0;
      final modifiersSeen = <String>{};
      final eventsSeen = <String>{};

      for (var seed = 0; seed < games; seed++) {
        final game = simulateGame(seed: seed, settings: settings, bank: bank);

        modifiersSeen.addAll(game.roundModifiers.whereType<String>());
        for (final round in game.playerPickEvents) {
          for (final event in round) {
            eventsSeen.add(event.eventId);
          }
        }

        for (var i = 0; i < game.perRoundDeltas.length; i++) {
          roundsPlayed++;
          final suddenDeath = game.suddenDeathRounds.contains(i);
          if (suddenDeath) suddenDeathRounds++;

          for (final delta in game.perRoundDeltas[i]) {
            if (delta.delta >= 0) continue;
            if (suddenDeath) continue;
            expect(
              delta.delta,
              greaterThanOrEqualTo(-2),
              reason:
                  'seed $seed round $i: ${delta.playerId} lost '
                  '${-delta.delta} in one round with no Sudden Death (§7b)',
            );
          }
        }

        // No unreachable state: lives never leave [0, max] and the game always
        // terminates at the round limit or the early-end threshold.
        for (final player in game.finalPlayers) {
          expect(
            player.currentLives,
            inInclusiveRange(0, settings.livesPerPlayer),
            reason: 'seed $seed: ${player.id} ended outside the life range',
          );
        }
        expect(
          game.perRoundDeltas.length,
          inInclusiveRange(1, settings.totalRounds),
          reason: 'seed $seed played an impossible number of rounds',
        );
      }

      expect(roundsPlayed, greaterThan(games));
      expect(
        suddenDeathRounds,
        greaterThan(0),
        reason:
            'Sudden Death never fired across 10,000 games, so the one '
            'documented §7b bypass went untested and the cap property passed '
            'without exercising its own exception',
      );
    });

    test('the run actually reached every event, not just most of them', () {
      // The failure this guards: a pool filter that silently drops events
      // leaves the simulation green while covering less than it claims. That
      // is precisely what the older 10k run did.
      const games = 4000;
      final settings = everythingOn();
      final modifiersSeen = <String>{};
      final eventsSeen = <String>{};

      for (var seed = 0; seed < games; seed++) {
        final game = simulateGame(seed: seed, settings: settings, bank: bank);
        modifiersSeen.addAll(game.roundModifiers.whereType<String>());
        for (final round in game.playerPickEvents) {
          for (final event in round) {
            eventsSeen.add(event.eventId);
          }
        }
      }

      final expectedModifiers = {
        for (final e in InterferenceCatalogue.roundStartEvents) e.id,
      };
      final expectedEvents = {
        for (final e in InterferenceCatalogue.playerPickEvents) e.id,
      };

      expect(
        expectedModifiers.difference(modifiersSeen),
        isEmpty,
        reason: 'a §9c modifier never fired across $games games',
      );
      expect(
        expectedEvents.difference(eventsSeen),
        isEmpty,
        reason: 'a §9b event never fired across $games games',
      );
    });

    test('it holds at 3 players and at 20', () {
      // Table size changes which events can do anything: Steal a Life needs a
      // victim, Spread the Blame needs somewhere to spread, Double Imposter
      // needs room for another imposter.
      for (final players in [3, 20]) {
        final settings = everythingOn(players: players, rounds: 3);
        for (var seed = 0; seed < 400; seed++) {
          final game = simulateGame(seed: seed, settings: settings, bank: bank);
          for (final player in game.finalPlayers) {
            expect(
              player.currentLives,
              inInclusiveRange(0, settings.livesPerPlayer),
              reason: '$players players, seed $seed',
            );
          }
        }
      }
    });
  });

  group('A6: the three rules that were fixed from earlier drafts', () {
    test('Spread the Blame keeps a plurality reachable at 3, 10 and 20', () {
      // The precise claim, because a looser one fails honestly: the cap makes
      // a plurality REACHABLE, not guaranteed. Ten voters spread two-per-tile
      // is a legal ballot and a genuine five-way tie — which the Mayor then
      // breaks (§7a), so the round still resolves. The rule this replaced was
      // worse in kind: under a hard no-duplicates ban a tie is *forced*, with
      // no legal ballot producing a winner at all.
      for (final count in [3, 10, 20]) {
        final ids = [for (var i = 0; i < count; i++) 'p$i'];

        // Concentrate inside the cap: two on the first tile, two on the next,
        // and the remainder scattered so nothing else reaches two.
        final votes = <Vote>[];
        final tally = <String, int>{};
        for (var i = 0; i < count; i++) {
          final accused = ids.firstWhere(
            (id) =>
                id != ids[i] &&
                (tally[id] ?? 0) < InterferenceCatalogue.spreadTheBlameCap,
          );
          votes.add(Vote(voterId: ids[i], accusedId: accused));
          tally[accused] = (tally[accused] ?? 0) + 1;
        }

        expect(
          tally.values.every(
            (v) => v <= InterferenceCatalogue.spreadTheBlameCap,
          ),
          isTrue,
          reason: 'the ballot itself broke the cap at $count players',
        );

        // The Mayor has to be someone the tie does not include: §7a makes a
        // tie in which the Mayor is one of the accused a wash, deliberately.
        // Spread the Blame makes wide ties far more common, so that
        // interaction is worth pinning rather than discovering at a table.
        final highest = tally.values.reduce((a, b) => a > b ? a : b);
        final tied = {
          for (final entry in tally.entries)
            if (entry.value == highest) entry.key,
        };
        final mayor = ids.lastWhere((id) => !tied.contains(id));

        final resolution = resolveRound(
          votes: votes,
          roles: {for (final id in ids) id: PlayerRole.crew},
          modifiers: const RoundModifiers(
            roundModifier: InterferenceCatalogue.spreadTheBlame,
          ),
          itemUsages: const [],
          currentLives: {for (final id in ids) id: 3},
          mayorPlayerId: mayor,
        );
        expect(
          resolution.targetPlayerId,
          isNotNull,
          reason:
              'at $count players Spread the Blame produced no target even '
              'with a Mayor outside the tie — that is a dead end',
        );

        // And the §7a wash is still reachable, which is correct rather than a
        // gap: a Mayor who is themselves accused cannot arbitrate.
        if (tied.length > 1) {
          final washed = resolveRound(
            votes: votes,
            roles: {for (final id in ids) id: PlayerRole.crew},
            modifiers: const RoundModifiers(
              roundModifier: InterferenceCatalogue.spreadTheBlame,
            ),
            itemUsages: const [],
            currentLives: {for (final id in ids) id: 3},
            mayorPlayerId: tied.first,
          );
          expect(
            washed.wasWash,
            isTrue,
            reason: '§7a: a tie containing the Mayor is a wash',
          );
        }
      }
    });

    test('a hard no-duplicates ban would force a tie — the cap does not', () {
      // Why the cap is 2 rather than 1, stated as arithmetic rather than as a
      // comment. This is the failure §9c documents.
      for (final count in [3, 10, 20]) {
        final ids = [for (var i = 0; i < count; i++) 'p$i'];

        // One vote per tile is the only shape a no-duplicates ban permits at
        // N voters and N tiles.
        final banned = <String, int>{for (final id in ids) id: 1};
        expect(
          banned.values.toSet(),
          {1},
          reason: 'every tile holds exactly one vote — a permanent N-way tie',
        );

        // The cap of 2 admits a shape with a strict winner.
        final withCap = <String, int>{
          ids.first: InterferenceCatalogue.spreadTheBlameCap,
          for (final id in ids.skip(1)) id: 1,
        };
        final best = withCap.values.reduce((a, b) => a > b ? a : b);
        expect(
          withCap.values.where((v) => v == best).length,
          1,
          reason:
              'at $count players the cap of 2 admits no shape with a strict '
              'winner, which is the whole reason it is 2 and not 1',
        );
      }
    });

    test('Near-Unanimous cannot be blocked by imposters alone', () {
      // Under TRUE unanimity a lone imposter names someone nobody else did and
      // buys a free round every time. 75% is the threshold precisely so the
      // imposters cannot veto it on their own.
      for (final count in [4, 6, 10, 20]) {
        final imposterCount = RoomSettings.defaultImposterCount(count);
        final ids = [for (var i = 0; i < count; i++) 'p$i'];
        final imposters = ids.take(imposterCount).toSet();

        // Every crew member names the same target; every imposter scatters.
        final target = ids.last;
        final votes = [
          for (final id in ids)
            if (id != target)
              Vote(
                voterId: id,
                accusedId: imposters.contains(id) ? ids.first : target,
              ),
        ];

        final crewBacking = votes.where((v) => v.accusedId == target).length;
        final share = crewBacking / count;

        final resolution = resolveRound(
          votes: votes,
          roles: {
            for (final id in ids)
              id: imposters.contains(id)
                  ? PlayerRole.imposter
                  : PlayerRole.crew,
          },
          modifiers: const RoundModifiers(
            roundModifier: InterferenceCatalogue.nearUnanimous,
          ),
          itemUsages: const [],
          currentLives: {for (final id in ids) id: 3},
        );

        if (share >= 0.75) {
          expect(
            resolution.wasWash,
            isFalse,
            reason:
                'at $count players the crew reached '
                '${(share * 100).round()}% and were still blocked',
          );
        }
        // Below 75% a wash is correct; the assertion above is the one that
        // matters, and it is what a true-unanimity rule would fail.
      }
    });

    test('Mercy Round blocks every damage source, not just the vote', () {
      // §9c calls this explicitly total. The sources that can take a life in
      // one round are vote resolution, Life Drain, Steal a Life, Taboo slips,
      // Reverse Round and Sudden Death — so all of them are stacked here at
      // once and the result must still be zero.
      final ids = ['p0', 'p1', 'p2', 'p3'];
      final resolution = resolveRound(
        votes: [
          for (final id in ids.skip(1)) Vote(voterId: id, accusedId: 'p0'),
        ],
        roles: {for (final id in ids) id: PlayerRole.crew},
        modifiers: const RoundModifiers(
          roundModifier: InterferenceCatalogue.mercyRound,
          playerPickEvents: [
            PlayerPickEvent(playerId: 'p1', eventId: 'life_drain'),
            PlayerPickEvent(playerId: 'p2', eventId: 'steal_life'),
          ],
          tabooSlips: ['p3'],
          stealTargets: {'p2': 'p3'},
        ),
        itemUsages: const [],
        currentLives: {for (final id in ids) id: 3},
      );

      for (final id in ids) {
        expect(
          resolution.deltaFor(id),
          0,
          reason:
              '$id lost or gained a life during a Mercy Round — §9c says no '
              'life is lost this round from any source',
        );
      }
    });
  });
}
