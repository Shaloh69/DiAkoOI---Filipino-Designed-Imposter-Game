import 'package:flutter/painting.dart' show Color;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'vibe_pack.freezed.dart';
part 'vibe_pack.g.dart';

/// A Vibe Pack: one licensed instrumental track plus one complete visual theme
/// (03-VIBE-SYSTEM.md).
///
/// **Themes are data, not code.** Adding a pack must never require a Dart
/// change — that is what lets the golden matrix extend itself and what lets v2
/// sync a theme across devices (01-DESIGN.md §17). A test adds a seventh pack
/// at runtime to prove it.

/// Hex colour that survives JSON.
///
/// Written as `#RRGGBB` or `#AARRGGBB` in `theme.json` so a designer can edit a
/// pack in a text editor without knowing Dart.
class HexColorConverter implements JsonConverter<Color, String> {
  const HexColorConverter();

  @override
  Color fromJson(String json) {
    var hex = json.trim().replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) {
      throw FormatException('colour must be #RRGGBB or #AARRGGBB, got "$json"');
    }
    final value = int.tryParse(hex, radix: 16);
    if (value == null) {
      throw FormatException('colour "$json" is not valid hex');
    }
    return Color(value);
  }

  @override
  String toJson(Color object) {
    final hex = object
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0')
        .toUpperCase();
    return '#$hex';
  }
}

/// Named motion characters (03-VIBE-SYSTEM.md §3).
///
/// These are labels for spring parameter sets, not the parameters themselves —
/// a pack supplies its own stiffness and damping, and the profile only says
/// what kind of thing it is.
enum MotionProfileKind { bouncy, precise, snappy, slow, energetic, gentle }

/// Where the attribution watermark sits (§5).
enum WatermarkPosition { bottomCenter, bottomLeft, bottomRight }

/// A pack's palette. Every colour a widget can use comes from here.
@freezed
abstract class VibePalette with _$VibePalette {
  const factory VibePalette({
    @HexColorConverter() required Color bg,
    @HexColorConverter() required Color surface,
    @HexColorConverter() required Color surfaceAlt,
    @HexColorConverter() required Color textPrimary,
    @HexColorConverter() required Color textMuted,

    /// Crew accent. Must be distinguishable from [imposter] **without colour**
    /// (§6) — the shape and texture tokens below carry that.
    @HexColorConverter() required Color crew,
    @HexColorConverter() required Color imposter,
    @HexColorConverter() required Color interference,
    @HexColorConverter() required Color danger,
  }) = _VibePalette;

  factory VibePalette.fromJson(Map<String, dynamic> json) =>
      _$VibePaletteFromJson(json);
}

/// Type tokens.
@freezed
abstract class VibeType with _$VibeType {
  const factory VibeType({
    required String display,
    required String body,
    @Default(1.25) double scaleRatio,
  }) = _VibeType;

  factory VibeType.fromJson(Map<String, dynamic> json) =>
      _$VibeTypeFromJson(json);
}

/// Motion as **real spring parameters** (§3).
///
/// "bouncy" and "precise" must produce visibly different behaviour when you
/// hold a card, or the system is decoration. [damping] is the ratio: below 1
/// overshoots, 1 is critical, above 1 is slow and heavy.
@freezed
abstract class VibeMotion with _$VibeMotion {
  const factory VibeMotion({
    required MotionProfileKind profile,
    required double stiffness,
    required double damping,
    @Default(240) int baseMs,
  }) = _VibeMotion;

  const VibeMotion._();

  factory VibeMotion.fromJson(Map<String, dynamic> json) =>
      _$VibeMotionFromJson(json);

  /// True when the spring overshoots its target — the visible difference
  /// between a bouncy pack and a precise one.
  bool get overshoots => damping < 1.0;

  Duration get baseDuration => Duration(milliseconds: baseMs);
}

/// Card texture tokens.
@freezed
abstract class VibeTexture with _$VibeTexture {
  const factory VibeTexture({
    @Default('flat') String card,
    @Default(0.0) double grainOpacity,

    /// Shape token carrying the crew/imposter distinction **without colour**
    /// (§6). Some accent pairs are poor for colour-blind players, and the pair
    /// changes per pack, so colour alone can never be the signal.
    @Default('rounded') String crewShape,
    @Default('notched') String imposterShape,
    @Default(16.0) double cardRadius,
    @Default(8.0) double gutter,
  }) = _VibeTexture;

  factory VibeTexture.fromJson(Map<String, dynamic> json) =>
      _$VibeTextureFromJson(json);
}

/// Attribution shown for the pack's track (§5).
@freezed
abstract class VibeWatermarkSpec with _$VibeWatermarkSpec {
  const factory VibeWatermarkSpec({
    required String track,
    required String artist,
    @Default(WatermarkPosition.bottomCenter) WatermarkPosition position,
  }) = _VibeWatermarkSpec;

  const VibeWatermarkSpec._();

  factory VibeWatermarkSpec.fromJson(Map<String, dynamic> json) =>
      _$VibeWatermarkSpecFromJson(json);

  /// The §5 format: `♪ Tugtog — Artist Name`.
  String get label => '♪ $track — $artist';
}

/// The licence record every pack must ship (§1).
///
/// **No record, no ship.** Attribution is not a licence; this is the evidence
/// that permission exists, and A3 audits that every shipped track has one.
@freezed
abstract class VibeLicence with _$VibeLicence {
  const factory VibeLicence({
    required String source,
    required String type,
    required String url,
    required String attribution,
    String? acquired,

    /// True while this is a silent stub rather than a real licensed track.
    /// A pack with this set must never reach a release build.
    @Default(false) bool isPlaceholder,
  }) = _VibeLicence;

  const VibeLicence._();

  factory VibeLicence.fromJson(Map<String, dynamic> json) =>
      _$VibeLicenceFromJson(json);

  /// Whether this record is complete enough to ship (§1).
  bool get isShippable =>
      !isPlaceholder &&
      source.trim().isNotEmpty &&
      type.trim().isNotEmpty &&
      url.trim().isNotEmpty;
}

/// One complete pack.
@freezed
abstract class VibePack with _$VibePack {
  const factory VibePack({
    required String id,
    required String displayName,
    required VibePalette palette,
    required VibeType type,
    required VibeMotion motion,
    required VibeWatermarkSpec watermark,
    @Default(VibeTexture()) VibeTexture texture,

    /// Populated from the pack's `licence.json`, which is a separate file so a
    /// licence can be updated without touching the theme.
    VibeLicence? licence,

    /// Relative to the pack directory, or **null when no track exists yet**.
    ///
    /// Placeholder packs genuinely have no audio file. Modelling that as null
    /// rather than shipping a fake silent binary keeps the missing track
    /// visible: a licence-audited folder should not contain something
    /// pretending to be a licensed asset, and a stub would also hide a real
    /// pack whose filename was mistyped. A test asserts that every
    /// non-placeholder pack has a track file and every placeholder has none.
    String? trackFile,
  }) = _VibePack;

  const VibePack._();

  factory VibePack.fromJson(Map<String, dynamic> json) =>
      _$VibePackFromJson(json);

  /// Asset path of this pack's track, or null when the pack has no audio.
  String? get trackAssetPath =>
      trackFile == null ? null : 'assets/vibes/$id/$trackFile';

  /// Whether this pack can actually play anything.
  bool get hasTrack => trackFile != null;

  /// Maximum blur sigma for the reveal card, derived from the pack's own
  /// motion character rather than hardcoded at the call site.
  double get revealBlurSigma => 8 + (motion.stiffness / 40);
}
