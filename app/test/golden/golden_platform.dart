import 'dart:io' show Platform;

/// Why golden tests do not run outside Linux.
///
/// Alchemist's CI mode blocks text and drops shadows to make output stable, but
/// it is not byte-identical across operating systems: the same test differs by
/// roughly 0.7% of pixels between Windows and Linux. Baselines are therefore
/// generated on Linux only, matching the CI runner, and comparing them anywhere
/// else fails for reasons that have nothing to do with the widget under test.
///
/// Pass to `group(..., skip: skipUnlessGoldenPlatform)` in every golden test.
/// Returns `null` on Linux so the group runs normally.
///
/// See docs/06-TESTING-STRATEGY.md §3 and docs/adr/0003.
Object? get skipUnlessGoldenPlatform => Platform.isLinux
    ? null
    : 'Golden baselines are Linux-locked. Regenerate and verify with: '
          'docker compose -f docker-compose.goldens.yml run --rm goldens';
