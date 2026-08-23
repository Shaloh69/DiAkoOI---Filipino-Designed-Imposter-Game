import 'package:diakooi/engine/engine.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/screens/event_debug_screen.dart';
import 'package:diakooi/ui/widgets/interference_card.dart';
import 'package:diakooi/ui/widgets/interference_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden/support.dart';

/// The A6 items that live in the UI rather than in the engine.
Future<void> main() async {
  final packs = await loadAllPacks();

  Widget wrap(Widget child, {int packIndex = 0}) => MaterialApp(
    theme: VibeTheme.materialThemeFor(packs[packIndex]),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  group('every event is reachable in the debug menu (A6)', () {
    testWidgets('all of them are listed, and each renders when tapped', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // VibeScaffold carries the mute button, which reads a provider, so the
      // screen needs a scope even though the screen itself takes none.
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: VibeTheme.materialThemeFor(packs.first),
            home: const EventDebugScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Reading the catalogue proves nothing about the catalogue. Each event
      // has to actually render, which is what "verified end to end" means.
      for (final event in InterferenceCatalogue.all) {
        final tile = find.text(event.name);
        await tester.scrollUntilVisible(tile, 200);
        await tester.tap(tile);
        await tester.pumpAndSettle();

        if (event.id == InterferenceCatalogue.nothing) {
          // §9b's "Nothing" is the outcome that keeps rolls genuinely
          // uncertain. It is the one event that correctly shows no card, and
          // asserting that is better than quietly skipping it.
          expect(
            find.byType(InterferenceCard),
            findsNothing,
            reason:
                '"Nothing" put a card on screen — the whole point is that a '
                'roll can come back empty',
          );
          continue;
        }
        expect(
          find.byType(InterferenceCard),
          findsWidgets,
          reason: '${event.name} rendered no card',
        );
      }
    });
  });

  group('the interference card is not the reveal card (A6, §9e)', () {
    testWidgets('it is chamfered where the reveal card is rounded', (
      tester,
    ) async {
      // Shape, not just colour — a pack whose accent sits close to its surface
      // would otherwise lose the distinction entirely (§6).
      await tester.pumpWidget(
        wrap(
          const InterferenceCard(title: 'Interference', body: 'Life Drain'),
        ),
      );
      await tester.pumpAndSettle();

      final decoration = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<ShapeDecoration>()
          .firstWhere((d) => d.shape is BeveledRectangleBorder);

      expect(
        decoration.shape,
        isA<BeveledRectangleBorder>(),
        reason:
            'the word card is a RoundedRectangleBorder; §9e says nobody '
            'should be able to confuse the two',
      );
      expect(
        decoration.color,
        packs.first.palette.interference,
        reason: 'the card must ride the pack accent, not a house colour',
      );
    });

    testWidgets('it looks different on every pack', (tester) async {
      final colours = <Color>{};
      for (var i = 0; i < packs.length; i++) {
        await tester.pumpWidget(
          wrap(
            const InterferenceCard(title: 'This round', body: 'Mercy Round'),
            packIndex: i,
          ),
        );
        await tester.pumpAndSettle();
        colours.add(packs[i].palette.interference);
      }
      expect(
        colours.length,
        greaterThan(1),
        reason:
            '§9e: interference is driven by the pack accent so it looks '
            'different every session',
      );
    });

    testWidgets('reduced motion drops the skew and keeps the signal', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VibeTheme.materialThemeFor(packs.first, reduceMotion: true),
          home: const Scaffold(
            body: InterferenceCard(title: 'Interference', body: 'Taboo'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scoped to the card: Material puts Transforms of its own in the tree,
      // and an unscoped finder would fail on those rather than on ours.
      expect(
        find.descendant(
          of: find.byType(InterferenceCard),
          matching: find.byType(Transform),
        ),
        findsNothing,
        reason:
            'reduced motion must not rotate or scale — the accent still '
            'carries the signal (§6)',
      );
      expect(find.text('Taboo'), findsOneWidget);
    });
  });

  group('the §9a toggle tree', () {
    testWidgets('sub-toggles and checklists appear only under the master', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var settings = const InterferenceSettings();
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => InterferenceSetup(
              settings: settings,
              onChanged: (value) => setState(() => settings = value),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Player events'),
        findsNothing,
        reason: 'Interference is off by default and hides its own detail',
      );

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(find.text('Player events'), findsOneWidget);
      expect(find.text('Round events'), findsOneWidget);
      expect(find.text('Items'), findsOneWidget);
      expect(
        settings.playerPickEnabled,
        isFalse,
        reason:
            'the master switch reveals the groups; it must not silently turn '
            'them on (§9a)',
      );
    });

    testWidgets('turning one event off narrows the pool by exactly one', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var settings = const InterferenceSettings(
        enabled: true,
        roundStartEnabled: true,
      );
      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) => InterferenceSetup(
              settings: settings,
              onChanged: (value) => setState(() => settings = value),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final before = InterferenceRoller.eligible(
        settings: _roomWith(settings),
        category: EventCategory.roundStart,
      ).length;

      await tester.scrollUntilVisible(find.text('Mercy Round'), 200);
      await tester.tap(find.text('Mercy Round'));
      await tester.pumpAndSettle();

      final after = InterferenceRoller.eligible(
        settings: _roomWith(settings),
        category: EventCategory.roundStart,
      );
      expect(after, hasLength(before - 1));
      expect(
        after.map((e) => e.id),
        isNot(contains(InterferenceCatalogue.mercyRound)),
        reason: '§9a: a host disabling one event must get exactly that',
      );
    });

    testWidgets('Sudden Death starts unchecked', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 6000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const settings = InterferenceSettings(
        enabled: true,
        roundStartEnabled: true,
      );
      await tester.pumpWidget(
        wrap(
          InterferenceSetup(settings: settings, onChanged: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Sudden Death'), 200);
      final tile = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Sudden Death'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(
        tile.value,
        isFalse,
        reason:
            '§9c puts Sudden Death off by default — it bypasses the §7b cap '
            'and a host should have to reach for it',
      );
    });
  });
}

RoomSettings _roomWith(InterferenceSettings interference) =>
    RoomSettings.validated(
      playerCount: 6,
      topicWeights: const [
        TopicWeight(topicId: 'pagkain', weightPercent: 100),
      ],
      interference: interference,
    );
