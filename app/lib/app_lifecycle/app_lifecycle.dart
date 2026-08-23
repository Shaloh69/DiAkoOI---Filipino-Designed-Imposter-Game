// Copyright 2022, the Flutter project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// Adapted for DiAkoOi: provider -> flutter_riverpod. The template wrapped the
// notifier in an InheritedProvider via an AppLifecycleObserver widget; a
// Riverpod Provider owns the AppLifecycleListener directly, so there is no
// observer widget to forget to mount.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

typedef AppLifecycleStateNotifier = ValueNotifier<AppLifecycleState>;

final _log = Logger('AppLifecycle');

/// Exposes app lifecycle changes as a [ValueNotifier].
///
/// Consumers attach listeners rather than rebuilding: we care about the
/// _events_ (stop audio on background, resume on focus), not the state itself.
final appLifecycleStateNotifierProvider = Provider<AppLifecycleStateNotifier>((
  ref,
) {
  final notifier = AppLifecycleStateNotifier(AppLifecycleState.inactive);
  final listener = AppLifecycleListener(
    onStateChange: (state) => notifier.value = state,
  );
  _log.info('Subscribed to app lifecycle updates');

  ref.onDispose(() {
    listener.dispose();
    notifier.dispose();
  });

  return notifier;
});
