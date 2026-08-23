import 'package:diakooi/theme/motion.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:flutter/material.dart';

/// Confirm-tap → handoff → next interstitial, as **one continuous beat**
/// (05-IMPLEMENTATION-PLAN Phase 5, §3 of the prompt library).
///
/// Never a cut. The phone is physically moving between two people during this,
/// and a hard swap makes the app feel like it lost its place — the one moment
/// in the game where the software has to feel like it is keeping up with the
/// room rather than lagging it.
///
/// Framework primitives only, deliberately. `AnimatedBuilder` and `Hero` are
/// interruptible by construction: a player who taps through fast cancels the
/// beat rather than queueing behind it, which a packaged transition will not
/// reliably give you.
class HandoffBeat extends StatefulWidget {
  const HandoffBeat({required this.beatKey, required this.child, super.key});

  /// Changes when the phone moves to the next person. That change *is* the
  /// beat — nothing else triggers it.
  final Object beatKey;

  final Widget child;

  @override
  State<HandoffBeat> createState() => _HandoffBeatState();
}

class _HandoffBeatState extends State<HandoffBeat>
    with TickerProviderStateMixin {
  AnimationController? _controller;
  Object? _lastKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller?.dispose();
    _controller =
        AnimationController(
          vsync: this,
          duration: context.beats.handoff,
          value: 1,
        )..addListener(() {
          if (mounted) setState(() {});
        });
    _lastKey = widget.beatKey;
  }

  @override
  void didUpdateWidget(HandoffBeat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.beatKey != _lastKey) {
      _lastKey = widget.beatKey;
      // forward(from: 0) rather than reset-then-forward: an in-flight beat is
      // restarted from the top rather than snapping to zero first, so tapping
      // through quickly reads as hurrying it along rather than as a stutter.
      _controller!.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final t = _controller!.value;

    if (vibe.reduceMotion) {
      return Opacity(opacity: t.clamp(0.0, 1.0), child: widget.child);
    }

    final eased = context.beats.arrive.transform(t.clamp(0.0, 1.0));
    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(
        // Travels along the axis the phone travels: across, not up. Small,
        // because the beat is about continuity rather than spectacle.
        offset: Offset((1 - eased) * 28, 0),
        child: widget.child,
      ),
    );
  }
}

/// Tags a player's avatar so it flies between the interstitial and the card.
///
/// One tag per player per round, so two avatars for the same person on screen
/// at once — the grid tile and the interstitial portrait — do not fight over
/// the flight.
String handoffHeroTag({required String playerId, required int roundIndex}) =>
    'handoff-$playerId-$roundIndex';

/// A [Hero] that disappears cleanly under reduced motion.
///
/// A flight is motion across the screen, which is exactly what the setting
/// asks us not to do — but the subject still has to be there, so the wrapper
/// degrades to the plain child rather than to nothing.
class HandoffHero extends StatelessWidget {
  const HandoffHero({required this.tag, required this.child, super.key});

  final String tag;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.vibe.reduceMotion) return child;
    return Hero(
      tag: tag,
      // Keeps the flying copy on the pack's own surface rather than on the
      // Material default, which would flash the wrong colour mid-flight.
      flightShuttleBuilder: (_, animation, _, _, _) => Material(
        type: MaterialType.transparency,
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: child,
    );
  }
}
