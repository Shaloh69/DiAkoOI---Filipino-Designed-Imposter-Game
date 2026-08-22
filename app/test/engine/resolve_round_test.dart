import 'package:diakooi/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// A1 coverage for `resolveRound` — the rules 01-DESIGN.md flags as
/// counterintuitive on purpose. Each group names the section it enforces.
void main() {
  group('core resolution (§7)', () {
    test('caught imposter loses 2 and nobody else loses anything', () {
      final players = makePlayers(5);
      final result = resolveRound(
        votes: votesFrom({'p0': 'p4', 'p1': 'p4', 'p2': 'p4', 'p3': 'p0'}),
        roles: makeRoles(players, ['p4']),
        modifiers: const RoundModifiers(),
        itemUsages: const [],
        currentLives: makeLives(players),
      );

      expect(result.targetPlayerId, 'p4');
      expect(result.targetWasImposter, isTrue);
      expect(result.deltaFor('p4'), -2);
      for (final id in ['p0', 'p1', 'p2', 'p3']) {
        expect(result.deltaFor(id), 0, reason: '$id should be untouched');
      }
    });

    test('accuser-pays: only those who named the crew target lose a life', () {
      final players = makePlayers(5);
      final result = resolveRound(
        // p0 and p1 wrongly name crew p3. p2 names the real imposter p4.
        votes: votesFrom({'p0': 'p3', 'p1': 'p3', 'p2': 'p4'}),
        roles: makeRoles(players, ['p4']),
        modifiers: const RoundModifiers(),
        itemUsages: const [],
        currentLives: makeLives(players),
      );

      expect(result.targetPlayerId, 'p3');
      expect(result.targetWasImposter, isFalse);
      expect(result.deltaFor('p0'), -1);
      expect(result.deltaFor('p1'), -1);
      expect(
        result.deltaFor('p2'),
        0,
        reason:
            'named an actual imposter, so loses nothing even in the '
            'minority (§7)',
      );
      expect(result.deltaFor('p3'), 0, reason: 'the accused crew pays nothing');
    });

    test('a player naming themselves is rejected', () {
      final players = makePlayers(4);
      final result = resolveRound(
        votes: votesFrom({'p0': 'p0', 'p1': 'p2', 'p2': 'p1'}),
        roles: makeRoles(players, ['p3']),
        modifiers: const RoundModifiers(),
        itemUsages: const [],
        currentLives: makeLives(players),
      );
      // p1 and p2 tie at 1 each; p0's self-vote is dropped rather than
      // deciding the round.
      expect(result.wasWash, isTrue);
    });
  });

  group('vote weight is tally-only, never damage (§7)', () {
    test('a Double Vote player on a losing target loses exactly 1, not 2', () {
      final players = makePlayers(5);
      final result = resolveRound(
        // p0 carries weight 2, so crew p3 (2 + 1) outpolls imposter p4 (1).
        votes: votesFrom(
          {'p0': 'p3', 'p1': 'p3', 'p2': 'p4'},
          weights: {'p0': 2},
        ),
        roles: makeRoles(players, ['p4']),
        modifiers: const RoundModifiers(
          playerPickEvents: [
            PlayerPickEvent(
              playerId: 'p0',
              eventId: InterferenceCatalogue.doubleVote,
            ),
          ],
        ),
        itemUsages: const [],
        currentLives: makeLives(players),
      );

      expect(result.targetPlayerId, 'p3');
      expect(
        result.deltaFor('p0'),
        -1,
        reason: 'weight moved the tally but must not move damage (§7)',
      );
      expect(result.deltaFor('p1'), -1);
    });

    test('a Megaphone holder likewise loses 1', () {
      final players = makePlayers(5);
      final result = resolveRound(
        votes: votesFrom(
          {'p0': 'p3', 'p1': 'p3', 'p2': 'p4'},
          weights: {'p0': 2},
        ),
        roles: makeRoles(players, ['p4']),
        modifiers: const RoundModifiers(),
        itemUsages: const [
          ItemUsage(
            playerId: 'p0',
            itemId: InterferenceCatalogue.itemMegaphone,
            roleAtUse: PlayerRole.crew,
            phase: ItemUsePhase.voting,
          ),
        ],
        currentLives: makeLives(players),
      );
      expect(result.deltaFor('p0'), -1);
    });
  });

  group('Mayor tie rule (§7a) — the four cases', () {
    late List<Player> players;
    setUp(() => players = makePlayers(5));

    test('no tie: the Mayor is irrelevant', () {
      final result = resolveRound(
        votes: votesFrom({'p0': 'p3', 'p1': 'p3', 'p2': 'p4'}),
        roles: makeRoles(players, ['p4']),
        modifiers: const RoundModifiers(),
        itemUsages: const [],
        currentLives: makeLives(players),
        mayorPlayerId: 'p2',
      );
      expect(result.targetPlayerId, 'p3');
      expect(result.wasWash, isFalse);
    });

    test("tie the Mayor voted in: the Mayor's tile wins", () {
      final result = resolveRound(
        // p3 and p4 tie at 1 each. Mayor p2 named p4.
        votes: votesFrom({'p0': 'p3', 'p2': 'p4'}),
        roles: makeRoles(players, ['p4']),
        modifiers: const RoundModifiers(),
        itemUsages: const [],
        currentLives: makeLives(players),
        mayorPlayerId: 'p2',
      );
      expect(result.targetPlayerId, 'p4');
      expect(result.wasWash, isFalse);
      expect(result.deltaFor('p4'), -2);
    });

    test("tie the Mayor didn't vote in: wash, nobody loses a life", () {
      final six = makePlayers(6);
      final result = resolveRound(
        // p3 and p4 tie at 2 each. Mayor p0 named p1, who is on 1 — so the
        // Mayor did not vote in the tie at all.
        votes: votesFrom({
          'p1': 'p3',
          'p2': 'p3',
          'p3': 'p4',
          'p5': 'p4',
          'p0': 'p1',
        }),
        roles: makeRoles(six, ['p5']),
        modifiers: const RoundModifiers(),
        itemUsages: const [],
        currentLives: makeLives(six),
        mayorPlayerId: 'p0',
      );
      expect(result.wasWash, isTrue);
      expect(result.targetPlayerId, isNull);
      expect(result.lifeDeltas, isEmpty);
    });

    test('Mayor is one of the tied accused: wash', () {
      final result = resolveRound(
        // p1 and p2 tie at 2 each, and Mayor p2 is one of them.
        votes: votesFrom({
          'p0': 'p2',
          'p1': 'p2',
          'p3': 'p1',
          'p4': 'p1',
          'p2': 'p0',
        }),
        roles: makeRoles(players, ['p4']),
        modifiers: const RoundModifiers(),
        itemUsages: const [],
        currentLives: makeLives(players),
        mayorPlayerId: 'p2',
      );
      expect(
        result.wasWash,
        isTrue,
        reason: 'a tie including the Mayor is a wash even when they voted',
      );
    });

    test('a tie with no Mayor designated is a wash', () {
      final result = resolveRound(
        votes: votesFrom({'p0': 'p3', 'p1': 'p4'}),
        roles: makeRoles(players, ['p4']),
        modifiers: const RoundModifiers(),
        itemUsages: const [],
        currentLives: makeLives(players),
      );
      expect(result.wasWash, isTrue);
    });
  });

  group('damage cap (§7b)', () {
    test('stacked losses clamp at 2 and the player is reported as capped', () {
      final players = makePlayers(5);
      final result = resolveRound(
        votes: votesFrom({'p0': 'p3', 'p1': 'p3', 'p2': 'p4'}),
        roles: makeRoles(players, ['p4']),
        modifiers: const RoundModifiers(
          // p0 takes a wrong accusation (-1), Life Drain (-1) and a Taboo
          // slip (-1): -3 before the clamp.
          playerPickEvents: [
            PlayerPickEvent(
              playerId: 'p0',
              eventId: InterferenceCatalogue.lifeDrain,
            ),
          ],
          tabooSlips: ['p0'],
        ),
        itemUsages: const [],
        currentLives: makeLives(players),
      );

      expect(result.deltaFor('p0'), -2, reason: 'clamped at 2 (§7b)');
      expect(result.cappedPlayerIds, contains('p0'));
    });

    test('Sudden Death is the sole bypass', () {
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

      expect(result.deltaFor('p3'), -5, reason: 'loses all remaining lives');
      expect(result.cappedPlayerIds, isEmpty);
    });

    test('Double Damage doubles accuser damage but not imposter damage', () {
      final players = makePlayers(5);

      final wrong = resolveRound(
        votes: votesFrom({'p0': 'p3', 'p1': 'p3'}),
        roles: makeRoles(players, ['p4']),
        modifiers: const RoundModifiers(
          roundModifier: InterferenceCatalogue.doubleDamage,
        ),
        itemUsages: const [],
        currentLives: makeLives(players),
      );
      expect(wrong.deltaFor('p0'), -2);
      expect(wrong.deltaFor('p1'), -2);

      final caught = resolveRound(
        votes: votesFrom({'p0': 'p4', 'p1': 'p4'}),
        roles: makeRoles(players, ['p4']),
        modifiers: const RoundModifiers(
          roundModifier: InterferenceCatalogue.doubleDamage,
        ),
        itemUsages: const [],
        currentLives: makeLives(players),
      );
      expect(
        caught.deltaFor('p4'),
        -2,
        reason: '2 is already the cap, so Double Damage cannot raise it (§7b)',
      );
    });
  });
}
