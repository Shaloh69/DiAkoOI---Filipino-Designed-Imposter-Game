import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A1: `lib/engine/` has no `package:flutter` import.
///
/// This is a hard rule (CLAUDE.md), and the kind that erodes quietly — one
/// `Color` or `Duration` import at a time — unless something fails the build.
/// The engine must stay runnable without a Flutter binding so the resolution
/// logic can move server-side unchanged in v2.
void main() {
  test('lib/engine contains no Flutter import', () {
    final engineDir = Directory('lib/engine');
    expect(
      engineDir.existsSync(),
      isTrue,
      reason: 'lib/engine must exist; run from the app/ directory',
    );

    final offenders = <String>[];
    var scanned = 0;

    for (final entity in engineDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      scanned++;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final isImport =
            line.trimLeft().startsWith('import ') ||
            line.trimLeft().startsWith('export ');
        if (!isImport) continue;
        if (line.contains('package:flutter/') ||
            line.contains('package:flutter_test/') ||
            line.contains('package:flutter_riverpod/')) {
          offenders.add('${entity.path}:${i + 1}: $line');
        }
      }
    }

    expect(
      scanned,
      greaterThan(0),
      reason: 'no Dart files scanned — the check would pass vacuously',
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'lib/engine/ must be pure Dart (CLAUDE.md §Hard rules). Found:\n'
          '${offenders.join('\n')}',
    );
  });
}
