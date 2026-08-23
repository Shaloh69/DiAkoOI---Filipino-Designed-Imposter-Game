import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:diakooi/selfie/selfie_capture.dart';
import 'package:flutter/foundation.dart';

/// A [SelfieSource] backed by the camera **preview stream** (01-DESIGN.md §4b).
///
/// **`takePicture()` is never called, and never may be.** It writes a JPEG to
/// the app's temp directory before handing back a path, which breaks the §4b
/// guarantee silently — nothing fails, the photo is simply on disk. The same
/// goes for `image_picker`. `test/privacy/no_disk_write_test.dart` fails the
/// build if either name appears in `lib/`.
///
/// `startImageStream` delivers sensor frames straight to Dart as planar bytes.
/// One is converted, the stream is stopped, and the controller is disposed.
class CameraSelfieSource implements SelfieSource {
  CameraSelfieSource({this.resolution = ResolutionPreset.medium});

  /// Deliberately not `max`. The frame is displayed at [SelfieTargets] sizes,
  /// so a sensor-resolution capture would buy nothing and cost the memory §8e
  /// says pushes a device into its Extended RAM swap.
  final ResolutionPreset resolution;

  CameraController? _controller;

  /// The live controller, for a preview widget. Null until [initialize].
  CameraController? get controller => _controller;

  /// Opens the front camera. Returns false if there is none, or if permission
  /// was refused — either way the player gets a monogram, not an error.
  Future<bool> initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        resolution,
        // No microphone. A party game has no use for one, and asking for the
        // permission would undercut everything §4b promises.
        enableAudio: false,
      );
      await controller.initialize();
      _controller = controller;
      return true;
    } on Object catch (error) {
      debugPrint('Camera unavailable, falling back to monogram: $error');
      return false;
    }
  }

  @override
  Future<CapturedFrame?> captureFrame() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return null;

    final completer = Completer<CameraImage>();
    await controller.startImageStream((image) {
      if (!completer.isCompleted) completer.complete(image);
    });
    final image = await completer.future;
    await controller.stopImageStream();

    final description = controller.description;
    final rgba = _toRgba(
      image,
      quarterTurns: description.sensorOrientation ~/ 90,
      mirror: description.lensDirection == CameraLensDirection.front,
    );
    if (rgba == null) return null;

    return CapturedFrame(await _encodePng(rgba));
  }

  @override
  Future<void> dispose() async {
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}

/// One frame's pixels, already oriented.
@immutable
class _Rgba {
  const _Rgba(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}

/// Converts a camera frame to RGBA, applying rotation and mirroring as index
/// arithmetic rather than as a second pass.
///
/// Doing it here keeps the rest of the pipeline working on ordinary encoded
/// bytes, and avoids materialising an intermediate full-size image just to
/// turn it the right way up.
_Rgba? _toRgba(
  CameraImage image, {
  required int quarterTurns,
  required bool mirror,
}) => switch (image.format.group) {
  ImageFormatGroup.yuv420 => _yuv420ToRgba(
    image,
    quarterTurns: quarterTurns,
    mirror: mirror,
  ),
  ImageFormatGroup.bgra8888 => _bgraToRgba(
    image,
    quarterTurns: quarterTurns,
    mirror: mirror,
  ),
  _ => null,
};

/// Where a source pixel lands in the output buffer.
int _destOffset({
  required int x,
  required int y,
  required int width,
  required int height,
  required int quarterTurns,
  required bool mirror,
}) {
  final sx = mirror ? width - 1 - x : x;
  return switch (quarterTurns % 4) {
    1 => ((x * height) + (height - 1 - y)) * 4,
    2 => (((height - 1 - y) * width) + (width - 1 - sx)) * 4,
    3 => (((width - 1 - x) * height) + y) * 4,
    _ => ((y * width) + sx) * 4,
  };
}

_Rgba _yuv420ToRgba(
  CameraImage image, {
  required int quarterTurns,
  required bool mirror,
}) {
  final width = image.width;
  final height = image.height;
  final rotated = quarterTurns.isOdd;
  final out = Uint8List(width * height * 4);

  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];
  final uvRowStride = uPlane.bytesPerRow;
  final uvPixelStride = uPlane.bytesPerPixel ?? 1;

  for (var y = 0; y < height; y++) {
    final yRow = y * yPlane.bytesPerRow;
    final uvRow = (y >> 1) * uvRowStride;
    for (var x = 0; x < width; x++) {
      final uvIndex = uvRow + (x >> 1) * uvPixelStride;
      final luma = yPlane.bytes[yRow + x];
      final u = uPlane.bytes[uvIndex] - 128;
      final v = vPlane.bytes[uvIndex] - 128;

      // BT.601, the colour space camera hardware delivers YUV in.
      final r = (luma + 1.370705 * v).round().clamp(0, 255);
      final g = (luma - 0.337633 * u - 0.698001 * v).round().clamp(0, 255);
      final b = (luma + 1.732446 * u).round().clamp(0, 255);

      final o = _destOffset(
        x: x,
        y: y,
        width: width,
        height: height,
        quarterTurns: quarterTurns,
        mirror: mirror,
      );
      out[o] = r;
      out[o + 1] = g;
      out[o + 2] = b;
      out[o + 3] = 255;
    }
  }

  return _Rgba(out, rotated ? height : width, rotated ? width : height);
}

_Rgba _bgraToRgba(
  CameraImage image, {
  required int quarterTurns,
  required bool mirror,
}) {
  final width = image.width;
  final height = image.height;
  final rotated = quarterTurns.isOdd;
  final source = image.planes[0];
  final rowStride = source.bytesPerRow;
  final out = Uint8List(width * height * 4);

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = y * rowStride + x * 4;
      final o = _destOffset(
        x: x,
        y: y,
        width: width,
        height: height,
        quarterTurns: quarterTurns,
        mirror: mirror,
      );
      out[o] = source.bytes[i + 2];
      out[o + 1] = source.bytes[i + 1];
      out[o + 2] = source.bytes[i];
      out[o + 3] = source.bytes[i + 3];
    }
  }

  return _Rgba(out, rotated ? height : width, rotated ? width : height);
}

Future<Uint8List> _encodePng(_Rgba frame) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    frame.bytes,
    frame.width,
    frame.height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  final image = await completer.future;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('failed to encode the captured frame');
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
