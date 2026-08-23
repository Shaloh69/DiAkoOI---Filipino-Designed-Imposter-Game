// Phase 0 golden harness.
//
// One primitive, so `flutter test --tags golden` has something to run and the
// Alchemist baseline pipeline is proven end to end before Phase 3 depends on
// it. Phase 3 replaces this with the real matrix: every primitive × every Vibe
// Pack, which is what catches hardcoded design values
// (CLAUDE.md §Hard rules, docs/06-TESTING-STRATEGY.md §3).

import 'dart:async';

import 'package:alchemist/alchemist.dart';
import 'package:diakooi/style/my_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_platform.dart';

void main() {
  group('MyButton', () {
    unawaited(
      goldenTest(
        'renders its label',
        fileName: 'my_button',
        builder: () => GoldenTestGroup(
          children: [
            GoldenTestScenario(
              name: 'enabled',
              child: MyButton(onPressed: () {}, child: const Text('Play')),
            ),
            GoldenTestScenario(
              name: 'disabled',
              child: const MyButton(child: Text('Play')),
            ),
          ],
        ),
      ),
    );
  }, skip: skipUnlessGoldenPlatform);
}
