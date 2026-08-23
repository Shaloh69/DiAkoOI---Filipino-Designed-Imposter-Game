import 'dart:math' as math;

import 'package:diakooi/theme/vibe_loader.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/primitives/primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden/support.dart';

/// The A3 checks that are not goldens.
///
/// Contrast, colour-blind safety, layout limits and the "themes are data"
/// guarantee are all per-pack properties. They run on every platform — unlike
/// the goldens, which are Linux-only (ADR 0004) — so a Windows developer still
/// gets the accessibility bars enforced.
Future<void> main() async {
  final packs = await loadAllPacks();

  group('the pack set itself (03-VIBE-SYSTEM.md §3)', () {
    test('six launch packs are present', () {
      expect(packs.map((p) => p.id).toSet(), {
        'tugtog',
        'alon',
        'palengke',
        'lamig',
        'tahimik',
        'sayaw',
      });
    });

    test('every pack carries a licence record — no record, no ship (§1)', () {
      for (final pack in packs) {
        expect(
          pack.licence,
          isNotNull,
          reason: '${pack.id} has no licence.json',
        );
        expect(pack.licence!.source, isNotEmpty);
        expect(pack.licence!.type, isNotEmpty);
        expect(pack.licence!.url, isNotEmpty);
      }
    });

    test('placeholder packs are flagged and carry no track', () {
      for (final pack in packs) {
        if (pack.licence!.isPlaceholder) {
          expect(
            pack.hasTrack,
            isFalse,
            reason:
                '${pack.id} is a placeholder but declares a track file — a '
                'stub pretending to be a licensed asset is exactly what §1 '
                'is about',
          );
          expect(pack.licence!.isShippable, isFalse);
        } else {
          expect(
            pack.hasTrack,
            isTrue,
            reason: '${pack.id} claims a real licence but has no track',
          );
        }
      }
    });

    test('every motion profile is real spring parameters (§3)', () {
      for (final pack in packs) {
        expect(pack.motion.stiffness, greaterThan(0));
        expect(pack.motion.damping, greaterThan(0));
        expect(pack.motion.baseMs, greaterThan(0));
      }
    });

    test('bouncy and precise are visibly different, not just named', () {
      final bouncy = packs.firstWhere((p) => p.id == 'tugtog');
      final precise = packs.firstWhere((p) => p.id == 'lamig');

      expect(
        bouncy.motion.overshoots,
        isTrue,
        reason: 'a bouncy pack must overshoot — damping below 1',
      );
      expect(
        precise.motion.overshoots,
        isFalse,
        reason: 'a precise pack must not overshoot',
      );
      // If the two springs were close, "the profiles are decoration" would be
      // the fair criticism §3 makes.
      expect(
        (bouncy.motion.damping - precise.motion.damping).abs(),
        greaterThan(0.25),
      );
    });
  });

  group('contrast, per pack (§6)', () {
    // Every palette must pass 4.5:1 for body text and 3:1 for large text.
    // §6 names Sayaw's neon-on-purple and Palengke's high-chroma set as the
    // two that fail if unchecked, so this runs against all six rather than a
    // sample.
    for (final pack in packs) {
      test('${pack.id}: body text on every surface clears 4.5:1', () {
        final palette = pack.palette;
        for (final ground in {
          'bg': palette.bg,
          'surface': palette.surface,
          'surfaceAlt': palette.surfaceAlt,
        }.entries) {
          final ratio = contrastRatio(palette.textPrimary, ground.value);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '${pack.id}: textPrimary on ${ground.key} is '
                '${ratio.toStringAsFixed(2)}:1',
          );
        }
      });

      test('${pack.id}: muted text clears 3:1 for large text', () {
        final palette = pack.palette;
        final ratio = contrastRatio(palette.textMuted, palette.bg);
        expect(
          ratio,
          greaterThanOrEqualTo(3.0),
          reason:
              '${pack.id}: textMuted on bg is ${ratio.toStringAsFixed(2)}:1 — '
              'the watermark uses this (§5)',
        );
      });

      test('${pack.id}: role accents clear 3:1 against the surface', () {
        final palette = pack.palette;
        for (final accent in {
          'crew': palette.crew,
          'imposter': palette.imposter,
          'interference': palette.interference,
          'danger': palette.danger,
        }.entries) {
          final ratio = contrastRatio(accent.value, palette.surface);
          expect(
            ratio,
            greaterThanOrEqualTo(3.0),
            reason:
                '${pack.id}: ${accent.key} on surface is '
                '${ratio.toStringAsFixed(2)}:1 — a border nobody can see is '
                'not a role signal',
          );
        }
      });
    }
  });

  group('crew vs imposter without colour (§6)', () {
    // The accent pair changes per pack and some pairs are poor for colour-blind
    // players, so colour can never be the only signal.
    for (final pack in packs) {
      test('${pack.id}: shape tokens differ between roles', () {
        final theme = VibeTheme(pack: pack, reduceMotion: false);
        final crew = theme.shapeForRole(isImposter: false);
        final imposter = theme.shapeForRole(isImposter: true);
        expect(
          crew,
          isNot(imposter),
          reason:
              '${pack.id} distinguishes roles by colour alone — unusable for '
              'a colour-blind player',
        );
      });

      test('${pack.id}: the rendered borders are different shapes', () {
        final theme = VibeTheme(pack: pack, reduceMotion: false);
        final crew = theme.roleShape(
          isImposter: false,
          color: pack.palette.crew,
        );
        final imposter = theme.roleShape(
          isImposter: true,
          color: pack.palette.crew,
        );
        expect(
          crew.runtimeType == imposter.runtimeType &&
              crew.toString() == imposter.toString(),
          isFalse,
          reason: '${pack.id}: role borders render identically',
        );
      });
    }
  });

  group('themes are data (§2)', () {
    testWidgets('a seventh pack loads with zero Dart changes', (tester) async {
      // The load-bearing proof. Nothing below names a pack in Dart: the source
      // is handed a directory that did not exist when this code was written.
      const source = InMemoryVibePackSource({
        'bagong_pack': {
          'theme.json': '', // replaced below
          'licence.json': '',
        },
      });
      expect(source.files.keys, contains('bagong_pack'));

      final live = InMemoryVibePackSource({
        'bagong_pack': {
          'theme.json': syntheticThemeJson(
            'bagong_pack',
            displayName: 'Bagong Pack',
          ),
          'licence.json': syntheticLicenceJson(),
        },
      });

      final loader = VibePackLoader(source: live);
      final library = await loader.loadAll();

      expect(library.failures, isEmpty);
      expect(library.packs, hasLength(1));

      final pack = library.packs.single;
      expect(pack.id, 'bagong_pack');
      expect(pack.displayName, 'Bagong Pack');

      // And it renders through the same primitives, unmodified.
      await tester.pumpWidget(
        themedForGolden(
          pack,
          const PlayerTile(
            name: 'Ana',
            avatar: MonogramBadge(name: 'Ana', size: 40),
            livesRemaining: 2,
            livesTotal: 3,
            revealRole: true,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Ana'), findsOneWidget);
    });

    test(
      'a pack whose directory and declared id disagree is rejected',
      () async {
        final loader = VibePackLoader(
          source: InMemoryVibePackSource({
            'folder_name': {
              'theme.json': syntheticThemeJson('different_id'),
              'licence.json': syntheticLicenceJson(),
            },
          }),
        );
        final library = await loader.loadAll();
        expect(library.packs, isEmpty);
        expect(library.failures, hasLength(1));
        expect(library.failures.single.reason, contains('directory name'));
      },
    );

    test(
      'a pack with no licence.json fails to load — no record, no ship',
      () async {
        final loader = VibePackLoader(
          source: InMemoryVibePackSource({
            'no_licence': {'theme.json': syntheticThemeJson('no_licence')},
          }),
        );
        final library = await loader.loadAll();
        expect(library.packs, isEmpty);
        expect(library.failures.single.reason, contains('no readable licence'));
      },
    );

    test('one broken pack does not take down the others', () async {
      final loader = VibePackLoader(
        source: InMemoryVibePackSource({
          'good': {
            'theme.json': syntheticThemeJson('good'),
            'licence.json': syntheticLicenceJson(),
          },
          'broken': {
            'theme.json': '{ not json',
            'licence.json': syntheticLicenceJson(),
          },
        }),
      );
      final library = await loader.loadAll();
      expect(library.packs.map((p) => p.id), ['good']);
      expect(library.failures.map((f) => f.packId), ['broken']);
    });
  });

  group('reduced motion (§6)', () {
    testWidgets('collapses motion but keeps the palette', (tester) async {
      final pack = packs.first;

      final normal = VibeTheme(pack: pack, reduceMotion: false);
      final reduced = VibeTheme(pack: pack, reduceMotion: true);

      expect(
        reduced.palette,
        normal.palette,
        reason: 'theme and motion are independent — the palette still applies',
      );
      // The requirement is that reduced motion never overshoots — not that it
      // is always more damped. Asserted across every pack, including the two
      // that are already over-damped.
      for (final candidate in packs) {
        final calm = VibeTheme(pack: candidate, reduceMotion: true);
        final damped = SpringDescription.withDampingRatio(
          mass: 1,
          stiffness: candidate.motion.stiffness,
        );
        expect(
          calm.spring.damping,
          greaterThanOrEqualTo(damped.damping - 1e-9),
          reason:
              '${candidate.id}: reduced motion must be at least critically '
              'damped, so it cannot overshoot',
        );
      }
      expect(reduced.curve, Curves.linear);
      expect(
        reduced.baseDuration.inMilliseconds,
        lessThanOrEqualTo(normal.baseDuration.inMilliseconds),
      );

      // And a primitive renders without its motion flourish.
      await tester.pumpWidget(
        themedForGolden(
          pack,
          const PolaroidFrame(
            tilt: 0.3,
            child: ColoredBox(color: Color(0xFF888888)),
          ),
          reduceMotion: true,
        ),
      );
      final transform = tester.widget<Transform>(find.byType(Transform).first);
      // The Polaroid tilt is a motion flourish; reduced motion zeroes it.
      expect(transform.transform.getRotation().isIdentity(), isTrue);
    });
  });

  group('layout limits (A3)', () {
    for (final pack in packs) {
      testWidgets('${pack.id}: holds at 320dp and 200% text scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Theme(
                data: VibeTheme.materialThemeFor(pack),
                child: ColoredBox(
                  color: pack.palette.bg,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstraintBanner(text: 'ONE WORD ONLY'),
                      SizedBox(
                        width: 140,
                        child: PlayerTile(
                          name: 'Maria Clara',
                          avatar: MonogramBadge(
                            name: 'Maria Clara',
                            size: 40,
                          ),
                          livesRemaining: 2,
                          livesTotal: 3,
                        ),
                      ),
                      VibeWatermark(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        expect(
          tester.takeException(),
          isNull,
          reason:
              '${pack.id} overflows at 320dp / 200% text — the smallest '
              'phone a player will actually use',
        );
      });
    }
  });
}

/// WCAG 2.1 contrast ratio between two opaque colours.
///
/// Implemented rather than pulled in: it is twelve lines, and a dependency for
/// something this small is a supply-chain cost for no benefit.
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color color) {
  double channel(double value) => value <= 0.03928
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}
