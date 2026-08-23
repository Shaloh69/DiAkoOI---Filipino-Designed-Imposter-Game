/// The design-system primitives (03-VIBE-SYSTEM.md, 05-IMPLEMENTATION-PLAN
/// Phase 3).
///
/// **Not one colour, duration, radius or spacing is hardcoded here.** Every
/// value resolves from `context.vibe`, and the golden matrix — every primitive
/// × every pack — is what proves that rather than asserting it.
library;

import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/primitives/reveal_surface.dart';
import 'package:flutter/material.dart';

/// A selfie or monogram in a Polaroid-style frame (01-DESIGN.md §4a).
///
/// The selfie is in-memory bytes only; this widget never takes a path, which
/// is the shape of the §4b guarantee expressed in the type system.
class PolaroidFrame extends StatelessWidget {
  const PolaroidFrame({
    required this.child,
    this.caption,
    this.tilt = 0,
    this.size = 96,
    super.key,
  });

  final Widget child;
  final String? caption;

  /// Radians. The running motif is a slightly askew Polaroid.
  final double tilt;
  final double size;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;

    return Transform.rotate(
      angle: vibe.reduceMotion ? 0 : tilt,
      child: Container(
        padding: EdgeInsets.all(vibe.gutter * 0.75),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: vibe.cardRadius,
          border: Border.all(color: palette.surfaceAlt, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  vibe.texture.cardRadius * 0.5,
                ),
                child: child,
              ),
            ),
            if (caption != null) ...[
              SizedBox(height: vibe.gutter * 0.5),
              SizedBox(
                width: size,
                child: Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 13,
                    fontFamily: vibe.pack.type.display,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Initials on a coloured ground, for players who skip the selfie (§4).
class MonogramBadge extends StatelessWidget {
  const MonogramBadge({required this.name, this.size = 96, super.key});

  final String name;
  final double size;

  /// First letters of the first two words, so "Juan Dela Cruz" reads "JD".
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'))
      ..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    // Derived from the pack's own accents so a monogram is never off-palette,
    // and stable per name so a player keeps the same colour all game.
    final tint = Color.lerp(
      vibe.palette.crew,
      vibe.palette.interference,
      (name.hashCode % 100) / 100,
    )!;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(vibe.texture.cardRadius * 0.5),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          // Chosen against the tint, not the page, so it stays legible on any
          // pack's accent range.
          color: tint.computeLuminance() > 0.5
              ? vibe.palette.bg
              : vibe.palette.textPrimary,
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
          fontFamily: vibe.pack.type.display,
        ),
      ),
    );
  }
}

/// One life, filled or spent (§8).
class LifePip extends StatelessWidget {
  const LifePip({required this.filled, this.size = 12, super.key});

  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? vibe.palette.danger : Colors.transparent,
          border: Border.all(
            color: filled ? vibe.palette.danger : vibe.palette.textMuted,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

/// A row of [LifePip]s.
class LifePips extends StatelessWidget {
  const LifePips({
    required this.remaining,
    required this.total,
    this.size = 12,
    super.key,
  });

  final int remaining;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return Semantics(
      label: '$remaining of $total lives remaining',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) SizedBox(width: vibe.gutter * 0.35),
            LifePip(filled: i < remaining, size: size),
          ],
        ],
      ),
    );
  }
}

/// The badge shown when a player holds an item (§9d).
///
/// The table sees that someone holds *something*, never what.
class ItemBadge extends StatelessWidget {
  const ItemBadge({this.label = '?', this.size = 22, super.key});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: vibe.palette.interference,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: vibe.palette.bg,
          fontSize: size * 0.55,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// A player's tile in the voting grid (§7).
class PlayerTile extends StatelessWidget {
  const PlayerTile({
    required this.name,
    required this.avatar,
    required this.livesRemaining,
    required this.livesTotal,
    this.isImposter = false,
    this.revealRole = false,
    this.isMarked = false,
    this.heldItemLabel,
    this.voteCount = 0,
    super.key,
  });

  final String name;
  final Widget avatar;
  final int livesRemaining;
  final int livesTotal;

  /// Role is only ever *rendered* when [revealRole] is true — during play the
  /// grid must not leak it.
  final bool isImposter;
  final bool revealRole;

  /// §9b Marked: the table knows interference touched them, not what.
  final bool isMarked;
  final String? heldItemLabel;
  final int voteCount;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;

    final accent = revealRole
        ? vibe.accentFor(isImposter: isImposter)
        : palette.surfaceAlt;

