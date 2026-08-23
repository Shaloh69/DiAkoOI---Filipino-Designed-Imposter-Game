import 'dart:io';
import 'dart:math' as math;

import 'package:diakooi/theme/motion.dart';
import 'package:diakooi/theme/vibe_pack.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/motion/reveal_machine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden/support.dart';

/// The A5 items that close without the handset.
///
/// Frame times need the V60 Lite and are not guessed at here or anywhere else.
/// What *is* checkable off-device: that no animation names its own duration,
/// that every one of them has a reduced-motion path, that
/// `MediaQuery.disableAnimations` reaches all of them, and that nothing blocks
/// input while it runs.
Future<void> main() async {
  final packs = await loadAllPacks();

  VibeTheme themeFor(VibePack pack, {bool reduceMotion = false}) =>
      VibeTheme(pack: pack, reduceMotion: reduceMotion);

  group('no animation names its own duration', () {
    // The static half of the rule. A widget test only catches the animations
    // it happens to drive, and a hardcoded 300ms in a screen nobody pumped
    // would sail through — so the source is scanned as well.
    //
    // Derived durations are fine: `Duration(milliseconds: total)` where total
    // came from the pack is exactly what the rule wants. Only *numeric
    // literals* are the defect.
    final literalDuration = RegExp(
      r'Duration\(\s*(days|hours|minutes|seconds|milliseconds|microseconds)'
      r'\s*:\s*[0-9]',
    );

    /// Files allowed to hold a literal, each for a stated reason. Anything not
    /// on this list is a failure, and the list is asserted to be exactly this
    /// so adding one requires editing the test.
    const exempt = <String, String>{
      // The theme is where durations are allowed to come from.
      'lib/theme/motion.dart': 'defines the beats every animation reads',
      'lib/theme/vibe_pack.dart': 'the pack model itself',
      'lib/theme/vibe_theme.dart': 'the reduced-motion fade length',
      'lib/theme/frame_budget.dart': 'a frame budget, not an animation',
      // A one-second tick is a clock, not a design timing. It does not change
      // per pack and should not: a slow pack must not make a timer slower.
      'lib/ui/screens/discussion_screen.dart':
          'the §6 clue timer ticks in '
          'real seconds, not in beats',
    };

    test('lib/ holds no literal animation duration outside the theme', () {
      final offenders = <String>[];
      var scanned = 0;

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('.g.dart') ||
            entity.path.endsWith('.freezed.dart')) {
          continue;
        }
        final normalised = entity.path.replaceAll(r'\', '/');
        if (exempt.containsKey(normalised)) continue;
        scanned++;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final trimmed = lines[i].trimLeft();
          if (trimmed.startsWith('//')) continue;
          if (literalDuration.hasMatch(lines[i])) {
            offenders.add('$normalised:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(
        scanned,
        greaterThan(10),
        reason: 'almost nothing was scanned — the check would pass vacuously',
      );
      expect(
        offenders,
        isEmpty,
        reason:
            'every animation reads its timing from the active pack\'s motion '
            'profile (CLAUDE.md §Hard rules). A hardcoded duration makes a '
            'bouncy pack and a precise one feel the same, which is the whole '
            'thing the system exists to produce. Found:\n'
            '${offenders.join('\n')}',
      );
    });

    test('every exemption names a file that still exists', () {
      // An exemption for a deleted file is a hole nobody is watching.
      for (final path in exempt.keys) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason: '$path is exempt but does not exist',
        );
      }
    });

    test('the check can actually fail', () {
      // Proving the regex matches what it claims to. A static check nobody has
      // seen fail is a check nobody knows works.
      expect(
        literalDuration.hasMatch('duration: const Duration(milliseconds: 300)'),
        isTrue,
      );
      expect(
        literalDuration.hasMatch('AnimationController(duration: beats.pin)'),
        isFalse,
      );
      expect(
        literalDuration.hasMatch('Duration(milliseconds: total)'),
        isFalse,
        reason: 'a duration derived from the pack is the correct form',
      );
    });
  });

  group('beats come from the pack, not from a constant', () {
    test('a faster pack produces faster beats, everywhere', () {
      final byTempo = [...packs]
        ..sort((a, b) => a.motion.baseMs.compareTo(b.motion.baseMs));
      final fastest = themeFor(byTempo.first).beats;
      final slowest = themeFor(byTempo.last).beats;

      expect(
        byTempo.first.motion.baseMs,
        lessThan(byTempo.last.motion.baseMs),
        reason: 'the pack set has no tempo spread at all to test against',
      );

      for (final pair in <(String, Duration, Duration)>[
        ('shutter', fastest.shutter, slowest.shutter),
        ('develop', fastest.develop, slowest.develop),
        ('pin', fastest.pin, slowest.pin),
        ('snapIn', fastest.snapIn, slowest.snapIn),
        ('handoff', fastest.handoff, slowest.handoff),
        ('tally', fastest.tally, slowest.tally),
        ('weight', fastest.weight, slowest.weight),
        ('micro', fastest.micro, slowest.micro),
        ('stagger', fastest.stagger, slowest.stagger),
      ]) {
        expect(
          pair.$2,
          lessThan(pair.$3),
          reason:
              '${pair.$1} is the same or slower on the faster pack — it is '
              'not reading the motion profile',
        );
      }
    });

    test('the beats keep their order on every pack', () {
      // The shutter is always the snap of the sequence and the develop always
      // the long part. A pack that inverted them would read as broken.
      for (final pack in packs) {
        final beats = themeFor(pack).beats;
        expect(beats.shutter, lessThan(beats.micro), reason: pack.id);
        expect(beats.micro, lessThan(beats.tally), reason: pack.id);
        expect(beats.tally, lessThan(beats.snapIn), reason: pack.id);
        expect(beats.snapIn, lessThan(beats.handoff), reason: pack.id);
        expect(beats.handoff, lessThan(beats.weight), reason: pack.id);
        expect(beats.weight, lessThan(beats.develop), reason: pack.id);
      }
    });
  });

  group('reduced motion reaches every beat', () {
    test('every duration collapses and the stagger disappears', () {
      for (final pack in packs) {
        final calm = themeFor(pack, reduceMotion: true);
        final beats = calm.beats;

        for (final beat in <(String, Duration)>[
          ('shutter', beats.shutter),
          ('develop', beats.develop),
          ('pin', beats.pin),
          ('snapIn', beats.snapIn),
          ('handoff', beats.handoff),
          ('tally', beats.tally),
          ('weight', beats.weight),
          ('micro', beats.micro),
        ]) {
          expect(
            beat.$2,
            calm.baseDuration,
            reason:
                '${pack.id} ${beat.$1} did not collapse — reduced motion has '
                'to be one short fade, not a shorter version of the same '
                'choreography',
          );
        }

        expect(
          beats.stagger,
          Duration.zero,
          reason:
              'a stagger is motion drawing the eye across the screen, which '
              'is exactly what the setting asks us not to do',
        );
        expect(beats.arrive, Curves.linear);
        expect(beats.depart, Curves.linear);
      }
    });

    test('the palette survives it', () {
      // 03-VIBE-SYSTEM.md §6: theme and motion are independent. A calm app is
      // still this pack's app.
      for (final pack in packs) {
        final calm = themeFor(pack, reduceMotion: true);
        expect(calm.palette, themeFor(pack).palette, reason: pack.id);
        expect(calm.pack.type, themeFor(pack).pack.type, reason: pack.id);
      }
    });

    test('no pack overshoots under reduced motion', () {
      for (final pack in packs) {
        final spring = themeFor(pack, reduceMotion: true).spring;
        // SpringDescription stores absolute damping; the ratio is what decides
        // whether it overshoots.
        final ratio =
            spring.damping / (2 * math.sqrt(spring.mass * spring.stiffness));
        expect(
          ratio,
          greaterThanOrEqualTo(1.0 - 1e-9),
          reason: '${pack.id} still overshoots with motion reduced',
        );
      }
    });
  });

  group('the reveal state machine', () {
    // A Ticker records its start time on its first callback, so the first
    // pump after starting an animation reports zero elapsed. Every test here
    // takes that frame before advancing, or it measures a clock that has not
    // started.
    Future<void> settle(WidgetTester tester, int ms) async {
      await tester.pump();
      await tester.pump(Duration(milliseconds: ms));
    }

    Future<void> holdUntilRead(
      WidgetTester tester,
      RevealMachine machine,
    ) async {
      machine.hold();
      await tester.pump();
      for (var i = 0; i < 60 && !machine.hasBeenRead; i++) {
        await tester.pump(const Duration(milliseconds: 32));
      }
    }

    testWidgets('holding clears, releasing snaps shut instantly', (
      tester,
    ) async {
      final machine = await _machineFor(tester, packs.first);

      expect(machine.state, RevealState.idle);
      expect(machine.progress, 0);

      machine.hold();
      expect(machine.state, RevealState.holding);
      await settle(tester, 400);
      expect(machine.progress, greaterThan(0));

      machine.release();
      expect(
        machine.progress,
        0,
        reason:
            'a card that eases shut is one the next player reads on the way '
            'down — closing is instant on every pack (§5)',
      );
      expect(machine.state, RevealState.idle);
      machine.dispose();
    });

    testWidgets('closing is instant even on the slowest pack', (tester) async {
      final slowest = [...packs]
        ..sort((a, b) => b.motion.baseMs.compareTo(a.motion.baseMs));
      final machine = await _machineFor(tester, slowest.first);

      machine.hold();
      await settle(tester, 600);
      expect(machine.progress, greaterThan(0));

      machine.release();
      expect(
        machine.progress,
        0,
        reason: 'a slow pack must not mean a slower leak',
      );
      machine.dispose();
    });

    testWidgets('a re-press picks up rather than restarting', (tester) async {
      final machine = await _machineFor(tester, packs.first);

      machine.hold();
      await settle(tester, 200);
      expect(machine.progress, greaterThan(0));

      // Release then immediately press again. The point is that hold() is
      // callable at any moment — an animation that had to finish first would
      // make the card feel stuck.
      machine
        ..release()
        ..hold();
      expect(machine.state, RevealState.holding);
      await settle(tester, 200);
      expect(machine.progress, greaterThan(0));
      machine.dispose();
    });

    testWidgets('it becomes readable and stays marked read', (tester) async {
      final machine = await _machineFor(tester, packs.first);
      await holdUntilRead(tester, machine);

      expect(
        machine.hasBeenRead,
        isTrue,
        reason: 'a held card that never becomes legible cannot be passed on',
      );
      expect(machine.progress, greaterThanOrEqualTo(RevealMachine.legibleAt));

      machine.release();
      expect(
        machine.hasBeenRead,
        isTrue,
        reason: 'releasing hides the word; it does not un-read it',
      );
      machine.dispose();
    });

    testWidgets('every pack can be read within a reasonable press', (
      tester,
    ) async {
      // Two seconds of held press. A pack whose reveal cannot finish in that
      // is broken however good it looks, and this is the check that a tempo
      // change cannot quietly make the card unreadable.
      for (final pack in packs) {
        final machine = await _machineFor(tester, pack);
        await holdUntilRead(tester, machine);
        expect(machine.hasBeenRead, isTrue, reason: pack.id);
        machine.dispose();
      }
    });

    testWidgets('reduced motion still reveals, on a plain fade', (
      tester,
    ) async {
      final machine = await _machineFor(
        tester,
        packs.first,
        reduceMotion: true,
      );
      await holdUntilRead(tester, machine);

      expect(
        machine.hasBeenRead,
        isTrue,
        reason:
            'reduced motion calms the reveal; it must not remove it, or the '
            'card can never be read at all',
      );
      machine.dispose();
    });
  });
}

/// Builds a machine inside a real ticker, themed by [pack].
Future<RevealMachine> _machineFor(
  WidgetTester tester,
  VibePack pack, {
  bool reduceMotion = false,
}) async {
  late RevealMachine machine;
  await tester.pumpWidget(
    MaterialApp(
      theme: VibeTheme.materialThemeFor(pack, reduceMotion: reduceMotion),
      home: Builder(
        builder: (context) => _TickerHost(
          // Keyed per pack so a loop over packs rebuilds the host rather than
          // reusing the element and skipping initState.
          key: ValueKey('${pack.id}-$reduceMotion'),
          onBuilt: (vsync) {
            machine = RevealMachine(
              vsync: vsync,
              beats: context.vibe.beats,
              spring: context.vibe.spring,
              reduceMotion: context.vibe.reduceMotion,
            );
          },
        ),
      ),
    ),
  );
  return machine;
}

class _TickerHost extends StatefulWidget {
  const _TickerHost({required this.onBuilt, super.key});

  final void Function(TickerProvider vsync) onBuilt;

  @override
  State<_TickerHost> createState() => _TickerHostState();
}

class _TickerHostState extends State<_TickerHost>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    widget.onBuilt(this);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
