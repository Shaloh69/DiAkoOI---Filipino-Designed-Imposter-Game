// Copyright 2022, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:diakooi/audio/sounds.dart';
import 'package:diakooi/game_internals/level_state.dart';
import 'package:diakooi/game_internals/score.dart';
import 'package:diakooi/level_selection/levels.dart';
import 'package:diakooi/play_session/game_widget.dart';
import 'package:diakooi/providers.dart';
import 'package:diakooi/style/confetti.dart';
import 'package:diakooi/style/my_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart' hide Level;

/// This widget defines the entirety of the screen that the player sees when
/// they are playing a level.
///
/// It is a stateful widget because it manages some state of its own,
/// such as whether the game is in a "celebration" state.
class PlaySessionScreen extends ConsumerStatefulWidget {
  const PlaySessionScreen(this.level, {super.key});

  final GameLevel level;

  @override
  ConsumerState<PlaySessionScreen> createState() => _PlaySessionScreenState();
}

class _PlaySessionScreenState extends ConsumerState<PlaySessionScreen> {
  static final _log = Logger('PlaySessionScreen');

  static const _celebrationDuration = Duration(milliseconds: 2000);

  static const _preCelebrationDuration = Duration(milliseconds: 500);

  bool _duringCelebration = false;

  late DateTime _startOfPlay;

  late final LevelState _levelState;

  @override
  void initState() {
    super.initState();

    _startOfPlay = DateTime.now();
    _levelState = LevelState(
      goal: widget.level.difficulty,
      onWin: _playerWon,
    );
  }

  @override
  void dispose() {
    _levelState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(paletteProvider);

    return IgnorePointer(
      // Ignore all input during the celebration animation.
      ignoring: _duringCelebration,
      child: Scaffold(
        backgroundColor: palette.backgroundPlaySession,
        // The stack is how you layer widgets on top of each other.
        // Here, it is used to overlay the winning confetti animation on top
        // of the game.
        body: Stack(
          children: [
            // This is the main layout of the play session screen,
            // with a settings button on top, the actual play area
            // in the middle, and a back button at the bottom.
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: InkResponse(
                    onTap: () => GoRouter.of(context).push('/settings'),
                    child: Image.asset(
                      'assets/images/settings.png',
                      semanticLabel: 'Settings',
                    ),
                  ),
                ),
                const Spacer(),
                Expanded(
                  // The actual UI of the game.
                  child: GameWidget(
                    level: widget.level,
                    levelState: _levelState,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: MyButton(
                    onPressed: () => GoRouter.of(context).go('/play'),
                    child: const Text('Back'),
                  ),
                ),
              ],
            ),
            // This is the confetti animation that is overlaid on top of the
            // game when the player wins.
            SizedBox.expand(
              child: Visibility(
                visible: _duringCelebration,
                child: IgnorePointer(
                  child: Confetti(isStopped: !_duringCelebration),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playerWon() async {
    _log.info('Level ${widget.level.number} won');

    final score = Score(
      widget.level.number,
      widget.level.difficulty,
      DateTime.now().difference(_startOfPlay),
    );

    ref.read(playerProgressProvider).setLevelReached(widget.level.number);

    // Let the player see the game just after winning for a bit.
    await Future<void>.delayed(_preCelebrationDuration);
    if (!mounted) return;

    setState(() {
      _duringCelebration = true;
    });

    ref.read(audioControllerProvider).playSfx(SfxType.congrats);

    /// Give the player some time to see the celebration animation.
    await Future<void>.delayed(_celebrationDuration);
    if (!mounted) return;

    GoRouter.of(context).go('/play/won', extra: {'score': score});
  }
}
