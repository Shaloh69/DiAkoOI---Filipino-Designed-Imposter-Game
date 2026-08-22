// Copyright 2022, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:diakooi/audio/audio_controller.dart' show AudioController;

/// Maps a sound effect to its candidate asset filenames under `assets/sfx/`.
///
/// Every list is empty: the template's placeholder SFX were removed at
/// adoption (docs/adr/0002-templates.md). [AudioController.playSfx] treats an
/// empty list as "nothing to play", so the app runs silently until Phase 3
/// ships licensed audio. The [SfxType] cases are kept so call sites written
/// before then still compile.
List<String> soundTypeToFilename(SfxType type) => switch (type) {
  SfxType.huhsh => const <String>[],
  SfxType.wssh => const <String>[],
  SfxType.buttonTap => const <String>[],
  SfxType.congrats => const <String>[],
  SfxType.erase => const <String>[],
  SfxType.swishSwish => const <String>[],
};

/// Allows control over loudness of different SFX types.
double soundTypeToVolume(SfxType type) {
  switch (type) {
    case SfxType.huhsh:
      return 0.4;
    case SfxType.wssh:
      return 0.2;
    case SfxType.buttonTap:
    case SfxType.congrats:
    case SfxType.erase:
    case SfxType.swishSwish:
      return 1;
  }
}

enum SfxType { huhsh, wssh, buttonTap, congrats, erase, swishSwish }
