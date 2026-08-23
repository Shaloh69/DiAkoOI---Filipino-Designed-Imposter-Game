// Copyright 2022, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// Adapted for DiAkoOi: the template's achievementIdIOS/achievementIdAndroid
// fields were leftovers of the achievements integration described in
// docs/adr/0002-templates.md. Stripped at adoption — DiAkoOi ships no
// achievements and no store-services dependency of any kind.

const gameLevels = [
  GameLevel(number: 1, difficulty: 5),
  GameLevel(number: 2, difficulty: 42),
  GameLevel(number: 3, difficulty: 100),
];

class GameLevel {
  const GameLevel({required this.number, required this.difficulty});

  final int number;

  final int difficulty;
}
