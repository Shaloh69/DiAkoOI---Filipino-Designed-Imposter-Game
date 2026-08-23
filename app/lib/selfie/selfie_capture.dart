import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:diakooi/selfie/selfie_bytes.dart';
import 'package:flutter/foundation.dart';

/// Capturing a selfie without it ever reaching storage (01-DESIGN.md §4b).
///
/// **Both `image_picker` and `camera.takePicture()` write a temp file by
/// default and will silently break the guarantee.** Neither appears anywhere in
/// this app — a static check in `test/privacy/no_disk_write_test.dart` fails
/// the build if either is reintroduced, because the failure mode here is silent
/// and a runtime test can only catch what it happens to exercise.
///
/// The supported path is a preview-stream frame converted in memory.

/// Target sizes, in logical pixels before device scaling.
///
/// **Downscale at capture** is §8e mitigation 2, and the reason it matters is
/// arithmetic: twenty players holding full sensor frames is hundreds of
/// megabytes of live image data, which is enough to push a device into its
/// Extended RAM swap. Two small renditions per player is single-digit
/// megabytes, which is not.
abstract final class SelfieTargets {
  /// The Polaroid frame during onboarding and the pass interstitial.
  static const int polaroidPx = 320;

  /// The voting grid, where twenty of these are on screen at once.
  static const int gridTilePx = 192;
}

/// A raw frame handed over by a capture source.
///
/// Encoded (PNG/JPEG) rather than raw planes, so the decode can be done by
/// `dart:ui` at a target size — which means the full-resolution image is never
/// materialised as an RGBA buffer at all.
class CapturedFrame {
  const CapturedFrame(this.encodedBytes);

  final Uint8List encodedBytes;
}

/// Something that can produce one frame.
///
/// An interface so the pipeline is testable without a camera, and so the
/// plugin-specific code stays in one place.
abstract interface class SelfieSource {
  /// Grabs a single frame. Must never write to disk.
  Future<CapturedFrame?> captureFrame();

  Future<void> dispose();
}

/// Turns a captured frame into the two renditions the app holds.
///
/// Pure and testable: no plugin, no camera, no file system.
class SelfieProcessor {
  const SelfieProcessor();

  /// Decodes [frame] **directly at each target size**.
  ///
  /// `instantiateImageCodec` with a `targetWidth` decodes at that size rather
  /// than decoding full-size and then shrinking, so the sensor-resolution
  /// bitmap never exists in memory. That is the difference between this being a
  /// memory mitigation and it being a cosmetic resize.
  Future<SelfieBytes> process(CapturedFrame frame) async {
    final polaroid = await _decodeToPng(
      frame.encodedBytes,
      SelfieTargets.polaroidPx,
    );
    final gridTile = await _decodeToPng(
      frame.encodedBytes,
      SelfieTargets.gridTilePx,
    );
    return SelfieBytes(polaroid: polaroid, gridTile: gridTile);
  }

  Future<Uint8List> _decodeToPng(Uint8List source, int targetPx) async {
    final codec = await ui.instantiateImageCodec(
      source,
      targetWidth: targetPx,
      targetHeight: targetPx,
    );
    try {
      final frame = await codec.getNextFrame();
      try {
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null) {
          throw StateError('failed to encode the downscaled selfie');
        }
        return data.buffer.asUint8List();
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
}

/// The result of an onboarding capture attempt.
sealed class SelfieOutcome {
  const SelfieOutcome();
}

/// A selfie was captured.
class SelfieCaptured extends SelfieOutcome {
  const SelfieCaptured(this.bytes);
  final SelfieBytes bytes;
}

/// The player skipped, or capture failed. Either way they get a monogram —
/// §4 makes Skip a first-class path, not an error state.
class SelfieSkipped extends SelfieOutcome {
  const SelfieSkipped({this.reason});
  final String? reason;
}

/// Drives capture for one player.
class SelfieCaptureController {
  SelfieCaptureController({
    required this.source,
    this.processor = const SelfieProcessor(),
  });

  final SelfieSource source;
  final SelfieProcessor processor;

  /// Captures one frame and downscales it.
  ///
  /// Any failure becomes [SelfieSkipped] rather than an exception: a camera
  /// permission denial or a plugin error must drop the player to a monogram,
  /// not strand onboarding with people waiting to be passed the phone.
  Future<SelfieOutcome> capture() async {
    try {
      final frame = await source.captureFrame();
      if (frame == null) {
        return const SelfieSkipped(reason: 'no frame available');
      }
      return SelfieCaptured(await processor.process(frame));
    } on Object catch (error) {
      debugPrint('Selfie capture failed, falling back to monogram: $error');
      return SelfieSkipped(reason: error.toString());
    }
  }

  Future<void> dispose() => source.dispose();
}
