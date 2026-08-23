// Copyright 2022, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:diakooi/audio/audio_controller.dart' show AudioController;

/// Music tracks available to [AudioController].
///
/// Deliberately empty. The template's placeholder tracks were removed at
/// adoption (docs/adr/0002-templates.md); Phase 3 populates music from Vibe
/// Packs under `assets/vibes/`, each with a licence record.
/// See docs/03-VIBE-SYSTEM.md §1 — no record, no ship.
const Set<Song> songs = {};

class Song {
  const Song(this.filename, this.name, {this.artist});

  final String filename;

  final String name;

  final String? artist;

  @override
  String toString() => 'Song<$filename>';
}
