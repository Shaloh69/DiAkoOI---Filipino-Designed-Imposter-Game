import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:diakooi/theme/vibe_pack.dart';
import 'package:diakooi/ui/primitives/primitives.dart';
import 'package:diakooi/ui/widgets/interference_card.dart';
import 'package:diakooi/ui/widgets/vibe_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_platform.dart';
import 'support.dart';

/// **The golden matrix: every primitive × every Vibe Pack.**
///
/// This is the load-bearing proof that the theming system is real rather than
/// decoration (03-VIBE-SYSTEM.md §7, 06-TESTING-STRATEGY.md §3). A hardcoded
/// colour, radius or spacing in any primitive shows up here the moment it
/// appears, because the same widget is rendered against six palettes.
///
/// The pack list is **loaded from `assets/vibes/`**, not written in Dart, so a
/// seventh pack extends the matrix with zero code changes.
///
/// Goldens run on Linux only — a local green on Windows means they were
/// skipped, not verified (ADR 0004).
Future<void> main() async {
  final packs = await loadAllPacks();

  /// One scenario per pack, for a primitive.
  GoldenTestGroup matrixFor(
    String name,
    Widget Function(VibePack pack) build,
  ) => GoldenTestGroup(
    columns: packs.length,
    children: [
      for (final pack in packs)
        GoldenTestScenario(
          name: pack.id,
          child: themedForGolden(pack, build(pack)),
        ),
    ],
  );

  // Not a golden, so it must run everywhere — including Windows, where the
  // goldens themselves skip. Without it the whole matrix could pass vacuously
  // on a checkout with no packs.
  test('the matrix covers every pack found on disk', () {
    expect(
      packs,
      isNotEmpty,
      reason: 'no packs loaded — the matrix would pass vacuously',
    );
    expect(
      packs.length,
      greaterThanOrEqualTo(6),
      reason: '03-VIBE-SYSTEM.md §3 specifies six launch packs',
    );
  });

  group('primitive × pack matrix', () {
    unawaited(
      goldenTest(
        'PolaroidFrame',
        fileName: 'matrix_polaroid_frame',
        builder: () => matrixFor(
          'PolaroidFrame',
          (pack) => PolaroidFrame(
            caption: 'Ana',
            tilt: -0.04,
            child: ColoredBox(color: pack.palette.surfaceAlt),
          ),
        ),
      ),
    );

    unawaited(
      goldenTest(
        'MonogramBadge',
        fileName: 'matrix_monogram_badge',
        builder: () => matrixFor(
          'MonogramBadge',
          (pack) => const MonogramBadge(name: 'Juan Dela Cruz', size: 72),
        ),
      ),
    );

    unawaited(
      goldenTest(
        'LifePips',
        fileName: 'matrix_life_pips',
        builder: () => matrixFor(
          'LifePips',
          (pack) => const LifePips(remaining: 2, total: 3),
        ),
      ),
    );

    unawaited(
      goldenTest(
        'ItemBadge',
        fileName: 'matrix_item_badge',
        builder: () => matrixFor('ItemBadge', (pack) => const ItemBadge()),
      ),
    );

    unawaited(
      goldenTest(
        'PlayerTile',
        fileName: 'matrix_player_tile',
        builder: () => matrixFor(
          'PlayerTile',
          (pack) => const SizedBox(
            width: 140,
            child: PlayerTile(
              name: 'Ana',
              avatar: MonogramBadge(name: 'Ana', size: 56),
              livesRemaining: 2,
              livesTotal: 3,
              isMarked: true,
              heldItemLabel: '?',
              voteCount: 3,
            ),
          ),
        ),
      ),
    );

    // Role treatment is the §6 accessibility requirement: crew and imposter
    // must differ by SHAPE, not only by an accent colour that changes per pack.
    unawaited(
      goldenTest(
        'PlayerTile — crew vs imposter, role revealed',
        fileName: 'matrix_player_tile_roles',
        builder: () => GoldenTestGroup(
          columns: packs.length,
          children: [
            for (final pack in packs)
              GoldenTestScenario(
                name: pack.id,
                child: themedForGolden(
                  pack,
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 120,
                        child: PlayerTile(
                          name: 'Crew',
                          avatar: MonogramBadge(name: 'C', size: 44),
                          livesRemaining: 3,
                          livesTotal: 3,
                          revealRole: true,
                        ),
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        width: 120,
                        child: PlayerTile(
                          name: 'Imposter',
                          avatar: MonogramBadge(name: 'I', size: 44),
                          livesRemaining: 1,
                          livesTotal: 3,
                          isImposter: true,
                          revealRole: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    unawaited(
      goldenTest(
        'ConstraintBanner',
        fileName: 'matrix_constraint_banner',
        builder: () => matrixFor(
          'ConstraintBanner',
          (pack) => const SizedBox(
            width: 200,
            child: ConstraintBanner(text: 'ONE WORD ONLY'),
          ),
        ),
      ),
    );

    unawaited(
      goldenTest(
        'PassInterstitial',
        fileName: 'matrix_pass_interstitial',
        builder: () => matrixFor(
          'PassInterstitial',
          (pack) => const SizedBox(
            width: 260,
            height: 320,
            child: PassInterstitial(
              nextPlayerName: 'Ana',
              avatar: MonogramBadge(name: 'Ana', size: 72),
              paceHint: '~8 min left this round',
            ),
          ),
        ),
      ),
    );

    unawaited(
      goldenTest(
        'VibeWatermark',
        fileName: 'matrix_vibe_watermark',
        builder: () => matrixFor(
          'VibeWatermark',
          (pack) => const VibeWatermark(),
        ),
      ),
    );

    // The card's chrome — border shape, radius, surface — is what varies per
    // pack, so one state is enough here.
    unawaited(
      goldenTest(
        'RevealCard',
        fileName: 'matrix_reveal_card',
        builder: () => matrixFor(
          'RevealCard',
          (pack) => const SizedBox(
            width: 200,
            height: 140,
            child: RevealCard(content: 'Jollibee', revealProgress: 0),
          ),
        ),
      ),
    );

    // The one button style in the game, in all three emphases plus disabled.
    // Every colour, radius and padding on it resolves from the pack, so a
    // hardcoded value here would be visible across six baselines at once —
    // which is the entire reason the matrix exists.
    unawaited(
      goldenTest(
        'VibeButton',
        fileName: 'matrix_vibe_button',
        builder: () => matrixFor(
          'VibeButton',
          (pack) => SizedBox(
            width: 200,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                VibeButton(label: 'Deal', onPressed: () {}),
                const SizedBox(height: 8),
                VibeButton(
                  label: 'End the game',
                  emphasis: VibeEmphasis.quiet,
                  onPressed: () {},
                ),
                const SizedBox(height: 8),
                const VibeButton(label: 'Waiting on 3', onPressed: null),
              ],
            ),
          ),
        ),
      ),
    );

    // The §9e interference language, side by side with the reveal card it
    // must never be confused with. Goldened across every pack because that is
    // what proves the distinction survives a palette where the accent sits
    // close to the surface — the case where colour alone would fail (§6).
    unawaited(
      goldenTest(
        'InterferenceCard',
        fileName: 'matrix_interference_card',
        builder: () => matrixFor(
          'InterferenceCard',
          (pack) => const SizedBox(
            width: 240,
            child: InterferenceCard(
              title: 'This round',
              body: 'Mercy Round',
              footnote: 'No life is lost this round, from any source.',
            ),
          ),
        ),
      ),
    );

    // The reveal's PROGRESS states are deliberately not goldened.
    //
    // Alchemist CI mode cannot capture them. Two things were measured before
    // concluding that: an ImageFiltered blur on its own DOES produce a
    // different baseline from unblurred content, but RevealSurface at progress
    // 0.0 / 0.5 / 1.0 produces three byte-identical ones — CI mode flattens the
    // opacity compositing the cross-fade depends on.
    //
    // The widget itself is correct; `reveal_surface_spike_test.dart` asserts
    // the opacity pair reaches the tree as [0,1], [0.5,0.5], [1,0]. Goldening
    // it here would have added three baselines that can never fail, which reads
    // as coverage and is worse than none.
  }, skip: skipUnlessGoldenPlatform);
}
