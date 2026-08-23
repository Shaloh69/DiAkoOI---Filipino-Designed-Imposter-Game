# Privacy tests

`app/test/privacy/` is off-limits without explicit instruction (CLAUDE.md §Off-limits).
The disk-write assertions here are the proof behind a public claim, so weakening them
weakens the claim.

## What `no_disk_write_test.dart` must prove (Phase 4)

Zero new files under the temp and documents directories across a full onboarding run.
`image_picker` and `camera.takePicture()` both write a temp file by default and will
silently break this — capture from the preview stream into `Uint8List`, or
read-then-delete inside a `finally` (`docs/01-DESIGN.md` §4b).

## What it must NOT be read as proving

When that test is written, it **must carry a comment stating its bound**, to this effect:

```dart
// SCOPE OF THIS TEST — read before trusting it.
//
// This asserts that the APPLICATION writes no selfie bytes to storage. That is
// the whole of the claim we make publicly.
//
// It cannot and does not assert anything about kernel paging. The reference
// device ships vendor Extended RAM (a UFS-backed swap file) which may page
// process memory — including these bytes — to storage below our layer. Flutter
// exposes no way to mark a buffer non-swappable.
//
// So: "the app never writes your photo to storage" is proven here.
// "your photo never touches disk" is NOT, and must never be claimed.
//
// See docs/adr/0005-extended-ram-and-selfie-privacy.md and
// docs/06-TESTING-STRATEGY.md §8e.
```

Recorded here because the test does not exist yet and this bound must not be lost between
now and Phase 4.
