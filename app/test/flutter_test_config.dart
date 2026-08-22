// Alchemist configuration for every test under test/.
//
// Platform goldens are disabled deliberately: CI-mode goldens render text as
// blocked rectangles with the Ahem font and skip shadows, which makes a single
// set of baselines valid on a Windows dev machine and a Linux CI container
// alike. See docs/06-TESTING-STRATEGY.md §3.
//
// Baselines are authoritative when regenerated in Docker
// (`docker compose -f docker-compose.goldens.yml run --rm goldens`), never from
// a laptop. Locally generated baselines must not be committed.

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