    return Semantics(
      label: revealRole ? '$name, ${isImposter ? 'imposter' : 'crew'}' : name,
      child: Container(
        padding: EdgeInsets.all(vibe.gutter),
        decoration: ShapeDecoration(
          color: palette.surface,
          // Shape carries the role distinction without colour (§6).
          shape: revealRole
              ? vibe.roleShape(isImposter: isImposter, color: accent)
              : RoundedRectangleBorder(
                  side: BorderSide(color: accent, width: 2),
                  borderRadius: vibe.cardRadius,
                ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                avatar,
                if (isMarked)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: palette.interference,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.bg, width: 2),
                      ),
                    ),
                  ),
                if (heldItemLabel != null)
                  Positioned(
                    left: -4,
                    bottom: -4,
                    child: ItemBadge(label: heldItemLabel!),
                  ),
              ],
            ),
            SizedBox(height: vibe.gutter * 0.5),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 14,
                fontFamily: vibe.pack.type.body,
              ),
            ),
            SizedBox(height: vibe.gutter * 0.35),
            LifePips(remaining: livesRemaining, total: livesTotal),
            if (voteCount > 0) ...[
              SizedBox(height: vibe.gutter * 0.35),
              Text(
                '$voteCount',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 12,
                  fontFamily: vibe.pack.type.body,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The "pass to X" screen between players (§3, §4).
class PassInterstitial extends StatelessWidget {
  const PassInterstitial({
    required this.nextPlayerName,
    required this.avatar,
    this.constraintBanner,
    this.paceHint,
    super.key,
  });

  final String nextPlayerName;
  final Widget avatar;

  /// A §9f constraint banner, when the round carries one.
  final Widget? constraintBanner;

  /// Large Group Mode's soft pace hint (§2a).
  final String? paceHint;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;

    return ColoredBox(
      color: palette.bg,
      child: Padding(
        padding: EdgeInsets.all(vibe.gutter * 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (constraintBanner != null) ...[
              constraintBanner!,
              SizedBox(height: vibe.gutter * 2),
            ],
            avatar,
            SizedBox(height: vibe.gutter * 1.5),
            Text(
              'Pass to',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 16,
                fontFamily: vibe.pack.type.body,
              ),
            ),
            SizedBox(height: vibe.gutter * 0.5),
            Text(
              nextPlayerName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                fontFamily: vibe.pack.type.display,
              ),
            ),
            if (paceHint != null) ...[
              SizedBox(height: vibe.gutter),
              Text(
                paceHint!,
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 13,
                  fontFamily: vibe.pack.type.body,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A persistent banner for a socially-enforced constraint (§9f).
///
/// Roughly a third of the interference pool cannot be detected by the app, so
/// the banner is how the table is armed to police it. Secret constraints
/// (Taboo, Liar's Tax, The Fool) deliberately never appear here.
class ConstraintBanner extends StatelessWidget {
  const ConstraintBanner({
    required this.text,
    this.isRoundLevel = true,
    super.key,
  });

  final String text;
  final bool isRoundLevel;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: vibe.gutter,
          vertical: vibe.gutter * 0.75,
        ),
        decoration: BoxDecoration(
          color: palette.interference,
          borderRadius: BorderRadius.circular(vibe.texture.cardRadius * 0.5),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.bg,
            fontSize: isRoundLevel ? 15 : 14,
            fontWeight: FontWeight.w600,
            fontFamily: vibe.pack.type.body,
          ),
        ),
      ),
    );
  }
}

/// The hold-to-reveal word card (§5, §6b).
class RevealCard extends StatelessWidget {
  const RevealCard({
    required this.content,
    required this.revealProgress,
    this.isImposter = false,
    this.showRoleTreatment = false,
    this.technique = RevealTechnique.prerenderedCrossFade,
    super.key,
  });

  /// The word, or the imposter's vague clue. Which is decided by the engine.
  final String content;

  /// 0 obscured, 1 clear.
  final double revealProgress;

  final bool isImposter;

  /// Crew/imposter treatment is deliberately subtle — it must not read across
  /// a room (§6b).
  final bool showRoleTreatment;

  final RevealTechnique technique;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;
    final accent = vibe.accentFor(isImposter: isImposter);

    return Container(
      padding: EdgeInsets.all(vibe.gutter * 2),
      decoration: ShapeDecoration(
        color: palette.surface,
        shape: showRoleTreatment
            ? vibe.roleShape(isImposter: isImposter, color: accent)
            : RoundedRectangleBorder(
                side: BorderSide(color: palette.surfaceAlt, width: 2),
                borderRadius: vibe.cardRadius,
              ),
      ),
      child: RevealSurface(
        progress: revealProgress,
        technique: technique,
        maxBlurSigma: vibe.pack.revealBlurSigma,
        child: Center(
          child: Text(
            content,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: vibe.pack.type.display,
            ),
          ),
        ),
      ),
    );
  }
}

/// The persistent attribution watermark (§5).
///
/// **Stays visible when audio is muted.** Attribution is a licence obligation,
/// not an audio feature — and it is present in every pack even where the
/// licence does not demand it, because inconsistent attribution UI looks like
/// an accident.
class VibeWatermark extends StatelessWidget {
  const VibeWatermark({this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;

    return Semantics(
      button: onTap != null,
      label: 'Music attribution: ${vibe.pack.watermark.label}',
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: vibe.gutter,
            vertical: vibe.gutter * 0.5,
          ),
          child: Text(
            vibe.pack.watermark.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              // textMuted, not a lower opacity: §5 requires 4.5:1 against the
              // pack's own background, and opacity would break that per pack.
              color: palette.textMuted,
              fontSize: 12,
              fontFamily: vibe.pack.type.body,
            ),
          ),
        ),
      ),
    );
  }
}
