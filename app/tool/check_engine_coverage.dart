// Fails the build if engine line coverage drops below the A1 threshold.
//
// A1 requires >= 90% line coverage on lib/engine/. Measuring it once during
// Phase 1 proves nothing about Phase 6, so it is enforced on every run instead.
//
// Generated freezed/json_serializable output is excluded: it is not
// hand-written logic, it is regenerated on every build, and including it would
// let real gaps hide behind thousands of generated lines.
//
//   dart run tool/check_engine_coverage.dart [--min 90]

import 'dart:io';

const _defaultMinimum = 90.0;

void main(List<String> args) {
  final minimum = _parseMinimum(args);

  final lcov = File('coverage/lcov.info');
  if (!lcov.existsSync()) {
    stderr.writeln(
      'coverage/lcov.info not found. Run `flutter test --coverage` first.',
    );
    exit(2);
  }

  String? current;
  var found = 0;
  var hit = 0;
  final perFile = <String, ({int found, int hit})>{};
  var fileFound = 0;
  var fileHit = 0;

  for (final line in lcov.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3).replaceAll(r'\', '/');
      fileFound = 0;
      fileHit = 0;
    } else if (line.startsWith('DA:')) {
      final parts = line.substring(3).split(',');
      if (parts.length < 2) continue;
      fileFound++;
      if ((int.tryParse(parts[1]) ?? 0) > 0) fileHit++;
    } else if (line == 'end_of_record' && current != null) {
      perFile[current] = (found: fileFound, hit: fileHit);
      current = null;
    }
  }

  final engine = <String, ({int found, int hit})>{};
  for (final entry in perFile.entries) {
    final path = entry.key;
    if (!path.contains('lib/engine/')) continue;
    if (path.endsWith('.freezed.dart') || path.endsWith('.g.dart')) continue;
    engine[path] = entry.value;
    found += entry.value.found;
    hit += entry.value.hit;
  }

  if (engine.isEmpty) {
    stderr.writeln(
      'No lib/engine/ entries in coverage/lcov.info — the gate would pass '
      'without measuring anything.',
    );
    exit(2);
  }

  final sorted = engine.keys.toList()..sort();
  for (final path in sorted) {
    final stats = engine[path]!;
    final pct = stats.found == 0 ? 100.0 : stats.hit / stats.found * 100;
    stdout.writeln(
      '  ${pct.toStringAsFixed(1).padLeft(5)}%  '
      '${'${stats.hit}/${stats.found}'.padLeft(8)}  '
      '${path.substring(path.indexOf('lib/'))}',
    );
  }

  final total = hit / found * 100;
  stdout.writeln(
    '\nEngine line coverage: ${total.toStringAsFixed(2)}% '
    '($hit/$found lines), minimum ${minimum.toStringAsFixed(0)}%',
  );

  if (total < minimum) {
    stderr.writeln(
      'FAIL: engine coverage ${total.toStringAsFixed(2)}% is below the A1 '
      'minimum of ${minimum.toStringAsFixed(0)}%.',
    );
    exit(1);
  }
  stdout.writeln('OK');
}

double _parseMinimum(List<String> args) {
  final index = args.indexOf('--min');
  if (index == -1 || index + 1 >= args.length) return _defaultMinimum;
  return double.tryParse(args[index + 1]) ?? _defaultMinimum;
}
