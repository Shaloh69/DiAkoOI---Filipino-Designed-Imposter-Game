// Copyright 2026, Team Lanzones. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Riverpod replacements for the MultiProvider tree the Flutter Casual Games
// Toolkit template declared in main.dart. See docs/adr/0002-templates.md.
//
// The template's demo screens, palette and progress store went with Phase 4:
// the game is the app now, and a second colour source outside the Vibe Pack
// theme is exactly the hardcoded-design-value failure CLAUDE.md bans.

import 'package:diakooi/app_lifecycle/app_lifecycle.dart';
import 'package:diakooi/audio/audio_controller.dart';
import 'package:diakooi/settings/settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Persisted player settings, including mute state.
final settingsControllerProvider = Provider<SettingsController>(
  (ref) => SettingsController(),
);

/// Music and SFX facade over `package:audioplayers`.
///
/// Kept alive for the life of the app so music is not restarted on rebuilds,
/// and wired to both lifecycle and settings so backgrounding stops playback.
final audioControllerProvider = Provider<AudioController>((ref) {
  final controller = AudioController()
    ..attachDependencies(
      ref.watch(appLifecycleStateNotifierProvider),
      ref.watch(settingsControllerProvider),
    );
  ref.onDispose(controller.dispose);
  return controller;
});
