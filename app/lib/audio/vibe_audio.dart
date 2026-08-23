import 'dart:math' as math;

import 'package:diakooi/theme/vibe_pack.dart';

/// Audio behaviour for a session (03-VIBE-SYSTEM.md §4).
///
/// Deliberately a **pure state machine over levels**, separate from the
/// games-toolkit `AudioController` that owns the players. Ducking is the kind
/// of thing that becomes a tangle of half-restored volumes once several
/// overlapping reasons to duck exist — a stinger during a reveal during a
/// consequence prompt — so the level is derived from the set of active reasons
/// rather than mutated on each event.
///
/// It is also testable without an audio device, which is why the §4 table is
/// enforced by tests rather than by listening.

/// Why the music is currently attenuated (§4).
enum DuckReason {
  /// A reveal card is held open — reinforces the private moment.
  revealHeld,

  /// An interference stinger is playing over the track.
  interferenceStinger,

  /// The consequence prompt. "The room should get quieter."
  consequencePrompt,
}

/// The §4 attenuation table.
///
/// Reveal is the ~6dB the spec names. The consequence prompt ducks *more*
/// because §4 asks for noticeably quieter, and a stinger sits between them.
extension DuckReasonLevel on DuckReason {
  double get attenuationDb => switch (this) {
    DuckReason.revealHeld => 6,
    DuckReason.interferenceStinger => 9,
    DuckReason.consequencePrompt => 12,
  };
}

/// Converts decibels of attenuation to a linear volume multiplier.
///
/// `audioplayers` takes a 0..1 linear volume, but §4 specifies the duck in dB,
/// which is the unit that matches how it sounds. -6dB is half amplitude.
double linearFromDb(double attenuationDb) {
  if (attenuationDb <= 0) return 1;
  return math.pow(10, -attenuationDb / 20).toDouble();
}

/// The audio state for one session.
///
/// Immutable: every transition returns a new value, so a test can assert the
/// §4 table directly and the UI can rebuild from it.
class VibeAudioState {
  const VibeAudioState({
    this.pack,
    this.isMuted = false,
    this.activeDucks = const {},
    this.isPlaying = false,
  });

  final VibePack? pack;

  /// User mute. **The watermark stays visible when muted** (§4) — attribution
  /// is a licence obligation, not an audio feature — so nothing here touches
  /// watermark visibility, and [watermarkVisible] says so explicitly.
  final bool isMuted;

  final Set<DuckReason> activeDucks;
  final bool isPlaying;

  /// The deepest active duck wins, rather than the sum.
  ///
  /// Summing would let three overlapping reasons attenuate to near silence and
  /// then restore unpredictably as they cleared in a different order.
  double get attenuationDb {
    if (activeDucks.isEmpty) return 0;
    return activeDucks
        .map((d) => d.attenuationDb)
        .reduce((a, b) => a > b ? a : b);
  }

  /// The volume to hand the player, 0..1.
  double get volume => isMuted ? 0 : linearFromDb(attenuationDb);

  /// Always true. Present as a property so the rule is expressed in code and
  /// a test can hold it, rather than living only in a comment.
  bool get watermarkVisible => true;

  /// Whether a track can actually play — placeholder packs have none.
  bool get canPlay => pack?.hasTrack ?? false;

  VibeAudioState copyWith({
    VibePack? pack,
    bool? isMuted,
    Set<DuckReason>? activeDucks,
    bool? isPlaying,
  }) => VibeAudioState(
    pack: pack ?? this.pack,
    isMuted: isMuted ?? this.isMuted,
    activeDucks: activeDucks ?? this.activeDucks,
    isPlaying: isPlaying ?? this.isPlaying,
  );

  // ── §4 transitions ────────────────────────────────────────────────────

  /// `VIBE_ROLL`: the session's pack is drawn and the track starts looping.
  VibeAudioState startSession(VibePack next) => copyWith(
    pack: next,
    isPlaying: next.hasTrack,
    activeDucks: const {},
  );

  VibeAudioState duck(DuckReason reason) =>
      copyWith(activeDucks: {...activeDucks, reason});

  VibeAudioState unduck(DuckReason reason) =>
      copyWith(activeDucks: {...activeDucks}..remove(reason));

  /// Game summary: "track swells back to full" (§4).
  VibeAudioState swellToFull() => copyWith(activeDucks: const {});

  VibeAudioState setMuted({required bool muted}) => copyWith(isMuted: muted);

  VibeAudioState toggleMute() => copyWith(isMuted: !isMuted);

  @override
  String toString() =>
      'VibeAudioState(pack: ${pack?.id}, muted: $isMuted, '
      'ducks: ${activeDucks.map((d) => d.name).toList()..sort()}, '
      'volume: ${volume.toStringAsFixed(3)})';
}
