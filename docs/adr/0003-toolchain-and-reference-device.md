# ADR 0003 — Toolchain versions and reference device

**Status:** Accepted · **Date:** 2026-08-22

## Context

Phase 0 needs the toolchain pinned before anything can be reproducibly verified, and
`docs/05-IMPLEMENTATION-PLAN.md` requires the A5 performance device to be *named* or the
audit cannot be failed.

## Decision

### Flutter 3.47.1 / Dart 3.13.1

The machine was on Flutter 3.35.3 (Dart 3.9.2). The adopted template declares
`sdk: ^3.12.0`, so `flutter pub get` refused outright. The SDK was upgraded to **3.47.1**,
the current stable at adoption (released 2026-08-19, ships Dart 3.13.1).

Upgrading the machine-wide SDK was chosen over FVM because `CLAUDE.md §Commands` specifies
`flutter test`, not `fvm flutter test`, and the A0 audit requires those commands to run as
written. FVM would have needed a PATH shim to keep that true.

CI pins the same version via `subosito/flutter-action`.

### Node 22, pnpm 11.22.0

`corepack enable` fails on this machine (EPERM writing shims into `C:\Program Files\nodejs`),
so pnpm is installed through `npm i -g pnpm`, whose prefix is user-writable. The version is
recorded in the root `package.json` `packageManager` field.

pnpm 10+ blocks dependency build scripts by default and **fails the install** when one is
skipped. The allowlist lives in `pnpm-workspace.yaml` (`onlyBuiltDependencies`). Inside the
API's Docker image there is no workspace file, so that stage installs with
`--ignore-scripts` instead — the image never runs tests, so it needs no native test binary.

### Reference device — Vivo V60 Lite 5G

All A5 performance audits run on this device: named, physically available, and
representative of the target market. Specifications in `docs/06-TESTING-STRATEGY.md` §8
(Dimensity 7360-Turbo, Mali-G615 MC2, 6.77" AMOLED 1080×2392 @ 120Hz).

## Consequences

- Other Flutter projects on this machine (BlueWatt, AIRAT-NA, EngiRent) also move to
  3.47.1. Accepted deliberately when the upgrade was chosen.
- Golden baselines are generated on Linux only, pinned to this same Flutter version. CI
  mode reduces cross-platform variance but does not produce byte-identical output — see
  **ADR 0004** for the measurement, the Docker workflow, and the accepted tradeoff.

## Still open

Two Phase 0 checklist items remain owned by a human and are **not** settled by this ADR:

1. **Confirm the exact V60 Lite variant/chipset** in Settings → About. The table above is
   from published specifications, not from the physical handset.
2. **120Hz (8.3ms) vs capped 60Hz (16.6ms) frame target.** This is the budget every A5
   audit is measured against and must be decided before Phase 5. Record it here when it is.
