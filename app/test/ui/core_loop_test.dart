import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:diakooi/content/topics.dart';
import 'package:diakooi/content/word_bank.dart';
import 'package:diakooi/engine/engine.dart';
import 'package:diakooi/game/game_providers.dart';
import 'package:diakooi/selfie/selfie_bytes.dart';
import 'package:diakooi/selfie/selfie_capture.dart';
import 'package:diakooi/theme/motion.dart';
import 'package:diakooi/theme/vibe_loader.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/theme/vibe_providers.dart';
import 'package:diakooi/ui/primitives/primitives.dart';
import 'package:diakooi/ui/screens/game_shell.dart';
import 'package:diakooi/ui/widgets/selfie_capture_view.dart';
import 'package:diakooi/ui/widgets/vibe_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden/support.dart';

/// The core loop, driven through the widgets rather than the controller.
///
/// A4 asks whether every FSM transition is **reachable from the UI**. The
/// controller test proves the machine is sound; this proves the buttons that
/// walk it actually exist and are enabled at the right moments, which is a
/// different claim and the one a table experiences.
void main() {
  late VibePackLibrary library;

  setUpAll(() async {
    const loader = VibePackLoader(source: DiskVibePackSource());
    library = await loader.loadAll();
  });

  Widget app({bool disableAnimations = false}) => ProviderScope(
    overrides: [
      // Assets read off disk rather than through rootBundle, which a widget
      // test does not populate for the vibes directory.
      vibeLibraryProvider.overrideWith((ref) async => library),
      vibeRngProvider.overrideWithValue(SeededRng(1)),
      gameRngProvider.overrideWithValue(SeededRng(1)),
      wordBankProvider.overrideWith((ref) async => _bank()),
      selfieCameraProvider.overrideWithValue(_FakeCamera.new),
    ],
    child: MaterialApp(
      home: disableAnimations
          ? Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: true),
                child: const GameShell(),
              ),
            )
          : const GameShell(),
    ),
  );

  Future<void> boot(
    WidgetTester tester, {
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(app(disableAnimations: disableAnimations));
    await tester.pumpAndSettle();
  }

  Future<void> tapLabel(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(VibeButton, label));
    await tester.pumpAndSettle();
  }

  /// Walks host setup, then seats [count] players.
  ///
  /// The steppers appear in §2 order — players, lives, rounds, roundabouts —
  /// so their icon buttons can be addressed by position.
  Future<void> seat(
    WidgetTester tester, {
    required int count,
    int? rounds,
    bool captureSelfies = false,
  }) async {
    // The player stepper starts at 6.
    final more = find.widgetWithIcon(IconButton, Icons.add_circle_outline);
    final fewer = find.widgetWithIcon(IconButton, Icons.remove_circle_outline);
    for (var i = 6; i < count; i++) {
      await tester.tap(more.first);
      await tester.pump();
    }
    for (var i = 6; i > count; i--) {
      await tester.tap(fewer.first);
      await tester.pump();
    }
    if (rounds != null) {
      for (var i = 8; i > rounds; i--) {
        await tester.tap(fewer.at(2));
        await tester.pump();
      }
    }
    await tester.pumpAndSettle();
    await tapLabel(tester, 'Start — $count players');
    await tapLabel(tester, 'Start');

    for (var i = 0; i < count; i++) {
      await tester.enterText(find.byType(TextField), 'P${i + 1}');
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Next');
      await tapLabel(tester, captureSelfies ? 'Take it' : 'Skip');
      await tapLabel(tester, 'Looks good');
    }
  }

  /// Holds the card until it is actually legible, then releases.
  ///
  /// Pumped in steps rather than for a fixed duration: the reveal springs on
  /// the pack's own motion profile, so a slow pack takes longer to become
  /// readable than a fast one and a hardcoded 300ms would pass on Sayaw and
  /// fail on Tahimik.
  Future<void> readCard(WidgetTester tester) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(RevealCard)),
    );
    var pumps = 0;
    while (pumps < 60) {
      await tester.pump(const Duration(milliseconds: 32));
      pumps++;
      final button = tester.widgetList<VibeButton>(
        find.widgetWithText(VibeButton, 'Done — pass it on'),
      );
      if (button.isNotEmpty && button.first.onPressed != null) break;
    }
    expect(
      pumps,
      lessThan(60),
      reason:
          'the card never became legible — a reveal that cannot finish in two '
          'seconds of held press is broken, whatever the pack tempo',
    );
    await gesture.up();
    await tester.pumpAndSettle();
  }

  /// Hands the phone round so every player sees their card.
  Future<void> distribute(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await tapLabel(tester, 'I am P${i + 1}');
      await readCard(tester);
      await tapLabel(tester, 'Done — pass it on');
    }
    await tapLabel(tester, 'Start the roundabout');
  }

  Future<void> discuss(WidgetTester tester) async {
    await tapLabel(tester, 'Skip to the vote');
  }

  /// Every player accuses the next seat along.
  Future<void> voteAround(WidgetTester tester, int count) async {
    for (var i = 0; i < count; i++) {
      await tester.tap(find.widgetWithText(PlayerTile, 'P${i + 1}'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(PlayerTile, 'P${(i + 1) % count + 1}'),
      );
      await tester.pumpAndSettle();
    }
  }

  group('a whole game, played through the UI', () {
    testWidgets('four players reach the summary and start again', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await boot(tester);
      await seat(tester, count: 4);

      await tapLabel(tester, 'Deal the first round');
      await distribute(tester, 4);
      await discuss(tester);
      await voteAround(tester, 4);

      expect(
        find.widgetWithText(VibeButton, 'Reveal'),
        findsOneWidget,
        reason: 'four ballots recorded, so the round can resolve',
      );
      await tapLabel(tester, 'Reveal');
      await tapLabel(tester, 'Life check');

      // Either straight on, or a consequence to write first.
      if (find.byType(TextField).evaluate().isNotEmpty) {
        await tester.enterText(find.byType(TextField), 'Sayaw ng budots');
        await tester.pumpAndSettle();
        await tapLabel(tester, 'Served');
      }
      await tapLabel(tester, 'End the game here');

      expect(find.text('Tapos na'), findsOneWidget);
      await tapLabel(tester, 'What next?');
      expect(find.text('Ulit?'), findsOneWidget);

      await tapLabel(tester, 'Play again — same 4');
      expect(
        find.text("Tonight's vibe"),
        findsOneWidget,
        reason: 'Play Again re-enters at VIBE_ROLL so the pack rerolls (§10)',
      );
    });

    testWidgets('New Game clears the table and shreds the selfies', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await boot(tester);
      await seat(tester, count: 3, captureSelfies: true);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GameShell)),
      );
      final selfies = [
        for (final seat in container.read(gameSessionProvider).seats)
          seat.selfie!,
      ];
      expect(selfies, hasLength(3));

      await tapLabel(tester, 'Deal the first round');
      await distribute(tester, 3);
      await discuss(tester);
      await voteAround(tester, 3);
      await tapLabel(tester, 'Reveal');
      await tapLabel(tester, 'Life check');
      if (find.byType(TextField).evaluate().isNotEmpty) {
        await tester.enterText(find.byType(TextField), 'Kumanta');
        await tester.pumpAndSettle();
        await tapLabel(tester, 'Served');
      }
      await tapLabel(tester, 'End the game here');
      await tapLabel(tester, 'What next?');
      await tapLabel(tester, 'New game');

      expect(container.read(gameSessionProvider).seats, isEmpty);
      for (final selfie in selfies) {
        expect(
          selfie.isShredded,
          isTrue,
          reason:
              'New Game is the one point where the roster ends, so it is the '
              'one point where the bytes stop being resident (§4b)',
        );
      }
      expect(find.text('Set up the game'), findsOneWidget);
    });
  });

  group('host setup (§2)', () {
    testWidgets('Large Group Mode announces itself at 13, not at 12', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await boot(tester);

      final more = find.widgetWithIcon(IconButton, Icons.add_circle_outline);
      for (var i = 6; i < 12; i++) {
        await tester.tap(more.first);
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.textContaining('one roundabout, tighter'), findsNothing);

      await tester.tap(more.first);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('one roundabout, tighter'),
        findsOneWidget,
        reason: '§2a engages at 13 and says so, because it changes the pacing',
      );
    });

    testWidgets('the host-as-player warning explains the cost (§2b)', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await boot(tester);

      expect(
        find.text('No — the host runs the phone'),
        findsOneWidget,
        reason: '§2b is default-off',
      );
      await tester.tap(find.text('No — the host runs the phone'));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .byWidgetPredicate(
              (w) => w is Switch && !w.value,
              description: 'the host-as-player switch',
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('information nobody else has'),
        findsOneWidget,
      );
    });

    testWidgets('every topic slider stops at the derived ceiling', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await boot(tester);

      // The default mix is Barkada Classic — all twelve topics.
      final twelve = TopicSelector.ceilingPercentFor(12);
      expect(find.text('12 topics in the mix'), findsOneWidget);
      expect(find.text('max $twelve%'), findsOneWidget);
      for (final slider in tester.widgetList<Slider>(find.byType(Slider))) {
        expect(
          slider.max,
          twelve.toDouble(),
          reason:
              'derived from the enabled topic count, never a constant '
              '(proposal 0001)',
        );
      }

      // Turning a topic off changes the count, and the bound has to move with
      // it — that is the whole reason it is derived rather than stored. The
      // last switch on the screen is the last topic row; the ones above it
      // belong to the §2 settings.
      await tester.tap(find.byType(Switch).last);
      await tester.pumpAndSettle();

      final eleven = TopicSelector.ceilingPercentFor(11);
      expect(find.text('11 topics in the mix'), findsOneWidget);
      expect(find.text('max $eleven%'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GameShell)),
      );
      expect(container.read(gameSessionProvider).phase, GamePhase.lobby);
    });
  });

  group('voting (§7)', () {
    testWidgets('a self-vote is refused and a double vote is impossible', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await boot(tester);
      await seat(tester, count: 3);
      await tapLabel(tester, 'Deal the first round');
      await distribute(tester, 3);
      await discuss(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GameShell)),
      );

      await tester.tap(find.widgetWithText(PlayerTile, 'P1'));
      await tester.pumpAndSettle();
      // P1 is the caller; tapping P1 again must record nothing.
      await tester.tap(find.widgetWithText(PlayerTile, 'P1'));
      await tester.pumpAndSettle();
      expect(container.read(gameSessionProvider).pendingVotes, isEmpty);

      await tester.tap(find.widgetWithText(PlayerTile, 'P2'));
      await tester.pumpAndSettle();
      expect(container.read(gameSessionProvider).pendingVotes, hasLength(1));

      // P1 has voted, so selecting them as a caller again does nothing.
      await tester.tap(find.widgetWithText(PlayerTile, 'P1'));
      await tester.pumpAndSettle();
      expect(container.read(gameSessionProvider).selectedVoterId, isNull);
    });

    testWidgets('Reveal stays disabled until every ballot is in', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await boot(tester);
      await seat(tester, count: 3);
      await tapLabel(tester, 'Deal the first round');
      await distribute(tester, 3);
      await discuss(tester);

      expect(find.text('Waiting on 3'), findsOneWidget);
      await tester.tap(find.widgetWithText(PlayerTile, 'P1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PlayerTile, 'P2'));
      await tester.pumpAndSettle();

      expect(
        find.text('Waiting on 2'),
        findsOneWidget,
        reason:
            'the progress count is what stops a host resolving early and '
            'handing someone a forfeit they had no say in (§7)',
      );
      expect(find.widgetWithText(VibeButton, 'Reveal'), findsNothing);
    });
  });

  group('the bank the app actually ships', () {
    testWidgets('host setup opens on a startable mix', (tester) async {
      // The synthetic bank the other tests use holds every catalogue topic.
      // The shipped one holds five, and against it every preset produced a
      // mix totalling 44 — invalid under §13b, Start disabled, no game
      // startable. A fixture more complete than reality proves nothing about
      // reality, so this one reads the real asset off disk.
      await tester.binding.setSurfaceSize(const Size(500, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final shipped = WordBank.fromJson(
        jsonDecode(File(WordBank.assetPath).readAsStringSync())
            as Map<String, dynamic>,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vibeLibraryProvider.overrideWith((ref) async => library),
            vibeRngProvider.overrideWithValue(SeededRng(1)),
            gameRngProvider.overrideWithValue(SeededRng(1)),
            wordBankProvider.overrideWith((ref) async => shipped),
            selfieCameraProvider.overrideWithValue(_FakeCamera.new),
          ],
          child: const MaterialApp(home: GameShell()),
        ),
      );
      await tester.pumpAndSettle();

      final start = tester.widget<VibeButton>(
        find.widgetWithText(VibeButton, 'Start — 6 players'),
      );
      expect(
        start.onPressed,
        isNotNull,
        reason:
            'Start is disabled, which means the default topic mix does not '
            'total 100 against the bank this build ships',
      );

      // And the mix it opens on is one the engine will accept.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GameShell)),
      );
      await tapLabel(tester, 'Start — 6 players');
      expect(
        container
            .read(gameSessionProvider)
            .settings
            .topicWeights
            .fold<int>(
              0,
              (sum, w) => sum + w.weightPercent,
            ),
        100,
      );
    });
  });

  group('reduced motion (A5)', () {
    testWidgets('disableAnimations reaches the theme and the whole game '
        'still plays', (tester) async {
      // The A5 item is "MediaQuery.disableAnimations honoured throughout".
      // Honoured means two things and this checks both: the flag reaches the
      // theme, and every screen still works with the motion collapsed. An
      // animation that was load-bearing would strand the flow here.
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await boot(tester, disableAnimations: true);

      final vibe = Theme.of(
        tester.element(find.byType(VibeScaffold).first),
      ).extension<VibeTheme>()!;
      expect(
        vibe.reduceMotion,
        isTrue,
        reason: 'the platform setting never reached the pack theme',
      );
      expect(vibe.beats.stagger, Duration.zero);
      expect(
        vibe.palette,
        isNotNull,
        reason: 'motion is collapsed, the palette is not (§6)',
      );

      await seat(tester, count: 3);
      await tapLabel(tester, 'Deal the first round');
      await distribute(tester, 3);
      await discuss(tester);
      await voteAround(tester, 3);
      await tapLabel(tester, 'Reveal');
      await tapLabel(tester, 'Life check');
      while (find.byType(TextField).evaluate().isNotEmpty) {
        await tester.enterText(find.byType(TextField), 'Sayaw');
        await tester.pumpAndSettle();
        await tapLabel(
          tester,
          find
                  .widgetWithText(VibeButton, 'Served — one more')
                  .evaluate()
                  .isNotEmpty
              ? 'Served — one more'
              : 'Served',
        );
      }
      await tapLabel(tester, 'End the game here');
      expect(find.text('Tapos na'), findsOneWidget);
    });

    testWidgets('no animation blocks input', (tester) async {
      // Taps land on the frame after they happen, mid-animation, without a
      // pumpAndSettle anywhere. An animation that swallowed input or had to
      // finish first would fail here and nowhere else — pumpAndSettle in every
      // other test hides exactly this.
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await boot(tester);
      await tapLabel(tester, 'Start — 6 players');
      await tapLabel(tester, 'Start');

      await tester.enterText(find.byType(TextField), 'Ana');
      await tester.pump();
      await tester.tap(find.widgetWithText(VibeButton, 'Next'));
      await tester.pump();

      // The develop sequence is running now. Tap straight through it.
      await tester.tap(find.widgetWithText(VibeButton, 'Skip'));
      await tester.pump();
      expect(
        find.widgetWithText(VibeButton, 'Looks good'),
        findsOneWidget,
        reason: 'the capture step did not respond during its own animation',
      );

      await tester.tap(find.widgetWithText(VibeButton, 'Looks good'));
      await tester.pump();
      expect(
        find.text('Player 2 of 6'),
        findsOneWidget,
        reason:
            'the develop had to finish before the next player could be '
            'seated — the beat is blocking, not decorative',
      );
    });

    testWidgets('the reveal is interruptible mid-clear', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await boot(tester);
      await seat(tester, count: 3);
      await tapLabel(tester, 'Deal the first round');
      await tapLabel(tester, 'I am P1');

      // Press, let it start clearing, release before it finishes, press again.
      final card = find.byType(RevealCard);
      var gesture = await tester.startGesture(tester.getCenter(card));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      await gesture.up();
      await tester.pump();

      expect(
        tester
            .widget<VibeButton>(
              find.widgetWithText(VibeButton, 'Done — pass it on'),
            )
            .onPressed,
        isNull,
        reason: 'a glance that never became legible must not count as read',
      );

      gesture = await tester.startGesture(tester.getCenter(card));
      await tester.pump();
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 32));
        final button = tester.widgetList<VibeButton>(
          find.widgetWithText(VibeButton, 'Done — pass it on'),
        );
        if (button.isNotEmpty && button.first.onPressed != null) break;
      }
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<VibeButton>(
              find.widgetWithText(VibeButton, 'Done — pass it on'),
            )
            .onPressed,
        isNotNull,
        reason:
            'a re-press after an interrupted hold must still be able to '
            'complete',
      );
    });
  });

  group('reachability (A4)', () {
    testWidgets('the UI walks every transition §3 draws', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await boot(tester);
      await seat(tester, count: 3, rounds: 3);
      await tapLabel(tester, 'Deal the first round');

      for (var round = 0; round < 3; round++) {
        if (round > 0) await tapLabel(tester, 'Deal');
        await distribute(tester, 3);
        await discuss(tester);
        await voteAround(tester, 3);
        await tapLabel(tester, 'Reveal');
        await tapLabel(tester, 'Life check');
        while (find.byType(TextField).evaluate().isNotEmpty) {
          await tester.enterText(find.byType(TextField), 'Sayaw');
          await tester.pumpAndSettle();
          await tapLabel(
            tester,
            find
                    .widgetWithText(VibeButton, 'Served — one more')
                    .evaluate()
                    .isNotEmpty
                ? 'Served — one more'
                : 'Served',
          );
        }
        await tapLabel(
          tester,
          round == 2 ? 'See how it went' : 'Next round',
        );
      }

      expect(
        find.text('Tapos na'),
        findsOneWidget,
        reason: 'three rounds is the round limit, so the game ends by itself',
      );
      await tapLabel(tester, 'What next?');
      await tapLabel(tester, 'Play again — same 3');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GameShell)),
      );
      final replayed = container
          .read(gameSessionProvider.notifier)
          .transitionTrail
          .toSet();

      // A second game, ended the other way, to reach replayPrompt -> lobby.
      // Play Again keeps the roster (§10), so the same three players are still
      // seated and onboarding goes straight to the deal.
      await tapLabel(tester, 'Start');
      await tapLabel(tester, 'Deal the first round');
      await distribute(tester, 3);
      await discuss(tester);
      await voteAround(tester, 3);
      await tapLabel(tester, 'Reveal');
      await tapLabel(tester, 'Life check');
      while (find.byType(TextField).evaluate().isNotEmpty) {
        await tester.enterText(find.byType(TextField), 'Kanta');
        await tester.pumpAndSettle();
        await tapLabel(
          tester,
          find
                  .widgetWithText(VibeButton, 'Served — one more')
                  .evaluate()
                  .isNotEmpty
              ? 'Served — one more'
              : 'Served',
        );
      }
      await tapLabel(tester, 'End the game here');
      await tapLabel(tester, 'What next?');
      await tapLabel(tester, 'New game');

      final walked = {
        ...replayed,
        ...container.read(gameSessionProvider.notifier).transitionTrail,
      };
      final all = <String>{
        for (final entry in GameMachine.transitions.entries)
          for (final to in entry.value) '${entry.key.name}->${to.name}',
      };

      // The two edges the base game cannot reach both need a round with zero
      // roundabouts, which only the §9c No Roundabouts modifier produces.
      // Interference is Phase 5, and naming them here means wiring them will
      // fail this test rather than passing unnoticed.
      expect(all.difference(walked), {
        'roundStart->votingPhase',
        'wordDistribution->votingPhase',
      });
      expect(find.text('Set up the game'), findsOneWidget);
    });

    testWidgets('a 20-player table seats everyone and plays a round', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(500, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await boot(tester);
      await seat(tester, count: 20);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GameShell)),
      );
      final settings = container.read(gameSessionProvider).settings;
      expect(settings.playerCount, 20);
      expect(settings.largeGroupMode, isTrue);
      expect(
        settings.effectiveRoundabouts,
        1,
        reason: 'twenty people times two laps is forty turns (§2a)',
      );

      await tapLabel(tester, 'Deal the first round');
      expect(
        find.textContaining('Big table'),
        findsOneWidget,
        reason: 'the §2a pace hint rides on the pass screen',
      );
      await distribute(tester, 20);
      await discuss(tester);
      await voteAround(tester, 20);

      expect(container.read(gameSessionProvider).votesRecorded, 20);
      await tapLabel(tester, 'Reveal');
      expect(container.read(gameSessionProvider).lastResolution, isNotNull);
    });
  });

  group('onboarding (§4)', () {
    testWidgets('Skip gives a monogram, not an error state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await boot(tester);
      await tapLabel(tester, 'Start — 6 players');
      await tapLabel(tester, 'Start');

      await tester.enterText(find.byType(TextField), 'Ana');
      await tester.pumpAndSettle();
      await tapLabel(tester, 'Next');
      await tapLabel(tester, 'Skip');

      expect(find.byType(MonogramBadge), findsOneWidget);
      expect(
        find.text('AN'),
        findsNothing,
        reason: 'one word gives one letter',
      );
      await tapLabel(tester, 'Looks good');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(GameShell)),
      );
      final seats = container.read(gameSessionProvider).seats;
      expect(seats.single.player.name, 'Ana');
      expect(seats.single.selfie, isNull);
    });
  });
}

