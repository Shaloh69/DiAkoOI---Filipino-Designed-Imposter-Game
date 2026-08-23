# ADR 0004 — Golden baselines are Linux-locked

**Status:** Accepted · **Date:** 2026-08-23

> **Numbering note.** This was requested as `0003`, but `0003-toolchain-and-reference-device.md`
> already exists from earlier in Phase 0. ADR numbers are identifiers, so this takes the next
> free number. The golden-baseline consequences previously noted in 0003 now live here, and
> 0003 points at this file.

## Context

`docs/06-TESTING-STRATEGY.md` §3 specifies Alchemist in **CI mode** for Flutter visual
regression, on the reasoning that CI mode "renders text as coloured blocks using the Ahem
font, which sidesteps the font-rendering differences that make goldens flaky". It also says
to generate baselines in Docker.

During Phase 0 the first baseline was generated on the development machine (Windows) rather
than in Docker, on the assumption that CI mode made output platform-independent and the
Docker step therefore optional.

**That assumption is false, and it was tested rather than argued.** The Windows-generated
baseline was run against the identical test inside a Linux container on the same Flutter
version (3.47.1):

```
Golden "goldens/ci/my_button.png": Pixel test failed, 0.73%, 156px diff detected.
```

CI mode **reduces** cross-platform variance. It does not eliminate it, and it does not
produce byte-identical output. Since CI runs on Linux, the committed baseline would have
failed the `dart` job on the first pull request — a machine-specific failure of exactly the
kind the Docker instruction exists to prevent.

## Decision

**Baselines are generated on Linux only, pinned to the Flutter version CI uses.**

- `docker/goldens.Dockerfile` builds from `ghcr.io/cirruslabs/flutter` and checks out the
  pinned Flutter tag. That pin **must** equal `FLUTTER_VERSION` in
  `.github/workflows/ci.yml`; both files carry a comment saying so.
- `docker-compose.goldens.yml` runs the regeneration:

  ```
  docker compose -f docker-compose.goldens.yml run --rm goldens
  ```

  Sources are mounted read-only and built in a scratch copy inside the container, so Linux
  `.dart_tool/` and `build/` artifacts never land in a Windows working tree. Only the
  regenerated PNGs are written back.
- Platform goldens stay **disabled** (`PlatformGoldensConfig(enabled: false)`), so there is
  one baseline set rather than one per operating system.
- Golden groups **skip off Linux** via `app/test/golden/golden_platform.dart`, passed as
  `group(..., skip: skipUnlessGoldenPlatform)`.

### The skip is loud, deliberately

A skipped golden suite exits 0. Left silent, `flutter test --tags golden` would report
green having verified nothing, and at the Phase 3 matrix size — every primitive × every
Vibe Pack — someone will read that green as "visuals verified". That misreading is how a
hardcoded design value ships past the one check designed to catch it.

So the skip announces itself: `test/flutter_test_config.dart` calls
`reportSkippedGoldenGroups()` after registration, printing the number of skipped groups,
the host platform, and the regeneration command:

```
!! GOLDENS NOT VERIFIED ------------------------------------------
!! 1 golden group skipped on windows. Nothing visual was checked.
!! A green run here does NOT mean the goldens pass.
!! Baselines are byte-locked to Linux; CI is the authority.
!! Verify or regenerate with:
!!   docker compose -f docker-compose.goldens.yml run --rm goldens
!! -----------------------------------------------------------------
```

The banner does not print on Linux, where the goldens actually run.

Every audit line asserting goldens pass now says **in CI** explicitly
(`docs/05-IMPLEMENTATION-PLAN.md` A3, Phase 3 exit, and Standing rules), and
`CLAUDE.md` §Testing states it too.

## Consequences

- **Windows and macOS developers get no local golden feedback.** Accepted. It is inherent
  to platform-locked baselines, and it is the same tradeoff `docs/06-TESTING-STRATEGY.md`
  §4 already makes for Playwright visual baselines. The Docker command is the escape hatch
  when local feedback is genuinely needed.
- CI is the sole authority on visual regression. A golden change must be reviewed as a diff
  in CI, never approved because it passed locally.
- The Flutter version is pinned in two places. They drift silently if edited apart, and the
  symptom months later is an unexplainable golden diff. Both files carry a
  `PIN 1 of 2` / `PIN 2 of 2` comment naming the other and saying to change them together.

  Verified 2026-08-23: `docker/goldens.Dockerfile` `ARG FLUTTER_VERSION=3.47.1`,
  `.github/workflows/ci.yml` `FLUTTER_VERSION: '3.47.1'`, and the built image reports
  `Flutter 3.47.1 • revision 6655482ec0` — identical.
- Regenerating baselines requires Docker. On a machine without it, goldens cannot be
  updated at all; that is preferable to updating them wrongly.

## Alternatives rejected

**Commit per-platform baselines** (`goldens/windows/`, `goldens/linux/`). Alchemist supports
it via platform goldens, but it multiplies the Phase 3 matrix by the number of developer
operating systems and invites approving a Windows baseline that CI never checks.

**Loosen the comparison threshold** so a 0.73% diff passes. This is the tempting one and it
is wrong: the tolerance that hides a platform difference also hides a real regression, which
defeats the purpose of the matrix.

**Generate baselines in CI and commit them back from the workflow.** Viable later, but it
puts a write credential on a workflow for no benefit Phase 0 needs.
