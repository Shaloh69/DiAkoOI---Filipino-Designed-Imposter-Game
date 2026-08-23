# ADR 0005 — Extended RAM and the selfie privacy guarantee

**Status:** Accepted · **Date:** 2026-08-22

## Context

The reference device ships 8GB physical RAM plus 8GB vivo Extended RAM, a UFS-backed swap
file (`docs/06-TESTING-STRATEGY.md` §8d). Selfies are held only in process memory as a
stated privacy differentiator (`docs/01-DESIGN.md` §4b).

When Extended RAM engages, the kernel pages cold process memory — including whatever holds
those bytes — to storage. This happens below the application layer. Flutter and Dart expose
no way to mark a buffer non-swappable, and `mlock`-style pinning is not available to us.

## Decision

Keep the in-memory design. **Scope the guarantee to the application layer**, downscale
selfies at capture, and word all public copy accordingly.

| Claim | Status |
|---|---|
| "The app never writes your photo to storage" | Provable, and `no_disk_write_test` proves it |
| "Your photo never leaves your device" | True |
| "Your photo never touches disk under any circumstance" | **Not guaranteeable** — must not appear anywhere |

## Rationale

Vendor memory extension is standard across mid-range Android and enabled by default;
targeting devices without it is not an option. No API exists to pin a Dart buffer as
non-swappable.

The honest guarantee — the app writes nothing — is still substantially stronger than every
competitor, all of which upload or persist. Overclaiming would trade a real, defensible
differentiator for a marginally punchier sentence, and A8 audits the privacy page line by
line against actual behaviour, so the overclaim would surface as an audit failure later
rather than never.

## Consequences

- Privacy copy is slightly longer and less punchy. Accepted.
- `no_disk_write_test` carries a comment bounding what it proves: it asserts the
  application writes nothing and cannot assert anything about kernel paging. The
  requirement is recorded in `app/test/privacy/README.md` until the test exists in Phase 4.
- The capture path downscales to display resolution (Polaroid thumbnail + grid tile) rather
  than holding a full sensor frame. A5 wanted this regardless: at 20 players it is roughly
  the difference between ~240MB and ~6MB of live image data, which is the difference
  between triggering Extended RAM and not.
- `docs/09-WEB-SPEC.md` §A4 and `docs/01-DESIGN.md` §4b are worded to match.

## Mitigations, in order of value

1. **Minimise lifetime.** Hold the selfie only as long as the roster exists — already the
   design. Swap risk scales with time resident.
2. **Minimise size.** Downscale at capture. Smaller buffers are less likely to be selected
   for paging and cheaper if they are.
3. **Clear on teardown.** Overwrite the bytes before dropping the reference on New Game.
   Does not unwrite a swap page, but shortens the window.
