import 'package:diakooi/theme/vibe_pack.dart';
import 'package:flutter/material.dart';

/// The active pack's design tokens, reachable from any widget.
///
/// **No widget may hardcode a colour, duration, radius or spacing**
/// (CLAUDE.md §Hard rules). Everything resolves through here, and the golden
/// matrix — every primitive × every pack — is what catches a violation the
/// moment one appears.
@immutable
class VibeTheme extends ThemeExtension<VibeTheme> {
  const VibeTheme({required this.pack, required this.reduceMotion});

  final VibePack pack;

  /// When true every motion profile collapses to a fade (03-VIBE-SYSTEM.md §6).
  /// The palette still applies — theme and motion are independent.
  final bool reduceMotion;

  VibePalette get palette => pack.palette;
  VibeTexture get texture => pack.texture;
  VibeMotion get motion => pack.motion;

  /// The spring a card animates on.
  ///
  /// Real parameters, not a name: `bouncy` (damping < 1) visibly overshoots
  /// where `precise` (damping 1) does not, which is the §3 requirement that
  /// the profiles be more than prose.
  SpringDescription get spring => SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: motion.stiffness,
    // Reduced motion CLAMPS the ratio to at least 1 rather than setting it to
    // 1. The requirement is "never overshoot", and a pack that is already
    // over-damped — Alon at 1.35 — would otherwise be made *less* damped and
    // therefore snappier by a setting that exists to calm things down.
    ratio: reduceMotion
        ? (motion.damping < 1.0 ? 1.0 : motion.damping)
        : motion.damping,
  );

  /// Base animation duration. Reduced motion shortens it to a plain fade
  /// rather than removing feedback entirely.
  Duration get baseDuration =>
      reduceMotion ? const Duration(milliseconds: 120) : motion.baseDuration;

  /// The curve for non-spring animations.
  Curve get curve => reduceMotion
      ? Curves.linear
      : (motion.overshoots ? Curves.easeOutBack : Curves.easeOutCubic);

  BorderRadius get cardRadius => BorderRadius.circular(texture.cardRadius);

  double get gutter => texture.gutter;

  /// Accent for a role. Colour alone never carries this — see
  /// [shapeForRole], which is the non-colour signal §6 requires.
  Color accentFor({required bool isImposter}) =>
      isImposter ? palette.imposter : palette.crew;

  /// Shape token for a role.
  ///
  /// The accent pair changes per pack and some pairs are poor for colour-blind
  /// players, so the crew/imposter distinction is carried by shape as well as
  /// colour in every pack (§6).
  String shapeForRole({required bool isImposter}) =>
      isImposter ? texture.imposterShape : texture.crewShape;

  /// Border shape for a role tile, derived from the pack's shape tokens.
  ShapeBorder roleShape({required bool isImposter, required Color color}) {
    final token = shapeForRole(isImposter: isImposter);
    final side = BorderSide(color: color, width: 2);
    return switch (token) {
      'square' => RoundedRectangleBorder(side: side),
      'chamfered' => BeveledRectangleBorder(
        side: side,
        borderRadius: BorderRadius.circular(texture.cardRadius),
      ),
      'notched' => RoundedRectangleBorder(
        side: side,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(texture.cardRadius),
          bottomRight: Radius.circular(texture.cardRadius),
        ),
      ),
      _ => RoundedRectangleBorder(
        side: side,
        borderRadius: BorderRadius.circular(texture.cardRadius),
      ),
    };
  }

  @override
  VibeTheme copyWith({VibePack? pack, bool? reduceMotion}) => VibeTheme(
    pack: pack ?? this.pack,
    reduceMotion: reduceMotion ?? this.reduceMotion,
  );

  @override
  VibeTheme lerp(ThemeExtension<VibeTheme>? other, double t) {
    // Packs are drawn per session and do not cross-fade, so a lerp between two
    // packs would only ever produce a colour nobody designed. Snapping is the
    // honest behaviour.
    if (other is! VibeTheme) return this;
    return t < 0.5 ? this : other;
  }

  /// Builds the Material theme for a pack, so framework widgets inherit the
  /// palette instead of defaulting to Material blue.
  static ThemeData materialThemeFor(
    VibePack pack, {
    bool reduceMotion = false,
  }) {
    final palette = pack.palette;
    final isDark = palette.bg.computeLuminance() < 0.5;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: palette.crew,
          brightness: isDark ? Brightness.dark : Brightness.light,
        ).copyWith(
          surface: palette.surface,
          onSurface: palette.textPrimary,
          error: palette.danger,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.bg,
      fontFamily: pack.type.body,
      extensions: [VibeTheme(pack: pack, reduceMotion: reduceMotion)],
    );
  }
}

/// Reads the active [VibeTheme].
extension VibeThemeContext on BuildContext {
  /// Throws if no pack is in scope — a widget rendering without a theme would
  /// otherwise silently fall back to Material defaults, which is exactly the
  /// hardcoded-value failure the system exists to prevent.
  VibeTheme get vibe {
    final theme = Theme.of(this).extension<VibeTheme>();
    if (theme == null) {
      throw FlutterError(
        'No VibeTheme in scope. Wrap the subtree in a theme built by '
        'VibeTheme.materialThemeFor(pack) — widgets must never fall back to '
        'Material defaults (CLAUDE.md §Hard rules).',
      );
    }
    return theme;
  }
}
