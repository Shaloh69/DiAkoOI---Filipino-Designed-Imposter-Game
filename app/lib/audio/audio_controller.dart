// Copyright 2022, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:diakooi/app_lifecycle/app_lifecycle.dart';
import 'package:diakooi/audio/songs.dart';
import 'package:diakooi/audio/sounds.dart';
import 'package:diakooi/settings/settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';

/// Allows playing music and sound. A facade to `package:audioplayers`.
class AudioController {
  /// Creates an instance that plays music and sound.
  ///
  /// Use [polyphony] to configure the number of sound effects (SFX) that can
  /// play at the same time. A [polyphony] of `1` will always only play one
  /// sound (a new sound will stop the previous one). See discussion
  /// of [_sfxPlayers] to learn why this is the case.
  ///
  /// Background music does not count into the [polyphony] limit. Music will
  /// never be overridden by sound effects because that would be silly.
  AudioController({int polyphony = 2})
    : assert(polyphony >= 1, 'polyphony must be at least 1'),
      _musicPlayer = AudioPlayer(playerId: 'musicPlayer'),
      _sfxPlayers = Iterable.generate(
        polyphony,
        (i) => AudioPlayer(playerId: 'sfxPlayer#$i'),
      ).toList(growable: false),
      _playlist = Queue.of(List<Song>.of(songs)..shuffle()) {
    _musicPlayer.onPlayerComplete.listen(_handleSongFinished);
    unawaited(_preloadSfx());
  }
  static final _log = Logger('AudioController');

  final AudioPlayer _musicPlayer;

  /// This is a list of [AudioPlayer] instances which are rotated to play
  /// sound effects.
  final List<AudioPlayer> _sfxPlayers;

  int _currentSfxPlayer = 0;

  final Queue<Song> _playlist;

  final Random _random = Random();

  SettingsController? _settings;

  ValueNotifier<AppLifecycleState>? _lifecycleNotifier;

  /// Makes sure the audio controller is listening to changes
  /// of both the app lifecycle (e.g. suspended app) and to changes
  /// of settings (e.g. muted sound).
  void attachDependencies(
    AppLifecycleStateNotifier lifecycleNotifier,
    SettingsController settingsController,
  ) {
    _attachLifecycleNotifier(lifecycleNotifier);
    _attachSettings(settingsController);
  }

  void dispose() {
    _lifecycleNotifier?.removeListener(_handleAppLifecycle);
    _stopAllSound();
    unawaited(_musicPlayer.dispose());
    for (final player in _sfxPlayers) {
      unawaited(player.dispose());
    }
  }

  /// Plays a single sound effect, defined by [type].
  ///
  /// The controller will ignore this call when the attached settings'
  /// [SettingsController.audioOn] is `true` or if its
  /// [SettingsController.soundsOn] is `false`.
  void playSfx(SfxType type) {
    final audioOn = _settings?.audioOn.value ?? false;
    if (!audioOn) {
      _log.fine(() => 'Ignoring playing sound ($type) because audio is muted.');
      return;
    }
    final soundsOn = _settings?.soundsOn.value ?? false;
    if (!soundsOn) {
      _log.fine(
        () => 'Ignoring playing sound ($type) because sounds are turned off.',
      );
      return;
    }

    final options = soundTypeToFilename(type);
    if (options.isEmpty) {
      // No licensed SFX bundled yet — see lib/audio/sounds.dart.
      _log.fine(
        () => 'Ignoring playing sound ($type) because none is bundled.',
      );
      return;
    }

    _log.fine(() => 'Playing sound: $type');
    final filename = options[_random.nextInt(options.length)];
    _log.fine(() => '- Chosen filename: $filename');

    final currentPlayer = _sfxPlayers[_currentSfxPlayer];
    unawaited(
      currentPlayer.play(
        AssetSource('sfx/$filename'),
        volume: soundTypeToVolume(type),
      ),
    );
    _currentSfxPlayer = (_currentSfxPlayer + 1) % _sfxPlayers.length;
  }

  /// Enables the [AudioController] to listen to [AppLifecycleState] events,
  /// and therefore do things like stopping playback when the game
  /// goes into the background.
  void _attachLifecycleNotifier(AppLifecycleStateNotifier lifecycleNotifier) {
    _lifecycleNotifier?.removeListener(_handleAppLifecycle);

    lifecycleNotifier.addListener(_handleAppLifecycle);
    _lifecycleNotifier = lifecycleNotifier;
  }

