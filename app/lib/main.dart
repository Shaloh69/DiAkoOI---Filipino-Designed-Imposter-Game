// Copyright 2022, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// Adapted for DiAkoOi: MultiProvider -> ProviderScope. See lib/providers.dart.

import 'dart:developer' as dev;

import 'package:diakooi/providers.dart';
import 'package:diakooi/router.dart';
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
    final palette = ref.watch(paletteProvider);

    // Read once so music starts immediately rather than on first screen that
    // happens to need audio. Mirrors the template's `lazy: false`.
    ref.watch(audioControllerProvider);

    return MaterialApp.router(
      title: 'DiAkoOi',
      theme:
          ThemeData.from(
            colorScheme: ColorScheme.fromSeed(
              seedColor: palette.darkPen,
              surface: palette.backgroundMain,
            ),
            textTheme: TextTheme(bodyMedium: TextStyle(color: palette.ink)),
          ).copyWith(
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
      routerConfig: router,
    );
  }
}
