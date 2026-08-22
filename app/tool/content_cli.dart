// Word-bank content tooling (02-CONTENT-PH.md §5).
//
// A standalone script, NOT the admin console — authors must be able to check
// their own CSV before anyone imports anything, and CI must be able to reject a
// broken bank without a browser.
//
//   dart run tool/content_cli.dart validate [--dir ../content] [--strict]
//   dart run tool/content_cli.dart bundle   [--dir ../content] [--out assets/wordbank/wordbank.json]
//   dart run tool/content_cli.dart stats    [--dir ../content]
//
// `validate` exits 1 on any rejection. `--strict` also fails on warnings,
// which is what a release build should use.

import 'dart:io';

import 'content/bundler.dart';
import 'content/schema.dart';
import 'content/validator.dart';

const _defaultContentDir = '../content';
const _defaultOut = 'assets/wordbank/wordbank.json';

void main(List<String> args) {
  if (args.isEmpty) {
    _usage();
    exit(2);
  }

  final command = args.first;
  final dir = _option(args, '--dir') ?? _defaultContentDir;
  final strict = args.contains('--strict');

  switch (command) {
    case 'validate':
      exit(_validate(dir, strict: strict));
    case 'bundle':
      exit(
        _bundle(
          dir,
          _option(args, '--out') ?? _defaultOut,
          placeholder: args.contains('--placeholder'),
        ),
      );
    case 'stats':
      exit(_stats(dir));
    default:
      stderr.writeln('Unknown command: $command\n');
      _usage();
      exit(2);
  }
}

void _usage() {
  stdout.writeln('''
DiAkoOi word-bank tooling (docs/02-CONTENT-PH.md §5)

  validate   check every CSV against the §5 rules; exit 1 on any rejection
  bundle     write the JSON bundle the app ships with
  stats      per-topic counts against the 60-word minimum

Options
  --dir <path>   content directory (default: $_defaultContentDir)
  --out <path>   bundle output     (default: $_defaultOut)
  --strict       treat warnings as failures too
  --placeholder  mark the bundle as scaffolding, not authored content
''');
}

String? _option(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

/// Reads every `<topic>.csv` directly inside [dir].
///
/// Subdirectories are skipped deliberately: `content/drafts/` holds
/// machine-generated candidates that no human has reviewed, and bundling those
/// by accident is exactly the failure this separation exists to prevent.
({List<ContentRow> rows, List<String> errors, int files}) _readAll(String dir) {
  final directory = Directory(dir);
  if (!directory.existsSync()) {
    return (
      rows: const [],
      errors: ['content directory not found: $dir'],
      files: 0,
    );
  }

  final rows = <ContentRow>[];
  final errors = <String>[];
  var files = 0;

  final csvFiles =
      directory
          .listSync()
          .whereType<File>()
          .where(
            (f) => f.path.toLowerCase().endsWith('.csv'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in csvFiles) {
    files++;
    final parsed = readCsv(file);
    errors.addAll(parsed.structuralErrors);
    rows.addAll(parsed.rows);
  }

  return (rows: rows, errors: errors, files: files);
}

int _validate(String dir, {required bool strict}) {
  final read = _readAll(dir);
  if (read.errors.isNotEmpty) {
    for (final error in read.errors) {
      stderr.writeln('REJECT $error');
    }
    return 1;
  }
  if (read.files == 0) {
    stderr.writeln('No CSV files found in $dir');
    return 1;
  }

  final report = validateRows(read.rows);

  report.rejections.forEach(stdout.writeln);
  report.warnings.forEach(stdout.writeln);

  stdout.writeln(
    '\n${read.files} file(s), ${report.rowsChecked} row(s): '
    '${report.rejections.length} rejection(s), '
    '${report.warnings.length} warning(s)',
  );

  if (!report.passes) return 1;
  if (strict && report.warnings.isNotEmpty) {
    stderr.writeln('--strict: warnings are failures');
    return 1;
  }
  stdout.writeln('OK');
  return 0;
}

int _bundle(String dir, String out, {bool placeholder = false}) {
  final read = _readAll(dir);
  if (read.errors.isNotEmpty) {
    for (final error in read.errors) {
      stderr.writeln('REJECT $error');
    }
    return 1;
  }

  final report = validateRows(read.rows);
  if (!report.passes) {
    // Never bundle content that would be rejected on import: the bundle is the
    // offline fallback, so a broken entry here reaches a table with no server
    // in the loop to catch it.
    stderr.writeln(
      'Refusing to bundle: ${report.rejections.length} rejection(s)',
    );
    report.rejections.forEach(stderr.writeln);
    return 1;
  }

  final bundle = buildBundle(
    read.rows,
    contentVersion: DateTime.now().toUtc().toIso8601String().split('T').first,
    isPlaceholder: placeholder,
    note: placeholder
        ? 'PLACEHOLDER — machine-generated candidate content, NOT authored and '
              'NOT reviewed. Exists so Phase 4 has something to run. Must be '
              'replaced by the authored bank before release '
              '(docs/02-CONTENT-PH.md §6, §7).'
        : null,
  );

  final file = File(out);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(encodeBundle(bundle));

  final suffix = placeholder ? ' [PLACEHOLDER — not authored content]' : '';
  stdout.writeln(
    'Wrote $out — ${bundle['totalWords']} words across '
    '${(bundle['topics']! as List).length} topic(s)$suffix',
  );
  return 0;
}

int _stats(String dir) {
  final read = _readAll(dir);
  final counts = <String, int>{};
  for (final row in read.rows) {
    counts[row.topicId] = (counts[row.topicId] ?? 0) + 1;
  }

  stdout.writeln('Topic coverage against the 60-word minimum (§1)\n');
  for (final wave in topicWaves.entries) {
    stdout.writeln('  ${wave.key}:');
    for (final topic in wave.value) {
      final count = counts[topic] ?? 0;
      final mark = count >= 60 ? 'ok  ' : 'SHORT';
      stdout.writeln(
        '    $mark ${topic.padRight(12)} ${count.toString().padLeft(3)} / 60',
      );
    }
  }

  final total = read.rows.length;
  stdout.writeln('\n  total: $total / 720 words, ${total * 3} / 2160 clues');
  return 0;
}