  /// Enables the [AudioController] to track changes to settings.
  /// Namely, when any of [SettingsController.audioOn],
  /// [SettingsController.musicOn] or [SettingsController.soundsOn] changes,
  /// the audio controller will act accordingly.
  void _attachSettings(SettingsController settingsController) {
    if (_settings == settingsController) {
      // Already attached to this instance. Nothing to do.
      return;
    }

    // Remove handlers from the old settings controller if present
    final oldSettings = _settings;
    if (oldSettings != null) {
      oldSettings.audioOn.removeListener(_audioOnHandler);
      oldSettings.musicOn.removeListener(_musicOnHandler);
      oldSettings.soundsOn.removeListener(_soundsOnHandler);
    }

    _settings = settingsController;

    // Add handlers to the new settings controller
    settingsController.audioOn.addListener(_audioOnHandler);
    settingsController.musicOn.addListener(_musicOnHandler);
    settingsController.soundsOn.addListener(_soundsOnHandler);

    if (settingsController.audioOn.value && settingsController.musicOn.value) {
      if (kIsWeb) {
        _log.info('On the web, music can only start after user interaction.');
      } else {
        unawaited(_playCurrentSongInPlaylist());
      }
    }
  }

  void _audioOnHandler() {
    _log.fine('audioOn changed to ${_settings!.audioOn.value}');
    if (_settings!.audioOn.value) {
      // All sound just got un-muted. Audio is on.
      if (_settings!.musicOn.value) {
        unawaited(_startOrResumeMusic());
      }
    } else {
      // All sound just got muted. Audio is off.
      _stopAllSound();
    }
  }

  void _handleAppLifecycle() {
    switch (_lifecycleNotifier!.value) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopAllSound();
      case AppLifecycleState.resumed:
        if (_settings!.audioOn.value && _settings!.musicOn.value) {
          unawaited(_startOrResumeMusic());
        }
      case AppLifecycleState.inactive:
        // No need to react to this state change.
        break;
    }
  }

  void _handleSongFinished(void _) {
    _log.info('Last song finished playing.');
    if (_playlist.isEmpty) return;
    // Move the song that just finished playing to the end of the playlist.
    _playlist.addLast(_playlist.removeFirst());
    // Play the song at the beginning of the playlist.
    unawaited(_playCurrentSongInPlaylist());
  }

  void _musicOnHandler() {
    if (_settings!.musicOn.value) {
      // Music got turned on.
      if (_settings!.audioOn.value) {
        unawaited(_startOrResumeMusic());
      }
    } else {
      // Music got turned off.
      unawaited(_musicPlayer.pause());
    }
  }

  Future<void> _playCurrentSongInPlaylist() async {
    if (_playlist.isEmpty) {
      // No licensed music bundled yet — see lib/audio/songs.dart.
      _log.info('Playlist is empty; nothing to play.');
      return;
    }

    _log.info(() => 'Playing ${_playlist.first} now.');
    try {
      await _musicPlayer.play(AssetSource('music/${_playlist.first.filename}'));
    } on Object catch (e) {
      _log.severe('Could not play song ${_playlist.first}', e);
    }
  }

  /// Preloads all sound effects.
  Future<void> _preloadSfx() async {
    _log.info('Preloading sound effects');
    // This assumes there is only a limited number of sound effects in the game.
    // If there are hundreds of long sound effect files, it's better
    // to be more selective when preloading.
    await AudioCache.instance.loadAll(
      SfxType.values
          .expand(soundTypeToFilename)
          .map((path) => 'sfx/$path')
          .toList(),
    );
  }

  void _soundsOnHandler() {
    for (final player in _sfxPlayers) {
      if (player.state == PlayerState.playing) {
        unawaited(player.stop());
      }
    }
  }

  Future<void> _startOrResumeMusic() async {
    if (_musicPlayer.source == null) {
      _log.info(
        'No music source set. '
        'Start playing the current song in playlist.',
      );
      await _playCurrentSongInPlaylist();
      return;
    }

    _log.info('Resuming paused music.');
    try {
      await _musicPlayer.resume();
    } on Object catch (e) {
      // Sometimes, resuming fails with an "Unexpected" error. audioplayers
      // surfaces platform errors that are not necessarily Exceptions, so this
      // deliberately catches Object.
      _log.severe('Error resuming music', e);
      // Try starting the song from scratch.
      await _playCurrentSongInPlaylist();
    }
  }

  void _stopAllSound() {
    _log.info('Stopping all sound');
    unawaited(_musicPlayer.pause());
    for (final player in _sfxPlayers) {
      unawaited(player.stop());
    }
  }
}
