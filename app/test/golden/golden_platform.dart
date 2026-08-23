import 'dart:io' show Platform, stdout;

/// The one command that regenerates and verifies golden baselines.
///
/// Named here so the skip reason, the warning banner and the docs cannot drift
/// apart from each other.
const goldenRegenerationCommand =
    'docker compose -f docker-compose.goldens.yml run --rm goldens';

int _skippedGroupCount = 0;

/// How many golden groups this test file skipped. Visible for testing.
int get skippedGoldenGroupCount => _skippedGroupCount;

/// Why golden tests do not run outside Linux.
///
/// Alchemist's CI mode blocks text and drops shadows to reduce cross-platform
/// variance, but it does not eliminate it: the same test differs by roughly
/// 0.7% of pixels between Windows and Linux. Baselines are therefore generated
/// on Linux only, matching the CI runner, and comparing them anywhere else
/// fails for reasons that have nothing to do with the widget under test.
///
/// Pass to `group(..., skip: skipUnlessGoldenPlatform)` in every golden test.
/// Returns `null` on Linux so the group runs normally.
///
/// See docs/adr/0004-golden-baselines.md and docs/06-TESTING-STRATEGY.md §3.
Object? get skipUnlessGoldenPlatform {
  if (Platform.isLinux) return null;

  _skippedGroupCount++;
  return 'Golden baselines are Linux-locked. Regenerate and verify with: '
      '$goldenRegenerationCommand';
}

/// Prints a loud banner when golden groups were skipped.
///
/// Without this, `flutter test --tags golden` exits 0 on a developer machine
/// having verified nothing, and a green run reads as "visuals checked". At the
/// Phase 3 matrix size — every primitive × every Vibe Pack — that misreading
/// is how a hardcoded design value ships. Called from
/// `test/flutter_test_config.dart` after registration.
void reportSkippedGoldenGroups() {
  if (_skippedGroupCount == 0) return;

  final plural = _skippedGroupCount == 1 ? 'group' : 'groups';
  stdout.writeln(
    '\n'
    '!! GOLDENS NOT VERIFIED ------------------------------------------\n'
    '!! $_skippedGroupCount golden $plural skipped on '
    '${Platform.operatingSystem}. Nothing visual was checked.\n'
    '!! A green run here does NOT mean the goldens pass.\n'
    '!! Baselines are byte-locked to Linux; CI is the authority.\n'
    '!! Verify or regenerate with:\n'
    '!!   $goldenRegenerationCommand\n'
    '!! -----------------------------------------------------------------\n',
  );
}
