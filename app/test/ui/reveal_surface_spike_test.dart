import 'dart:ui' as ui;

import 'package:diakooi/ui/primitives/reveal_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The hold-to-reveal blur spike (06-TESTING-STRATEGY.md §8b).
///
/// **Read this before trusting any conclusion drawn from these tests.**
///
/// A widget test has no GPU and no raster cache. It therefore **cannot**
/// establish which reveal technique is cheaper — that is a rasterisation
/// question, and the mechanism that makes the cross-fade cheap (a
/// `RepaintBoundary` layer being cached and re-composited instead of
/// re-filtered) does not exist here to be observed.
///
/// The first version of this file tried to prove cost by counting child paints
/// and produced the *opposite* of the expected result — the cross-fade paints
/// its child twice per frame by construction, so it counted higher. That
/// number is real, and it is recorded below, but it measures paint calls, not
/// filter evaluations, and it is not evidence about frame time.
///
/// What these tests do establish is the set of **structural preconditions**
/// that hold on any GPU:
///
///   * whether the backdrop is read back at all (`BackdropFilter`), and
///   * whether the filter's parameters are constant across a hold, which is
///     what makes the filtered layer cacheable in the first place.
///
/// Everything genuinely requiring the handset is enumerated in
/// `docs/adr/0008-hold-to-reveal-technique.md`. No millisecond figure is
/// produced anywhere in this file, deliberately.
void main() {
  Widget harness({
    required RevealTechnique technique,
    required double progress,
    bool reduceMotion = false,
    VoidCallback? onPaint,
  }) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 300,
          height: 200,
          child: RevealSurface(
            progress: progress,
            technique: technique,
            maxBlurSigma: 12,
            child: CustomPaint(
              painter: _CountingPainter(onPaint ?? () {}),
              child: const SizedBox(width: 300, height: 200),
            ),
          ),
        ),
      ),
    ),
  );

  /// Every blur sigma the technique asks for across a hold.
  ///
  /// This is the load-bearing measurement: a filter whose parameters change
  /// every frame must be re-evaluated every frame on any GPU. One whose
  /// parameters are constant can be rasterised once and composited thereafter.
  Future<List<double>> sigmasDuringHold(
    WidgetTester tester,
    RevealTechnique technique, {
    int frames = 20,
  }) async {
    final sigmas = <double>[];
    for (var i = 0; i <= frames; i++) {
      await tester.pumpWidget(
        harness(technique: technique, progress: i / frames),
      );
      await tester.pump(const Duration(milliseconds: 8));

      for (final element in find.byType(ImageFiltered).evaluate()) {
        final filtered = element.widget as ImageFiltered;
        sigmas.add(_sigmaOf(filtered.imageFilter));
      }
      for (final element in find.byType(BackdropFilter).evaluate()) {
        final backdrop = element.widget as BackdropFilter;
        final filter = backdrop.filter;
        if (filter != null) sigmas.add(_sigmaOf(filter));
      }
    }
    return sigmas;
  }

  group('structural facts — device-independent', () {
    testWidgets('the live technique reads back the backdrop', (tester) async {
      await tester.pumpWidget(
        harness(technique: RevealTechnique.liveBackdropFilter, progress: 0.5),
      );
      expect(
        find.byType(BackdropFilter),
        findsOneWidget,
        reason: 'a backdrop read-back is the expensive part of this technique',
      );
    });

    testWidgets('the cross-fade never reads back the backdrop', (tester) async {
      await tester.pumpWidget(
        harness(
          technique: RevealTechnique.prerenderedCrossFade,
          progress: 0.5,
        ),
      );
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ImageFiltered), findsOneWidget);
    });

    testWidgets('the cross-fade isolates the filtered copy behind a boundary', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          technique: RevealTechnique.prerenderedCrossFade,
          progress: 0.5,
        ),
      );
      // Without this the filtered layer re-rasterises with its parent and the
      // technique collapses into the expensive one. Necessary, not sufficient:
      // whether the cache is actually hit needs a GPU.
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('a fully revealed surface applies no filter', (tester) async {
      for (final technique in RevealTechnique.values) {
        await tester.pumpWidget(harness(technique: technique, progress: 1));
        expect(
          find.byType(BackdropFilter),
          findsNothing,
          reason: '$technique still filters at sigma 0 — pure cost, no effect',
        );
      }
    });
  });

  group('filter parameters across a hold — the real measurement', () {
    testWidgets('the live technique changes sigma every frame', (tester) async {
      final sigmas = await sigmasDuringHold(
        tester,
        RevealTechnique.liveBackdropFilter,
      );
      expect(sigmas, isNotEmpty);
      expect(
        sigmas.toSet().length,
        greaterThan(1),
        reason:
            'sigma varies with progress, so the filter must be re-evaluated '
            'on every frame of the hold — on any GPU',
      );
    });

    testWidgets('the cross-fade holds sigma constant', (tester) async {
      final sigmas = await sigmasDuringHold(
        tester,
        RevealTechnique.prerenderedCrossFade,
      );
      expect(sigmas, isNotEmpty);
      expect(
        sigmas.toSet().length,
        1,
        reason:
            'a constant sigma is what makes the filtered layer cacheable; '
            'only opacity animates. This is the whole basis of the technique, '
            'and it is checkable without a GPU',
      );
    });

    testWidgets('the downscaled blur also changes sigma every frame', (
      tester,
    ) async {
      final sigmas = await sigmasDuringHold(
        tester,
        RevealTechnique.downscaledBlur,
      );
      expect(
        sigmas.toSet().length,
        greaterThan(1),
        reason:
            'this technique cuts fill rate per evaluation, not the number of '
            'evaluations — a different saving, and one that stacks with '
            'neither the cross-fade nor a cap',
      );
    });
  });

  group('what this harness cannot determine', () {
    testWidgets('paint counts do not rank the techniques by cost', (
      tester,
    ) async {
      Future<int> paints(RevealTechnique technique) async {
        var count = 0;
        for (var i = 0; i <= 20; i++) {
          await tester.pumpWidget(
            harness(
              technique: technique,
              progress: i / 20,
              onPaint: () => count++,
            ),
          );
          await tester.pump(const Duration(milliseconds: 8));
        }
        return count;
      }

      final live = await paints(RevealTechnique.liveBackdropFilter);
      final crossFade = await paints(RevealTechnique.prerenderedCrossFade);

      // Recorded as an observation, NOT as a cost ranking. The cross-fade
      // paints its child twice per frame (clear copy + blurred copy), so it
      // counts higher — while doing strictly less filtering. Anyone reading
      // this number as "the cross-fade is more expensive" has read it wrong,
      // which is exactly why it is asserted with that meaning attached.
      expect(
        crossFade,
        greaterThan(live),
        reason:
            'the cross-fade paints the child twice by construction. This is a '
            'paint-call count, not a cost measurement — the filtering work it '
            'avoids is invisible without a GPU. See ADR 0008',
      );
    });
  });

  group('the cross-fade wiring', () {
    testWidgets('opacity pairs reach the tree across the hold', (tester) async {
      // This is what stands in for a golden of the reveal's progress states.
      // Alchemist CI mode flattens opacity compositing, so goldening those
      // states produced byte-identical baselines — see the note in
      // test/golden/primitive_matrix_golden_test.dart. Asserting the pair here
      // proves the cross-fade is wired correctly without a baseline that can
      // never fail.
      // A list of records, not a const map: double keys are not permitted in
      // a const map literal.
      const cases = [
        (progress: 0.0, opacities: [0.0, 1.0]),
        (progress: 0.5, opacities: [0.5, 0.5]),
        (progress: 1.0, opacities: [1.0, 0.0]),
      ];
      for (final entry in cases) {
        await tester.pumpWidget(
          harness(
            technique: RevealTechnique.prerenderedCrossFade,
            progress: entry.progress,
          ),
        );
        final opacities = tester
            .widgetList<Opacity>(find.byType(Opacity))
            .map((o) => o.opacity)
            .toList();
        expect(
          opacities,
          entry.opacities,
          reason:
              'at progress ${entry.progress} the clear and blurred layers '
              'must be at ${entry.opacities}',
        );
      }
    });
  });

  group('reduced motion (03-VIBE-SYSTEM.md §6)', () {
    testWidgets('collapses a live filter to the cheap technique', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          technique: RevealTechnique.liveBackdropFilter,
          progress: 0.5,
          reduceMotion: true,
        ),
      );
      expect(
        find.byType(BackdropFilter),
        findsNothing,
        reason:
            'reduced motion must not animate a per-frame filter; the palette '
            'still applies, motion does not',
      );
    });
  });

  group('robustness', () {
    testWidgets('clamps out-of-range progress rather than throwing', (
      tester,
    ) async {
      for (final technique in RevealTechnique.values) {
        for (final progress in [-0.5, 0.0, 0.5, 1.0, 1.5]) {
          await tester.pumpWidget(
            harness(technique: technique, progress: progress),
          );
          expect(tester.takeException(), isNull);
        }
      }
    });
  });
}

/// Extracts the sigma from an [ui.ImageFilter] via its `toString`.
///
/// Flutter exposes no accessor for it. Brittle in principle, but the format is
/// stable and the alternative is not measuring the one thing that is genuinely
/// measurable here.
double _sigmaOf(ui.ImageFilter filter) {
  final match = RegExp(
    r'blur\(([\d.]+),\s*([\d.]+)',
  ).firstMatch(filter.toString());
  if (match == null) return -1;
  return double.parse(match.group(1)!);
}

class _CountingPainter extends CustomPainter {
  const _CountingPainter(this.onPaint);

  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF334455),
    );
  }

  @override
  bool shouldRepaint(_CountingPainter oldDelegate) => true;
}
