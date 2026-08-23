import 'package:diakooi/theme/motion.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:flutter/material.dart';

/// Shutter flash → develop → pin, as one sequence (05-IMPLEMENTATION-PLAN
/// Phase 5).
///
/// **The monogram runs the identical sequence.** That is the requirement and
/// it is not decoration: §4 makes Skip a first-class path, and a photo that
/// develops while a monogram simply appears tells everyone at the table which
/// one the app considers real. The subject is a `child`, so this widget cannot
/// tell the difference and cannot treat them differently.
class DevelopSequence extends StatefulWidget {
  const DevelopSequence({
    required this.child,
    this.onFinished,
    this.autoStart = true,
    super.key,
  });

  /// The Polaroid or the monogram. This widget never knows which.
  final Widget child;

  final VoidCallback? onFinished;

  /// False leaves it at rest until [DevelopSequenceState.play] is called.
  final bool autoStart;

  @override
  State<DevelopSequence> createState() => DevelopSequenceState();
}

class DevelopSequenceState extends State<DevelopSequence>
    with TickerProviderStateMixin {
  AnimationController? _controller;

  /// Where the three beats sit in the combined timeline.
  late double _flashEnd;
  late double _developEnd;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final beats = context.beats;
    final total =
        beats.shutter.inMilliseconds +
        beats.develop.inMilliseconds +
        beats.pin.inMilliseconds;

    _flashEnd = beats.shutter.inMilliseconds / total;
    _developEnd =
        (beats.shutter.inMilliseconds + beats.develop.inMilliseconds) / total;

    _controller?.dispose();
    _controller =
        AnimationController(
            vsync: this,
            duration: Duration(milliseconds: total),
          )
          ..addListener(() {
            if (mounted) setState(() {});
          })
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) widget.onFinished?.call();
          });

    if (widget.autoStart) _controller!.forward();
  }

  /// Restarts the sequence. Used when a player retakes.
  void play() => _controller!.forward(from: 0);

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  double _phase(double start, double end) =>
      ((_controller!.value - start) / (end - start)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final t = _controller!.value;

    final flash = _phase(0, _flashEnd);
    final develop = _phase(_flashEnd, _developEnd);
    final pin = Curves.easeOutCubic.transform(_phase(_developEnd, 1));

    if (vibe.reduceMotion) {
      // One fade, no flash, no rotation, no travel. The palette still applies
      // (03-VIBE-SYSTEM.md §6) — this is the same subject, calmly.
      return Opacity(opacity: t.clamp(0.0, 1.0), child: widget.child);
    }

    // The image comes up out of the pack's own surface colour rather than out
    // of white or black, so a develop looks like this pack developing.
    final emerging = ColorFiltered(
      colorFilter: ColorFilter.mode(
        vibe.palette.surface.withValues(alpha: 1 - develop),
        BlendMode.srcOver,
      ),
      child: widget.child,
    );

    final settle = vibe.motion.overshoots
        ? Curves.easeOutBack.transform(pin)
        : pin;

    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          // Settles askew, which is the running Polaroid motif. The angle
          // comes from the pack's tempo: a bouncy pack lands further off true.
          angle: (1 - settle) * (vibe.motion.overshoots ? 0.22 : 0.10),
          child: Transform.scale(
            scale: 0.94 + settle * 0.06,
            child: Opacity(
              opacity: (develop * 1.4).clamp(0.0, 1.0),
              child: emerging,
            ),
          ),
        ),
        // The shutter, over the top and gone. Shortest beat in the game.
        if (flash > 0 && flash < 1)
          IgnorePointer(
            child: Opacity(
              opacity: 1 - flash,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: vibe.palette.textPrimary,
                  borderRadius: vibe.cardRadius,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
      ],
    );
  }
}