WordBank _bank() => WordBank(
  contentVersion: 'test',
  isPlaceholder: true,
  entries: [
    // Every catalogue topic, because the default preset is Barkada Classic
    // and a bank that cannot fill one of its topics is a different test.
    for (final topic in TopicCatalogue.topics)
      for (var i = 0; i < 30; i++)
        WordBankEntry(
          topicId: topic.id,
          word: '${topic.id}-$i',
          clues: ClueSet(
            tight: 'tight $i',
            standard: 'standard $i',
            loose: 'loose $i',
          ),
        ),
  ],
);

/// A real 1x1 PNG.
///
/// Zeroed bytes would decode to nothing and the avatar would silently render
/// an error box, which is the kind of pass that proves less than it looks like.
Uint8List _onePixelPng() => base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
  'hQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// A camera that always yields the same tiny frame.
///
/// The real one is not usable in a widget test — there is no plugin — and
/// forcing every onboarding test through the monogram path would leave the
/// captured-selfie branch untested.
class _FakeCamera implements SelfieCamera {
  @override
  Future<bool> initialize() async => true;

  @override
  Widget buildPreview(BuildContext context) => const SizedBox.expand();

  @override
  Future<SelfieOutcome> capture() async => SelfieCaptured(
    SelfieBytes(polaroid: _onePixelPng(), gridTile: _onePixelPng()),
  );

  @override
  Future<void> dispose() async {}
}
