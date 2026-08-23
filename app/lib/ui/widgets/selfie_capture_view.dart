import 'dart:async';

import 'package:camera/camera.dart';
import 'package:diakooi/selfie/camera_selfie_source.dart';
import 'package:diakooi/selfie/selfie_capture.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/widgets/vibe_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The camera, as the UI needs it.
///
/// An interface so onboarding can be widget-tested without a camera plugin,
/// and so the one place that touches `package:camera` stays one place.
abstract interface class SelfieCamera {
  /// False when there is no camera or permission was refused. Either way the
  /// player gets a monogram — §4 makes Skip a first-class path.
  Future<bool> initialize();

  Widget buildPreview(BuildContext context);

  Future<SelfieOutcome> capture();

  Future<void> dispose();
}

/// The production camera, over the preview stream.
class StreamingSelfieCamera implements SelfieCamera {
  StreamingSelfieCamera() : _source = CameraSelfieSource() {
    _controller = SelfieCaptureController(source: _source);
  }

  final CameraSelfieSource _source;
  late final SelfieCaptureController _controller;

  @override
  Future<bool> initialize() => _source.initialize();

  @override
  Widget buildPreview(BuildContext context) {
    final controller = _source.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(controller);
  }

  @override
  Future<SelfieOutcome> capture() => _controller.capture();

  @override
  Future<void> dispose() => _controller.dispose();
}

/// How the app builds a camera.
///
/// Overridden in widget tests, which have no plugin and must not try to open
/// one. Never a hardcoded constructor call at a use site.
final selfieCameraProvider = Provider<SelfieCamera Function()>(
  (ref) => StreamingSelfieCamera.new,
);

/// The capture step of onboarding (§4).
///
/// Three outcomes and all of them continue: a captured frame, a deliberate
/// skip, or a camera that would not open. Nothing here can strand a table with
/// the phone in someone's hand.
class SelfieCaptureView extends ConsumerStatefulWidget {
  const SelfieCaptureView({
    required this.playerName,
    required this.onDone,
    super.key,
  });

  final String playerName;
  final ValueChanged<SelfieOutcome> onDone;

  @override
  ConsumerState<SelfieCaptureView> createState() => _SelfieCaptureViewState();
}

class _SelfieCaptureViewState extends ConsumerState<SelfieCaptureView> {
  late final SelfieCamera _camera = ref.read(selfieCameraProvider)();
  Future<bool>? _ready;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _ready = _camera.initialize();
  }

  @override
  void dispose() {
    // Fire and forget: the widget is going away either way, and awaiting a
    // plugin teardown inside dispose would block the pass.
    unawaited(_camera.dispose());
    super.dispose();
  }

  Future<void> _capture() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    final outcome = await _camera.capture();
    if (!mounted) return;
    setState(() => _capturing = false);
    widget.onDone(outcome);
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;

    return FutureBuilder<bool>(
      future: _ready,
      builder: (context, snapshot) {
        final available = snapshot.data ?? false;
        final settled = snapshot.connectionState == ConnectionState.done;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: vibe.cardRadius,
                ),
                child: ClipRRect(
                  borderRadius: vibe.cardRadius,
                  child: available
                      ? _camera.buildPreview(context)
                      : Center(
                          child: Padding(
                            padding: EdgeInsets.all(vibe.gutter * 2),
                            child: Text(
                              settled
                                  ? 'No camera. ${widget.playerName} gets a '
                                        'monogram instead — that works just as '
                                        'well.'
                                  : 'Opening the camera…',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: palette.textMuted,
                                fontSize: 15,
                                fontFamily: vibe.pack.type.body,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            SizedBox(height: vibe.gutter),
            Text(
              // The claim is exactly this and no more. Vendor Extended RAM can
              // page process memory below our layer, so "never touches disk"
              // would be an overclaim (ADR 0005).
              'The app never saves this photo. It lives in memory for this '
              'game only.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 13,
                fontFamily: vibe.pack.type.body,
              ),
            ),
            SizedBox(height: vibe.gutter),
            if (available)
              VibeButton(
                label: _capturing ? 'Hold still…' : 'Take it',
                icon: Icons.camera_alt_outlined,
                onPressed: _capturing ? null : _capture,
              ),
            SizedBox(height: vibe.gutter * 0.5),
            VibeButton(
              label: 'Skip',
              emphasis: VibeEmphasis.quiet,
              onPressed: () => widget.onDone(
                const SelfieSkipped(reason: 'player skipped'),
              ),
            ),
          ],
        );
      },
    );
  }
}
