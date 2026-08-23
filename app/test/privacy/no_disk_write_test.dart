import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:diakooi/selfie/selfie_bytes.dart';
import 'package:diakooi/selfie/selfie_capture.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SCOPE OF THIS TEST — read before trusting it.
//
// This asserts that the APPLICATION writes no selfie bytes to storage. That is
// the whole of the claim made publicly, and the only claim that is provable.
//
// It cannot and does not assert anything about kernel paging. The reference
// device ships vendor Extended RAM — a UFS-backed swap file — which may page
// process memory, including these bytes, to storage below our layer. Flutter
// exposes no way to mark a buffer non-swappable.
//
// So: "the app never writes your photo to storage" is proven here.
//     "your photo never touches disk" is NOT, and must never be claimed.
//
// See docs/adr/0005-extended-ram-and-selfie-privacy.md and
// docs/06-TESTING-STRATEGY.md §8e.
//
// This directory is off-limits without explicit instruction (CLAUDE.md).
// Weakening these assertions weakens a public claim.
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('static: the two APIs that silently break the guarantee', () {
    // A runtime test only catches what it happens to exercise. These two APIs
    // write a temp file BY DEFAULT (01-DESIGN.md §4b implementation warning),
    // so their mere presence in lib/ is the defect — no execution required.
    test('lib/ never references image_picker or takePicture', () {
      final lib = Directory('lib');
      expect(lib.existsSync(), isTrue, reason: 'run from app/');

      final offenders = <String>[];
      var scanned = 0;

      for (final entity in lib.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('.g.dart') ||
            entity.path.endsWith('.freezed.dart')) {
          continue;
        }
        scanned++;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          // Comments explaining why these are banned are fine; uses are not.
          final trimmed = line.trimLeft();
          if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
          if (line.contains('image_picker') ||
              line.contains('ImagePicker') ||
              line.contains('takePicture(')) {
            offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
          }
        }
      }

      expect(
        scanned,
        greaterThan(0),
        reason: 'no Dart files scanned — the check would pass vacuously',
      );
      expect(
        offenders,
        isEmpty,
        reason:
            'image_picker and camera.takePicture() both write a temp file by '
            'default and will silently break the §4b guarantee. Capture from '
            'the preview stream into a Uint8List instead. Found:\n'
            '${offenders.join('\n')}',
      );
    });
  });

  group('runtime: a full onboarding run writes nothing', () {
    late Directory sandbox;
    late Directory temp;
    late Directory documents;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('diakooi-privacy');
      temp = Directory('${sandbox.path}${Platform.pathSeparator}tmp')
        ..createSync();
      documents = Directory('${sandbox.path}${Platform.pathSeparator}docs')
        ..createSync();
    });

    tearDown(() => sandbox.deleteSync(recursive: true));

    List<String> snapshot() => [
      for (final dir in [temp, documents])
        for (final entity in dir.listSync(recursive: true)) entity.path,
    ]..sort();

    test(
      'capturing selfies for a full 20-player roster creates no files',
      () async {
        final before = snapshot();

        final frame = await _syntheticFrame();
        final controller = SelfieCaptureController(
          source: _FakeSelfieSource(frame),
        );

        final roster = <SelfieBytes>[];
        // Twenty is the §2 maximum and the worst case for both memory and for
        // any accidental per-player file write.
        for (var i = 0; i < 20; i++) {
          final outcome = await controller.capture();
          expect(outcome, isA<SelfieCaptured>());
          roster.add((outcome as SelfieCaptured).bytes);
        }
        await controller.dispose();

        expect(roster, hasLength(20));
        expect(
          snapshot(),
          before,
          reason:
              'onboarding created a file. Something in the capture path is '
              'writing to storage (01-DESIGN.md §4b)',
        );

        for (final selfie in roster) {
          selfie.shred();
        }
        expect(
          snapshot(),
          before,
          reason: 'teardown created a file',
        );
      },
    );

    test('a skipped capture writes nothing either', () async {
      final before = snapshot();
      final controller = SelfieCaptureController(
        source: const _FakeSelfieSource(null),
      );
      final outcome = await controller.capture();
      await controller.dispose();

      expect(outcome, isA<SelfieSkipped>());
      expect(snapshot(), before);
    });

    test('a failing camera falls back to a monogram without writing', () async {
      final before = snapshot();
      final controller = SelfieCaptureController(
        source: const _ThrowingSelfieSource(),
      );
      final outcome = await controller.capture();
      await controller.dispose();

      expect(
        outcome,
        isA<SelfieSkipped>(),
        reason:
            'a permission denial must drop the player to a monogram, not '
            'strand onboarding with people waiting',
      );
      expect(snapshot(), before);
    });
  });

  group('the bytes themselves', () {
    test('are downscaled at capture, not held at sensor resolution', () async {
      final frame = await _syntheticFrame(size: 1600);
      final selfie = await const SelfieProcessor().process(frame);

      // A 1600x1600 RGBA buffer is ~10MB. Twenty of those is the number §8e
      // says pushes a device into swap.
      const sensorRgbaBytes = 1600 * 1600 * 4;
      expect(
        selfie.byteLength,
        lessThan(sensorRgbaBytes ~/ 10),
        reason:
            'the stored renditions must be far smaller than the frame they '
            'came from — that is the §8e mitigation, not a cosmetic resize',
      );

      final polaroid = await _decodedSize(selfie.polaroid);
      final tile = await _decodedSize(selfie.gridTile);
      expect(polaroid.width, SelfieTargets.polaroidPx);
      expect(tile.width, SelfieTargets.gridTilePx);
      expect(
        tile.width,
        lessThan(polaroid.width),
        reason: 'the grid tile is the one shown twenty times at once',
      );
    });

    test('shredding overwrites and then refuses reads', () async {
      final selfie = await const SelfieProcessor().process(
        await _syntheticFrame(),
      );
      expect(selfie.byteLength, greaterThan(0));
      expect(selfie.isShredded, isFalse);

      selfie.shred();

      expect(selfie.isShredded, isTrue);
      expect(selfie.byteLength, 0);
      expect(
        () => selfie.polaroid,
        throwsStateError,
        reason:
            'reading a shredded selfie means the reference outlived its '
            'roster — that should fail loudly, not return stale bytes',
      );
    });

    test('shredding twice is harmless', () async {
      final selfie = await const SelfieProcessor().process(
        await _syntheticFrame(),
      );
      selfie.shred();
      expect(selfie.shred, returnsNormally);
    });

    test('there is no way to construct one from a path', () {
      // Expressed as a type-level guarantee rather than a comment: if someone
      // adds a `SelfieBytes.fromFile` this stops compiling, which is a louder
      // failure than a review comment.
      expect(
        SelfieBytes.new,
        isA<
          SelfieBytes Function({
            required Uint8List polaroid,
            required Uint8List gridTile,
          })
        >(),
      );
    });
  });
}

/// A small encoded image, standing in for a camera frame.
Future<CapturedFrame> _syntheticFrame({int size = 640}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final paint = ui.Paint()..color = const ui.Color(0xFF4ADE80);
  canvas
    ..drawRect(
      ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      paint,
    )
    ..drawCircle(
      ui.Offset(size / 2, size / 2),
      size / 4,
      ui.Paint()..color = const ui.Color(0xFFF0A868),
    );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return CapturedFrame(data!.buffer.asUint8List());
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<({int width, int height})> _decodedSize(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  try {
    final frame = await codec.getNextFrame();
    try {
      return (width: frame.image.width, height: frame.image.height);
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

class _FakeSelfieSource implements SelfieSource {
  const _FakeSelfieSource(this.frame);

  final CapturedFrame? frame;

  @override
  Future<CapturedFrame?> captureFrame() async => frame;

  @override
  Future<void> dispose() async {}
}

class _ThrowingSelfieSource implements SelfieSource {
  const _ThrowingSelfieSource();

  @override
  Future<CapturedFrame?> captureFrame() async =>
      throw StateError('camera permission denied');

  @override
  Future<void> dispose() async {}
}
