import 'package:diakooi/engine/engine.dart';
import 'package:test/test.dart';

import 'support.dart';

/// A1: every §9b and §9c event resolves without throwing, alone and stacked.
///
/// The point is coverage of the whole catalogue rather than of the handful of
/// events with interesting arithmetic. An event that is inert today still has
/// to survive being passed in, because Phase 6 wires all of them to real UI.
void main() {
  late List<Player> players;
  late Map<String, PlayerRole> roles;
  late Map<String, int> lives;
  late List<Vote> votes;

  setUp(() {
    players = makePlayers(6);
    roles = makeRoles(players, ['p5']);
    lives = makeLives(players);
    // A resolvable vote: crew p3 is the target, named by p0 and p1.
    votes = votesFrom({'p0': 'p3', 'p1': 'p3', 'p2': 'p5', 'p4': 'p0'});
  });

  RoundResolution run({
    String? roundModifier,
    List<PlayerPickEvent> pickEvents = const [],
    List<ItemUsage> items = const [],
    Map<String, String> steals = const {},
    String? bodyguard,
    List<String> tabooSlips = const [],
  }) => resolveRound(
    votes: votes,
    roles: roles,
    modifiers: RoundModifiers(
      roundModifier: roundModifier,
      playerPickEvents: pickEvents,
      bodyguardPlayerId: bodyguard,
      tabooSlips: tabooSlips,
      stealTargets: steals,
    ),
    itemUsages: items,
    currentLives: lives,
    mayorPlayerId: 'p2',
  );

  group('every §9c round-start event resolves alone', () {
    for (final event in InterferenceCatalogue.roundStartEvents) {
      test('${event.id} does not throw', () {
        final result = run(roundModifier: event.id);
        expect(result, isA<RoundResolution>());
        // Losses respect the cap unless this event is the declared bypass.
        for (final delta in result.lifeDeltas) {
          if (delta.delta >= 0) continue;
          if (event.bypassesDamageCap) continue;
          expect(delta.delta, greaterThanOrEqualTo(-2));
        }
      });
    }
  });

  group('every §9b player-pick event resolves alone', () {
    for (final event in InterferenceCatalogue.playerPickEvents) {
      test('${event.id} does not throw', () {
        final result = run(
          pickEvents: [
            PlayerPickEvent(playerId: 'p0', eventId: event.id),
          ],
          steals: const {'p0': 'p4'},
        );
        expect(result, isA<RoundResolution>());
        for (final delta in result.lifeDeltas) {
          if (delta.delta < 0) {
            expect(delta.delta, greaterThanOrEqualTo(-2));
          }
        }
      });
    }
  });

  group('events stack without throwing', () {
    test('every round-start event against every player-pick event', () {
      for (final modifier in InterferenceCatalogue.roundStartEvents) {
        for (final pick in InterferenceCatalogue.playerPickEvents) {
          final result = run(
            roundModifier: modifier.id,
            pickEvents: [
              PlayerPickEvent(playerId: 'p0', eventId: pick.id),
              PlayerPickEvent(playerId: 'p1', eventId: pick.id),
            ],
            steals: const {'p0': 'p4', 'p1': 'p4'},
            tabooSlips: const ['p0'],
            bodyguard: 'p3',
          );
          expect(
            result,
            isA<RoundResolution>(),
            reason: 'stacking ${modifier.id} with ${pick.id} threw',
          );

          if (modifier.bypassesDamageCap) continue;
          for (final delta in result.lifeDeltas) {
            if (delta.delta >= 0) continue;
            expect(
              delta.delta,
              greaterThanOrEqualTo(-2),
              reason:
                  '${modifier.id} + ${pick.id} drove ${delta.playerId} to '
                  '${delta.delta}, past the §7b clamp',
            );
          }
        }
      }
    });

    test('every item resolves, alone and against every modifier', () {
      for (final itemId in InterferenceCatalogue.itemIds) {
        for (final modifier in [
          null,
          ...InterferenceCatalogue.roundStartEvents.map((e) => e.id),
        ]) {
          final result = run(
            roundModifier: modifier,
            items: [
              ItemUsage(
                playerId: 'p0',
                itemId: itemId,
                roleAtUse: PlayerRole.crew,
                phase: ItemUsePhase.voting,
                targetPlayerId: 'p1',
              ),
            ],
          );
          expect(
            result,
            isA<RoundResolution>(),
            reason: '$itemId with modifier $modifier threw',
          );
        }
      }
    });
  });

  group('the events with arithmetic behave as §9 specifies', () {
    test('Mercy Round removes every loss but keeps gains', () {
      final result = run(
        roundModifier: InterferenceCatalogue.mercyRound,
        pickEvents: const [
          PlayerPickEvent(
            playerId: 'p4',
            eventId: InterferenceCatalogue.bonusLife,
          ),
          PlayerPickEvent(
            playerId: 'p1',
            eventId: InterferenceCatalogue.lifeDrain,
          ),
        ],
        tabooSlips: const ['p2'],
      );

      for (final delta in result.lifeDeltas) {
        expect(
          delta.delta,
          greaterThanOrEqualTo(0),
          reason: 'Mercy Round is explicitly total (§9c)',
        );
      }
      expect(result.deltaFor('p4'), 1, reason: 'gains survive');
    });

    test('Reverse Round inverts the core rule', () {
      // Target is crew p3 -> the ACCUSED loses 2, not the accusers.
      final crewTarget = run(roundModifier: InterferenceCatalogue.reverseRound);
      expect(crewTarget.deltaFor('p3'), -2);
      expect(crewTarget.deltaFor('p0'), 0);

      // Target is imposter p5 -> each accuser loses 1.
      votes = votesFrom({'p0': 'p5', 'p1': 'p5', 'p2': 'p3'});
      final imposterTarget = run(
        roundModifier: InterferenceCatalogue.reverseRound,
      );
      expect(imposterTarget.deltaFor('p0'), -1);
      expect(imposterTarget.deltaFor('p1'), -1);
      expect(imposterTarget.deltaFor('p5'), 0);
    });

    test("Fool's Round makes the target gain instead of lose", () {
      final result = run(roundModifier: InterferenceCatalogue.foolsRound);
      expect(result.deltaFor('p3'), 1);
    });

    test('The Fool protects only the player who holds it', () {
      final result = run(
        pickEvents: const [
          PlayerPickEvent(
            playerId: 'p3',
            eventId: InterferenceCatalogue.theFool,
          ),
        ],
      );
      expect(result.deltaFor('p3'), 1);
      expect(
        result.deltaFor('p0'),
        0,
        reason: 'accusers pay nothing when the target gained instead',
      );
    });

    test('Vote Lock makes a player untargetable', () {
      votes = votesFrom({'p0': 'p3', 'p1': 'p3', 'p2': 'p4', 'p4': 'p2'});
      final result = run(
        pickEvents: const [
          PlayerPickEvent(
            playerId: 'p3',
            eventId: InterferenceCatalogue.voteLock,
          ),
        ],
      );
      expect(
        result.targetPlayerId,
        isNot('p3'),
        reason: 'votes against a Vote Lock player are rejected (§9b)',
      );
    });

    test('Spread the Blame caps duplicate accusations at 2', () {
      // Four players all name p3; only the first two count, so p3 ties with
      // p4 rather than winning outright.
      votes = votesFrom({
        'p0': 'p3',
        'p1': 'p3',
        'p2': 'p3',
        'p4': 'p3',
        'p3': 'p4',
        'p5': 'p4',
      });
      final result = run(roundModifier: InterferenceCatalogue.spreadTheBlame);
      expect(
        result.wasWash,
        isTrue,
        reason:
            'p3 capped at 2 ties p4 at 2; Mayor p2 named p3, which was '
            'discarded by the cap, so no tie-break applies',
      );
    });

    test('Near-Unanimous washes below 75% and lands at or above it', () {
      // 2 of 6 name p3 — well short.
      final short = run(roundModifier: InterferenceCatalogue.nearUnanimous);
      expect(short.wasWash, isTrue);

      // 5 of 6 name p3.
      votes = votesFrom({
        'p0': 'p3',
        'p1': 'p3',
        'p2': 'p3',
        'p4': 'p3',
        'p5': 'p3',
      });
      final landed = run(roundModifier: InterferenceCatalogue.nearUnanimous);
      expect(landed.wasWash, isFalse);
      expect(landed.targetPlayerId, 'p3');
    });

    test("Bodyguard cancels the protected player's loss", () {
      final result = run(bodyguard: 'p0');
      expect(
        result.deltaFor('p0'),
        0,
        reason: 'p0 wrongly accused p3 but is secretly immune (§9c)',
      );
      expect(result.deltaFor('p1'), -1, reason: 'p1 is not protected');
    });

    test('Shield cancels a loss; Veto cancels the whole vote', () {
      final shielded = run(
        items: const [
          ItemUsage(
            playerId: 'p0',
            itemId: InterferenceCatalogue.itemShield,
            roleAtUse: PlayerRole.crew,
            phase: ItemUsePhase.afterTally,
          ),
        ],
      );
      expect(shielded.deltaFor('p0'), 0);
      expect(shielded.deltaFor('p1'), -1);

      final vetoed = run(
        items: const [
          ItemUsage(
            playerId: 'p0',
            itemId: InterferenceCatalogue.itemVeto,
            roleAtUse: PlayerRole.crew,
            phase: ItemUsePhase.afterTally,
          ),
        ],
      );
      expect(vetoed.wasWash, isTrue);
      expect(vetoed.lifeDeltas, isEmpty);
    });

    test('Mirror reflects the loss onto the named target', () {
      final result = run(
        items: const [
          ItemUsage(
            playerId: 'p0',
            itemId: InterferenceCatalogue.itemMirror,
            roleAtUse: PlayerRole.crew,
            phase: ItemUsePhase.afterTally,
            targetPlayerId: 'p4',
          ),
        ],
      );
      expect(result.deltaFor('p0'), 0);
      expect(result.deltaFor('p4'), -1);
    });

    test('Steal a Life moves one life between two players', () {
      final result = run(
        pickEvents: const [
          PlayerPickEvent(
            playerId: 'p4',
            eventId: InterferenceCatalogue.stealLife,
          ),
        ],
        steals: const {'p4': 'p2'},
      );
      expect(result.deltaFor('p4'), 1);
      expect(result.deltaFor('p2'), -1);
    });

    test(
      'Double Imposter raises the count before assignment and caps at 4',
      () {
        final small = settingsFor(8, imposters: 2);
        expect(
          ImposterAssigner.countForRound(
            settings: small,
            roundModifier: InterferenceCatalogue.doubleImposter,
          ),
          3,
        );

        final atCap = settingsFor(10, imposters: 4);
        expect(
          ImposterAssigner.countForRound(
            settings: atCap,
            roundModifier: InterferenceCatalogue.doubleImposter,
          ),
          4,
          reason: 'already at the §2 maximum',
        );
        expect(
          ImposterAssigner.isDoubleImposterEligible(atCap),
          isFalse,
          reason: 'so §9c says reroll into a different event',
        );
      },
    );
  });

  group('§9f suppression', () {
    test('No Roundabouts removes every lap-dependent player-pick event', () {
      final suppressed = InterferenceCatalogue.lapDependentPlayerPickIds;
      expect(suppressed, isNotEmpty);
      for (final id in [
        InterferenceCatalogue.silentRound,
        InterferenceCatalogue.whisperOnly,
        InterferenceCatalogue.oneWordOnly,
        InterferenceCatalogue.copycat,
        InterferenceCatalogue.taboo,
        InterferenceCatalogue.liarsTax,
      ]) {
        expect(
          suppressed,
          contains(id),
          reason: '$id is lap-dependent and must be suppressed (§9f)',
        );
      }
      expect(
        suppressed,
        isNot(contains(InterferenceCatalogue.bonusLife)),
        reason: 'Bonus Life does not depend on a lap',
      );
    });
  });

  group('catalogue integrity', () {
    test('event ids are unique across both categories', () {
      final ids = InterferenceCatalogue.all.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('Sudden Death is the only cap bypass and is off by default', () {
      final bypassing = [
        for (final e in InterferenceCatalogue.all)
          if (e.bypassesDamageCap) e.id,
      ];
      expect(bypassing, [InterferenceCatalogue.suddenDeath]);

      final suddenDeath = InterferenceCatalogue.byId(
        InterferenceCatalogue.suddenDeath,
      )!;
      expect(suddenDeath.defaultEnabled, isFalse);
    });

    test('the §9b table is complete', () {
      expect(InterferenceCatalogue.playerPickEvents, hasLength(16));
    });

    test('the §9c table is complete', () {
      expect(InterferenceCatalogue.roundStartEvents, hasLength(21));
    });

    test('the §9d item list is complete', () {
      expect(InterferenceCatalogue.itemIds, hasLength(10));
    });
  });
}
