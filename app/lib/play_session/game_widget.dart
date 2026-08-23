// Copyright 2022, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// Adapted for DiAkoOi: provider -> flutter_riverpod. The template read
// GameLevel and LevelState from an ancestor MultiProvider scoped to the play
// session. Riverpod has no ancestor-scoped `Provider.value`, so the session
// owner passes them down and this widget listens to the notifier directly.

import 'package:diakooi/audio/sounds.dart';
import 'package:diakooi/game_internals/level_state.dart';
import 'package:diakooi/level_selection/levels.dart';
import 'package:diakooi/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// This widget defines the game UI itself, without things like the settings
/// button or the back button.
class GameWidget extends ConsumerWidget {
  const GameWidget({required this.level, required this.levelState, super.key});

  final GameLevel level;

  final LevelState levelState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: levelState,
      builder: (context, _) {
        return Column(
          children: [
            Text('Drag the slider to ${level.difficulty}% or above!'),
            Slider(
              label: 'Level Progress',
              autofocus: true,
              value: levelState.progress / 100,
              onChanged: (value) =>
                  levelState.setProgress((value * 100).round()),
              onChangeEnd: (value) {
                ref.read(audioControllerProvider).playSfx(SfxType.wssh);
                levelState.evaluate();
              },
            ),
          ],
        );
      },
    );
  }
}
