import 'package:diakooi/engine/engine.dart';
import 'package:test/test.dart';

import 'support.dart';

/// The §9a/§9c/§9f rules the roller owns: what may fire, and what may not.
void main() {
  List<Player> roster(int count) => [
    for (var i = 0; i < count; i++)
      Player(id: 'p$i', name: 'P$i', seatOrder: i, currentLives: 3),
  ];

  RoomSettings withInterference(
    InterferenceSettings interference, {
    int players = 6,
    int? imposters,
  }) => settingsFor(
    players,
    imposters: imposters,
    interference: interference,
  );

  const allOn = InterferenceSettings(
    enabled: true,
    playerPickEnabled: true,
    roundStartEnabled: true,
    itemsEnabled: true,
    playerPickProbability: 1,
  );

  group('nothing fires unless its own toggle is on (§9a)', () {
    test('the master switch gates all three groups', () {
      final settings = withInterference(
        const InterferenceSettings(
          playerPickEnabled: true,
          roundStartEnabled: true,
          itemsEnabled: true,
          playerPickProbability: 1,
        ),
      );
      final roll = InterferenceRoller.rollDetails(
        settings: settings,
        players: roster(6),
        imposterIds: const ['p0'],
        roundIndex: 3,
        roundModifier: InterferenceRoller.rollModifier(
          settings: settings,
          roundIndex: 3,
          rng: SeededRng(1),
        ),
        rng: SeededRng(1),
      );
      expect(
        roll.isEmpty,
        isTrue,
        reason:
            'the group toggles were on but the master switch was off — §9a '
            'makes it the gate over all three',
      );
    });

    test('round 1 is always clean, whatever the toggles say (§3, §9f)', () {
      final settings = withInterference(allOn);
      expect(
        InterferenceRoller.rollModifier(
          settings: settings,
          roundIndex: 0,
          rng: SeededRng(1),
        ),
        isNull,
      );
      expect(
        InterferenceRoller.rollDetails(
          settings: settings,
          players: roster(6),
          imposterIds: const ['p0'],
          roundIndex: 0,
          rng: SeededRng(1),
        ).isEmpty,
        isTrue,
        reason:
            'a modifier landing before anyone knows the base rules reads as '
            'the app being broken',
      );
    });

    test('a per-event checklist narrows the pool to exactly what is on', () {
      final settings = withInterference(
        allOn.copyWith(
          enabledEventIds: const [InterferenceCatalogue.mercyRound],
        ),
      );
      for (var seed = 0; seed < 50; seed++) {
        expect(
          InterferenceRoller.rollModifier(
            settings: settings,
            roundIndex: 2,
            rng: SeededRng(seed),
          ),
          InterferenceCatalogue.mercyRound,
          reason: '§9a: a host allowing one event must get only that one',
        );
      }
    });

    test('every event in both catalogues can be switched on alone', () {
      // The checklist is per-event, so each id has to be individually
      // reachable — a pool filter that quietly excluded one would leave a
      // checkbox that does nothing.
      for (final event in InterferenceCatalogue.roundStartEvents) {
        final settings = withInterference(
          allOn.copyWith(enabledEventIds: [event.id]),
          players: 8,
        );
        final rolled = InterferenceRoller.rollModifier(
          settings: settings,
          roundIndex: 2,
          rng: SeededRng(3),
        );
        expect(
          rolled,
          event.id,
          reason: '${event.name} could not be selected on its own',
        );
      }
    });
  });

  group('§9f suppression', () {
    test('No Roundabouts removes every lap-dependent event', () {
      final settings = withInterference(allOn);
      final suppressed = InterferenceRoller.eligible(
        settings: settings,
        category: EventCategory.playerPick,
        roundModifier: InterferenceCatalogue.noRoundabouts,
      ).map((e) => e.id).toSet();

      for (final id in InterferenceCatalogue.lapDependentPlayerPickIds) {
        expect(
          suppressed,
          isNot(contains(id)),
          reason:
              '$id needs a lap to happen in, and No Roundabouts goes straight '
              'to voting — it must be removed and rerolled, not left to fizzle',
        );
      }
      expect(
        suppressed,
        isNotEmpty,
        reason: 'suppression emptied the pool entirely',
      );
    });

    test('a normal round keeps them', () {
      final settings = withInterference(allOn);
      final pool = InterferenceRoller.eligible(
        settings: settings,
        category: EventCategory.playerPick,
      ).map((e) => e.id).toSet();

      for (final id in InterferenceCatalogue.lapDependentPlayerPickIds) {
        expect(pool, contains(id));
      }
    });

    test('a suppressed round still rolls something for everyone', () {
      final settings = withInterference(allOn);
      final roll = InterferenceRoller.rollDetails(
        settings: settings,
        players: roster(6),
        imposterIds: const ['p0'],
        roundIndex: 2,
        roundModifier: InterferenceCatalogue.noRoundabouts,
        rng: SeededRng(5),
      );
      expect(roll.playerPickEvents, hasLength(6));
      for (final pick in roll.playerPickEvents) {
        expect(
          InterferenceCatalogue.lapDependentPlayerPickIds,
          isNot(contains(pick.eventId)),
        );
      }
    });
  });

  group('§9c events that reach back into setup', () {
    test('Double Imposter raises the count before assignment', () {
      final settings = withInterference(allOn, players: 8, imposters: 2);
      expect(
        InterferenceRoller.imposterCountFor(
          settings: settings,
          roundModifier: InterferenceCatalogue.doubleImposter,
        ),
        3,
      );
      expect(
        InterferenceRoller.imposterCountFor(settings: settings),
        2,
        reason: 'without the modifier the host setting stands',
      );
    });

    test('it rerolls into something else when already at the cap', () {
      // §9c: at 4 it cannot raise anything, so rolling it would be a visible
      // no-op — the exact failure §9d calls the worst outcome.
      final settings = withInterference(allOn, players: 20, imposters: 4);
      for (var seed = 0; seed < 200; seed++) {
        expect(
          InterferenceRoller.rollModifier(
            settings: settings,
            roundIndex: 2,
            rng: SeededRng(seed),
          ),
          isNot(InterferenceCatalogue.doubleImposter),
        );
      }
    });

    test('it rerolls when the extra imposter would leave no crew', () {
      // Three players, two imposters: raising to three leaves nobody with the
      // real word, so there is no round to play.
      final settings = withInterference(allOn, players: 3, imposters: 2);
      for (var seed = 0; seed < 200; seed++) {
        expect(
          InterferenceRoller.rollModifier(
            settings: settings,
            roundIndex: 2,
            rng: SeededRng(seed),
          ),
          isNot(InterferenceCatalogue.doubleImposter),
        );
      }
    });

    test('it DOES fire at 3 players with 1 imposter — see proposal 0002', () {
      // Pinned because it looks like it should be blocked and is not. Raising
      // 1 to 2 at a table of three leaves a single crew member holding the
      // only real word, which the engine permits and which is playable only
      // in the thinnest sense.
      //
      // That is proposal 0002 finding 3 — imposter count has no floor on crew
      // — and it is a §2 range question, not a roller bug. Recorded here so
      // the interaction is visible while the proposal is open.
      final settings = withInterference(allOn, players: 3, imposters: 1);
      expect(
        InterferenceRoller.imposterCountFor(
          settings: settings,
          roundModifier: InterferenceCatalogue.doubleImposter,
        ),
        2,
      );

      var fired = false;
      for (var seed = 0; seed < 400 && !fired; seed++) {
        fired =
            InterferenceRoller.rollModifier(
              settings: settings,
              roundIndex: 2,
              rng: SeededRng(seed),
            ) ==
            InterferenceCatalogue.doubleImposter;
      }
      expect(
        fired,
        isTrue,
        reason:
            'if this starts failing, a crew floor was added — update '
            'proposal 0002 rather than deleting this test',
      );
    });

    test('Bodyguard picks a crew member, never an imposter', () {
      // The reason the roller has two phases at all: roles do not exist when
      // the modifier is drawn.
      final players = roster(8);
      const imposters = ['p0', 'p1'];
      for (var seed = 0; seed < 100; seed++) {
        final roll = InterferenceRoller.rollDetails(
          settings: withInterference(allOn, players: 8),
          players: players,
          imposterIds: imposters,
          roundIndex: 2,
          roundModifier: InterferenceCatalogue.bodyguard,
          rng: SeededRng(seed),
        );
        expect(roll.bodyguardPlayerId, isNotNull);
        expect(
          imposters,
          isNot(contains(roll.bodyguardPlayerId)),
          reason: '§9c makes Bodyguard a crew immunity',
        );
      }
    });
  });

  group('the item system gate (§9a, §9d)', () {
    test('item events vanish when the item system is off', () {
      final settings = withInterference(
        allOn.copyWith(itemsEnabled: false),
      );
      final pool = InterferenceRoller.eligible(
        settings: settings,
        category: EventCategory.playerPick,
      ).map((e) => e.id);
      expect(pool, isNot(contains(InterferenceCatalogue.mysteryItem)));

      final modifiers = InterferenceRoller.eligible(
        settings: settings,
        category: EventCategory.roundStart,
      ).map((e) => e.id);
      expect(modifiers, isNot(contains(InterferenceCatalogue.itemDrop)));
    });

    test('Item Drop hands one to everybody', () {
      final roll = InterferenceRoller.rollDetails(
        settings: withInterference(allOn),
        players: roster(6),
        imposterIds: const ['p0'],
        roundIndex: 2,
        roundModifier: InterferenceCatalogue.itemDrop,
        rng: SeededRng(2),
      );
      expect(roll.itemGrants, hasLength(6));
      for (final id in roll.itemGrants.values) {
        expect(InterferenceCatalogue.itemIds, contains(id));
      }
    });

    test('one held at a time, and a second pickup asks first', () {
      var player = const Player(
        id: 'p0',
        name: 'Ana',
        seatOrder: 0,
        currentLives: 3,
      );

      final first = ItemSystem.offer(
        player: player,
        itemId: InterferenceCatalogue.itemShield,
      );
      expect(first.needsDecision, isFalse);
      player = ItemSystem.take(
        player: player,
        itemId: InterferenceCatalogue.itemShield,
      );
      expect(player.heldItem, InterferenceCatalogue.itemShield);

      final second = ItemSystem.offer(
        player: player,
        itemId: InterferenceCatalogue.itemVeto,
      );
      expect(
        second.needsDecision,
        isTrue,
        reason:
            '§9d: silent fizzling is the worst outcome for a surprise system, '
            'so the holder is asked rather than swapped',
      );
      expect(
        player.heldItem,
        InterferenceCatalogue.itemShield,
        reason: 'offering must change nothing until the player decides',
      );
    });

    test('Wild Card never rerolls into another Wild Card', () {
      for (var seed = 0; seed < 200; seed++) {
        expect(
          ItemSystem.resolveOnUse(
            itemId: InterferenceCatalogue.itemWildCard,
            rng: SeededRng(seed),
          ),
          isNot(InterferenceCatalogue.itemWildCard),
        );
      }
    });

    test('an unknown item is refused rather than stored', () {
      expect(
        () => ItemSystem.take(
          player: const Player(
            id: 'p0',
            name: 'Ana',
            seatOrder: 0,
            currentLives: 3,
          ),
          itemId: 'item_not_real',
        ),
        throwsArgumentError,
      );
    });
  });

  group('§9f banners: the table is armed, but not for the secrets', () {
    test('every social event shows a banner', () {
      for (final event in InterferenceCatalogue.all) {
        if (event.enforcement != EventEnforcement.social) continue;
        if (InterferenceCatalogue.secretEventIds.contains(event.id)) continue;
        expect(
          InterferenceCatalogue.showsConstraintBanner(event),
          isTrue,
          reason:
              '${event.name} cannot be detected by the app, so the banner is '
              'the only thing arming the table to police it (§9f)',
        );
      }
    });

    test('the three secret constraints never do', () {
      // §9f: Taboo, Liar's Tax and The Fool are revealed in the round recap,
      // where the "oh, THAT is what happened" payoff lives. A banner would
      // spend it early.
      for (final id in InterferenceCatalogue.secretEventIds) {
        final event = InterferenceCatalogue.byId(id)!;
        expect(
          InterferenceCatalogue.showsConstraintBanner(event),
          isFalse,
          reason: '${event.name} is secret and must not be announced',
        );
      }
    });

    test('app-enforced player events do not clutter the banner', () {
      // The banner arms the table to police something. Bonus Life needs no
      // policing, and a banner listing it is noise that makes the real
      // constraints harder to see.
      final event = InterferenceCatalogue.byId(
        InterferenceCatalogue.bonusLife,
      )!;
      expect(InterferenceCatalogue.showsConstraintBanner(event), isFalse);
    });
  });

  group('A6 catalogue audit: a query, not a re-read', () {
    test('every event carries requiresColocation and requiresItemSystem', () {
      for (final event in InterferenceCatalogue.all) {
        expect(event.requiresColocation, isA<bool>(), reason: event.id);
        expect(event.requiresItemSystem, isA<bool>(), reason: event.id);
      }
    });

    test('exactly the item events require the item system', () {
      final flagged = [
        for (final event in InterferenceCatalogue.all)
          if (event.requiresItemSystem) event.id,
      ]..sort();
      expect(flagged, [
        InterferenceCatalogue.itemDrop,
        InterferenceCatalogue.mysteryItem,
      ]);
    });

    test('Sudden Death is the only event off by default', () {
      final off = [
        for (final event in InterferenceCatalogue.all)
          if (!event.defaultEnabled) event.id,
      ];
      expect(off, [InterferenceCatalogue.suddenDeath]);
    });

    test('Sudden Death is the only event that bypasses the §7b cap', () {
      final bypass = [
        for (final event in InterferenceCatalogue.all)
          if (event.bypassesDamageCap) event.id,
      ];
      expect(bypass, [InterferenceCatalogue.suddenDeath]);
    });
  });
}
