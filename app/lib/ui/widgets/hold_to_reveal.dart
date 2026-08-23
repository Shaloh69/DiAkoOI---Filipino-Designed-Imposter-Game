import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/primitives/primitives.dart';
import 'package:flutter/material.dart';

/// The word card, revealed only while a finger is held on it (§5).
///
/// **Hold is the primary mechanic and tilt is a flourish.** A card that stays
/// legible after you let go is a card the next player can read over your
/// shoulder, and at a table that is not a hypothetical — it is the normal way
/// this game leaks. Releasing snaps the blur back rather than easing it out,
/// because an ease is a window.
///
/// The tilt shear is deliberately small and does nothing to legibility. It
/// exists so the card feels like an object; §5 is explicit that it must not
/// become a second way to read the word.
class HoldToReveal extends StatefulWidget {
  const HoldToReveal({
    required this.content,
    required this.isImposter,
    this.showRoleTreatment = true,
    this.onFirstReveal,
    super.key,
  });

  /// The word, or the imposter's clue. Which of those it is was decided by the
  /// engine — this widget is never told the role for that purpose.
  final String content;

  /// Used only for the subtle §6b treatment, which must not read across a room.
  final bool isImposter;
  final bool showRoleTreatment;

  /// Fires the first time the card is held, so the flow can enable Continue.
  final VoidCallback? onFirstReveal;

  @override
  State<HoldToReveal> createState() => _HoldToRevealState();
}

class _HoldToRevealState extends State<HoldToReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: context.vibe.baseDuration,
    reverseDuration: Duration.zero,
  )..addListener(_onTick);

  bool _hasRevealed = false;

  void _onTick() => setState(() {});

  @override
  void dispose() {
    _controller
      ..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  void _hold() {
    _controller.forward();
    if (!_hasRevealed) {
      _hasRevealed = true;
      widget.onFirstReveal?.call();
    }
  }

  /// Snaps closed. Not an animation — a released card must be unreadable
  /// immediately, and any easing here is a window for the next player.
  void _release() => _controller.value = 0;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;

    return Semantics(
      label: 'Hold to see your word',
      value: _controller.value > 0.5 ? widget.content : 'hidden',
      child: GestureDetector(
        onTapDown: (_) => _hold(),
        onTapUp: (_) => _release(),
        onTapCancel: _release,
        onLongPressStart: (_) => _hold(),
        onLongPressEnd: (_) => _release(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RevealCard(
              content: widget.content,
              revealProgress: _controller.value,
              isImposter: widget.isImposter,
              showRoleTreatment: widget.showRoleTreatment,
            ),
            SizedBox(height: vibe.gutter),
            Text(
              _controller.value > 0
                  ? 'Let go and it closes'
                  : 'Press and hold to read',
              style: TextStyle(
                color: vibe.palette.textMuted,
                fontSize: 14,
                fontFamily: vibe.pack.type.body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
