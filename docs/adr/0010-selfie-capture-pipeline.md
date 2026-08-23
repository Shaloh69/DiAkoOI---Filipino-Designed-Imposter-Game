# ADR 0010 — Selfie capture: preview stream, converted and downscaled in Dart

**Status:** Accepted · **Date:** 2026-08-23

## Context

`01-DESIGN.md` §4b requires that **the app never writes a selfie to storage**. ADR 0005 fixes
the exact scope of that claim: it is an application-level guarantee, and it does not and
cannot extend to kernel paging, because the reference device ships vendor Extended RAM.

The two obvious ways to get a photo in Flutter both break the guarantee, and both break it
**silently** — nothing throws, nothing logs, the photo is simply on disk:

- `image_picker` hands back a path to a file it has already written.
- `camera`'s `CameraController.takePicture()` writes a JPEG to the app's temp directory and
  returns its path.

Neither is recoverable by deleting afterwards. A read-then-delete leaves the bytes on flash
until they are overwritten, and a crash between the two leaves them indefinitely.

## Decision

**Capture one frame from `startImageStream`, convert it in Dart, and stop the stream.**

`CameraSelfieSource` opens the front camera at `ResolutionPreset.medium` with
`enableAudio: false`, takes the first frame the stream delivers, converts it to RGBA, encodes
it once as PNG, and disposes. `takePicture` is never called and no file path exists anywhere
in the pipeline. `SelfieBytes` has no constructor that takes a path, so reintroducing one is
a deliberate act rather than an accident.

Three details are load-bearing:

**Rotation and mirroring are index arithmetic inside the conversion, not a second pass.**
Sensor frames arrive rotated by `sensorOrientation` and a front-camera selfie should read as
a mirror. Doing both while writing the output buffer avoids materialising an intermediate
full-size image purely to turn it the right way up.

**`ResolutionPreset.medium`, not `max`.** The frame is displayed at `SelfieTargets` sizes —
320px and 192px — so a sensor-resolution capture buys nothing and costs the memory §8e warns
about. Twenty players holding full frames is hundreds of megabytes of live image data, which
is enough to push a device into the very swap ADR 0005 says we cannot control. Capturing
small is the mitigation; it is not a cosmetic choice.

**`instantiateImageCodec(targetWidth:)` for the two renditions.** It decodes *at* the target
size rather than decoding full-size and shrinking, so the larger bitmap never exists.

`enableAudio: false` is deliberate beyond being unused: asking for a microphone permission
would undercut the one privacy claim the app makes. The manifest declares `CAMERA` and marks
both camera features `required="false"`, so the app still installs on a device without one.

## Consequences

**Good.**

- The guarantee is enforced by a static check as well as a runtime one.
  `test/privacy/no_disk_write_test.dart` fails the build if `image_picker`, `ImagePicker` or
  `takePicture(` appears anywhere in `lib/`, because a runtime test only catches what it
  happens to exercise and this failure mode is silent.
- Every failure path ends at a monogram. No camera, refused permission, no frame, a plugin
  error — all become `SelfieSkipped`. §4 makes Skip a first-class path, and a table with the
  phone in someone's hand cannot be stranded on an error.
- The conversion is ordinary Dart, so onboarding is widget-testable against a fake camera
  and the captured-selfie branch is covered rather than only the monogram one.

**Costs.**

- YUV420 → RGBA in Dart is a per-pixel loop. At `medium` it is one frame per player and
  measured in tens of milliseconds, which is why the preset matters; at `max` this approach
  would be the wrong one.
- `bgra8888` is handled for completeness but is an iOS format, and v1 is Android only
  (`CLAUDE.md` §Identity). Any other `ImageFormatGroup` returns null and the player gets a
  monogram rather than a wrong-coloured photograph.
- We depend on the first streamed frame being usable. In practice the first frame after
  `initialize()` is exposed and focused because the preview has been running; if that proves
  wrong on the reference device the fix is to drop the first N frames, not to reach for
  `takePicture`.

## What this does not claim

Nothing here makes the bytes unswappable. "The app never writes your photo to storage" is
proven. "Your photo never touches disk" is not, and must not appear anywhere — see ADR 0005
and `06-TESTING-STRATEGY.md` §8e. The capture UI says the former and stops there.
