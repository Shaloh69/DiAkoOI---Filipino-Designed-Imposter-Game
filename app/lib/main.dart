// Copyright 2022, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// Adapted for DiAkoOi: MultiProvider -> ProviderScope. See lib/providers.dart.

import 'dart:developer' as dev;

import 'package:diakooi/providers.dart';
import 'package:diakooi/ui/screens/game_shell.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

Future<void> main() async {
  // Basic logging setup.
  Logger.root.level = kDebugMode ? Level.FINE : Level.INFO;
  Logger.root.onRecord.listen((record) {
    dev.log(
      record.message,
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
    );
  });

  WidgetsFlutterBinding.ensureInitialized();
  // Put game into full screen mode on mobile devices.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // The phone is passed hand to hand, so portrait is the only sane orientation.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read once so music starts immediately rather than on the first screen
    // that happens to need audio.
    ref.watch(audioControllerProvider);

    // **No router.** A pass-and-play game is one device following one state
    // machine; a navigation stack would let a back gesture return to a screen
    // showing a word the table has already moved past. GameShell renders the
    // §3 phase and nothing else.
    //
    // The theme is deliberately not set here either: every colour comes from
    // the active Vibe Pack, and GameShell installs it once the pack is drawn.
    return const MaterialApp(
      title: 'DiAkoOi',
      home: GameShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}
