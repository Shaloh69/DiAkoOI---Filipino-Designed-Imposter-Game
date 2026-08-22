// Alchemist configuration for every test under test/.
//
// Platform goldens are disabled deliberately: CI-mode goldens render text as
// blocked rectangles with the Ahem font and skip shadows, which makes a single
// set of baselines valid on a Windows dev machine and a Linux CI container
// alike. See docs/06-TESTING-STRATEGY.md §3.
//
// CI mode is not byte-identical across operating systems, though: the same test
// differs by ~0.7% of pixels between Windows and Linux. Baselines are therefore
// generated on Linux only, pinned to the Flutter version CI uses:
//
//   docker compose -f docker-compose.goldens.yml run --rm goldens
//
// Golden groups skip off Linux — see test/golden/golden_platform.dart.

import 'dart:async';

import 'package:alchemist/alchemist.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(enabled: false),
    ),
    run: testMain,
  );
}
