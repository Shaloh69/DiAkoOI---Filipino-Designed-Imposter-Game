import 'package:diakooi/theme/motion.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/motion/reveal_machine.dart';
import 'package:diakooi/ui/primitives/primitives.dart';
import 'package:flutter/material.dart';

/// The word card, legible only while a finger is held on it (§5, §6b).
///
/// **Hold is the primary mechanic and tilt is a flourish.** A card that stays
/// legible after you let go is a card the next player can read over your
/// shoulder, and at a table that is not a hypothetical — it is the normal way
/// this game leaks.
///
/// Every duration and curve comes from the active pack's motion profile via
/// [VibeBeats]. Sayaw's word arrives with an overshoot; Lamig's does not. That
/// difference is the product (03-VIBE-SYSTEM.md §3), so nothing here names a
/// millisecond.
class HoldToReveal extends StatefulWidget {
  const HoldToReveal({
    required this.content,
    required this.isImposter,
    this.showRoleTreatment = true,
    this.onFirstReveal,
    super.key,
  });

  /// The word, or the imposter's clue. Which it is was decided by the engine —
  /// this widget is never told the role for that purpose.
  final String content;

  /// Used only for the subtle §6b treatment, which must not read across a room.
  final bool isImposter;
  final bool showRoleTreatment;

  /// Fires the first time the card is fully revealed, so the flow can enable
  /// Continue. A glance that never completes does not count as having read it.
  final VoidCallback? onFirstReveal;

  @override
  State<HoldToReveal> createState() => _HoldToRevealState();
}

class _HoldToRevealState extends State<HoldToReveal>
    with TickerProviderStateMixin {
  RevealMachine? _machine;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Built here rather than in initState because it needs the theme, and a
    // pack change mid-session must rebuild it with the new motion profile.
    //
    // That rebuild is why this uses TickerProviderStateMixin rather than the
    // Single variant: the Single mixin asserts on a second ticker even after
    // the first is disposed, and a Vibe Pack reroll on Play Again is exactly
    // a second ticker.
    final vibe = context.vibe;
    _machine?.dispose();
    _machine = RevealMachine(
      vsync: this,
      beats: vibe.beats,
      spring: vibe.spring,
      reduceMotion: vibe.reduceMotion,
    )..addListener(_onChanged);
  }

  bool _announced = false;

  void _onChanged() {
    if (!mounted) return;
    setState(() {});
    if (!_announced && _machine!.hasBeenRead) {
      _announced = true;
      widget.onFirstReveal?.call();
    }
  }

  @override
  void dispose() {
    _machine
      ?..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final beats = vibe.beats;
    final machine = _machine!;
    final progress = machine.progress;

    return Semantics(
      label: 'Hold to see your word',
      value: machine.state == RevealState.revealed ? widget.content : 'hidden',
      child: GestureDetector(
        // Both gesture families, because a quick tap and a long press are the
        // same intent here and a player who taps must not get nothing.
        onTapDown: (_) => machine.hold(),
        onTapUp: (_) => machine.release(),
        onTapCancel: machine.release,
        onLongPressStart: (_) => machine.hold(),
        onLongPressEnd: (_) => machine.release(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CardBody(
              content: widget.content,
              progress: progress,
              isImposter: widget.isImposter,
              showRoleTreatment: widget.showRoleTreatment,
              state: machine.state,
            ),
            SizedBox(height: vibe.gutter),
            AnimatedSwitcher(
              duration: beats.micro,
              switchInCurve: beats.arrive,
              switchOutCurve: beats.depart,
              child: Text(
                progress > 0
                    ? 'Let go and it closes'
                    : 'Press and hold to read',
                key: ValueKey(progress > 0),
                style: TextStyle(
                  color: vibe.palette.textMuted,
                  fontSize: 14,
                  fontFamily: vibe.pack.type.body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card itself: the blur clearing, and the word arriving on top of it.
class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.content,
    required this.progress,
    required this.isImposter,
    required this.showRoleTreatment,
    required this.state,
  });

  final String content;
  final double progress;
  final bool isImposter;
  final bool showRoleTreatment;
  final RevealState state;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;

    // The word snaps in over the last of the clear, so it lands rather than
    // fading up alongside the blur. Under reduced motion the scale is pinned
    // to 1 and only the opacity moves.
    final snap = Curves.easeOutCubic.transform(
      ((progress - 0.35) / 0.65).clamp(0.0, 1.0),
    );
    final scale = vibe.reduceMotion
        ? 1.0
        : 1 + (1 - snap) * (vibe.motion.overshoots ? 0.14 : 0.06);

    return Transform.scale(
      // The card breathes very slightly as it opens. Never under reduced
      // motion, and never enough to change what is legible.
      scale: vibe.reduceMotion ? 1.0 : 1 + progress * 0.015,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RevealCard(
            content: content,
            revealProgress: progress,
            isImposter: isImposter,
            showRoleTreatment: showRoleTreatment,
          ),
          // A second copy of the word, unblurred, riding the snap. The card
          // beneath still carries the blur, so the two together read as the
          // word resolving out of it.
          if (snap > 0)
            IgnorePointer(
              child: Opacity(
                opacity: snap,
                child: Transform.scale(
                  scale: scale,
                  child: Padding(
                    padding: EdgeInsets.all(vibe.gutter * 2),
                    child: Text(
                      content,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: vibe.palette.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: vibe.pack.type.display,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
