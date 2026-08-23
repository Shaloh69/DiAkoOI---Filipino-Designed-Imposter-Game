import 'package:diakooi/theme/vibe_theme.dart';
import 'package:flutter/material.dart';

/// The named beats every animation in the game is timed against.
///
/// **No animation may name a duration of its own** (CLAUDE.md §Hard rules).
/// Every value here is a multiple of the active pack's `motion.baseMs`, so
/// Sayaw at 160ms and Tahimik at 400ms produce genuinely different-feeling
/// apps from the same widget code — which is what 03-VIBE-SYSTEM.md §3 means
/// by "motion profiles are real parameters, not vibes-in-prose".
///
/// Multipliers, not milliseconds. A beat is a *ratio* to the pack's tempo: the
/// shutter is always a fraction of a beat and the develop always several,
/// whatever tempo the pack sets.
@immutable
class VibeBeats {
  const VibeBeats(this._theme);

  final VibeTheme _theme;

  int get _base => _theme.motion.baseMs;

  Duration _beat(double multiplier) => _theme.reduceMotion
      // Reduced motion collapses every beat to one short fade. Feedback still
      // happens — removing it entirely leaves a UI that looks broken rather
      // than calm (03-VIBE-SYSTEM.md §6).
      ? _theme.baseDuration
      : Duration(milliseconds: (_base * multiplier).round());

  /// The camera flash. Deliberately the shortest thing in the game.
  Duration get shutter => _beat(0.15);

  /// A Polaroid coming up. The one long beat in onboarding, and the reason
  /// the capture reads as an event rather than a form field.
  Duration get develop => _beat(2.5);

  /// Settling into the roster corner.
  Duration get pin => _beat(1);

  /// The word arriving on a held card.
  Duration get snapIn => _beat(0.75);

  /// Confirm-tap through to the next interstitial, as one beat (§3).
  Duration get handoff => _beat(1.25);

  /// A vote tile reacting, a tally ticking up.
  Duration get tally => _beat(0.5);

  /// The resolution reveal. The heaviest beat in the game, because it is the
  /// moment the round turns on.
  Duration get weight => _beat(2);

  /// Any small acknowledgement — a press, a toggle, a chip.
  Duration get micro => _beat(0.35);

  /// Stagger between items in a list or grid that animates in.
  ///
  /// Zero under reduced motion: a stagger is motion drawing the eye across the
  /// screen, which is precisely what the setting asks us not to do.
  Duration get stagger => _theme.reduceMotion ? Duration.zero : _beat(0.12);

  /// The curve for a beat that arrives. Overshoots only where the pack does.
  Curve get arrive => _theme.curve;

  /// The curve for a beat that leaves. Never overshoots — an element on its
  /// way out that bounces reads as an error.
  Curve get depart => _theme.reduceMotion ? Curves.linear : Curves.easeInCubic;
}

extension VibeBeatsAccess on VibeTheme {
  /// Named beats for this pack. See [VibeBeats].
  VibeBeats get beats => VibeBeats(this);
}

extension VibeBeatsContext on BuildContext {
  VibeBeats get beats => vibe.beats;
}
