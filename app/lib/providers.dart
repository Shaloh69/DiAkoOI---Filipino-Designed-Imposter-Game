// Copyright 2026, Team Lanzones. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// Riverpod replacements for the MultiProvider tree the Flutter Casual Games
// Toolkit template declared in main.dart. See docs/adr/0002-templates.md.
//
// ChangeNotifierProvider comes from flutter_riverpod's legacy export because
// PlayerProgress and LevelState are template ChangeNotifiers. Phase 1 replaces
// them with freezed models and Notifier subclasses (docs/05-IMPLEMENTATION-PLAN.md).

import 'package:diakooi/app_lifecycle/app_lifecycle.dart';
import 'package:diakooi/audio/audio_controller.dart';
import 'package:diakooi/player_progress/player_progress.dart';
import 'package:diakooi/settings/settings.dart';
import 'package:diakooi/style/palette.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Persisted player settings, including mute state.
final settingsControllerProvider = Provider<SettingsController>(
  (ref) => SettingsController(),
);

/// The active colour palette.
///
/// Phase 3 replaces this with the Vibe Pack theme resolver; nothing outside a
/// theme file may hardcode a colour (CLAUDE.md §Hard rules).
final paletteProvider = Provider<Palette>((ref) => Palette());

/// Player progress across levels. Template scaffolding, replaced in Phase 4.
final playerProgressProvider = ChangeNotifierProvider<PlayerProgress>(
  (ref) => PlayerProgress(),
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
