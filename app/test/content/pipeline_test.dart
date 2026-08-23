import 'dart:convert';
import 'dart:io';

import 'package:diakooi/engine/engine.dart';
import 'package:test/test.dart';

import '../../tool/content/bundler.dart';
import '../../tool/content/schema.dart';
import '../../tool/content/validator.dart';

/// CSV parsing and bundle generation (02-CONTENT-PH.md §5).
///
/// The bundle is decoded back through the engine's own `WordBankEntry`, so a
/// bundle that passes here is provably loadable by the app rather than merely
/// well-formed JSON.
void main() {
  group('CSV parsing', () {
    const parser = CsvParser();

    test('keeps commas inside quoted clues', () {
      final fields = parser.parseLine(
        'pagkain,Adobo,"toyo at suka, matagal lutuin",b,c,1,national',
      );
      expect(fields, hasLength(7));
      expect(fields[2], 'toyo at suka, matagal lutuin');
      expect(fields[5], '1');
    });

    test('handles an escaped quote', () {
      final fields = parser.parseLine('a,"he said ""hi""",c');
      expect(fields[1], 'he said "hi"');
    });

    test('round-trips through encode', () {
      const original = [
        'pagkain',
        'Adobo',
        'ulam na may toyo, matagal lutuin',
        'may "quote" din',
        'loose',
        '1',
        'national',
      ];
      expect(parser.parseLine(parser.encodeLine(original)), original);
    });

    test('an empty field stays empty rather than vanishing', () {
      expect(parser.parseLine('a,,c'), ['a', '', 'c']);
    });
  });

  group('reading a file', () {
    late Directory temp;

    setUp(() => temp = Directory.systemTemp.createTempSync('diakooi-content'));
    tearDown(() => temp.deleteSync(recursive: true));

    File write(String name, String contents) {
      final file = File('${temp.path}${Platform.pathSeparator}$name')
        ..writeAsStringSync(contents);
      return file;
    }

    test('parses a valid file', () {
      final file = write('pagkain.csv', '''
${csvHeader.join(',')}
pagkain,Adobo,"ulam na may toyo, matagal lutuin",isang ulam with rice,isang pagkain sa bahay,1,national
''');
      final parsed = readCsv(file);
      expect(parsed.isStructurallyValid, isTrue);
      expect(parsed.rows, hasLength(1));
      expect(parsed.rows.single.word, 'Adobo');
      expect(
        parsed.rows.single.lineNumber,
        2,
        reason: 'line numbers are 1-based and count the header',
      );
    });

    test('rejects a wrong header rather than guessing', () {
      final file = write('bad.csv', 'word,clue\nAdobo,something\n');
      final parsed = readCsv(file);
      expect(parsed.isStructurallyValid, isFalse);
      expect(
        parsed.structuralErrors.single,
        contains('header must be exactly'),
      );
      expect(parsed.rows, isEmpty);
    });

    test('reports a row with the wrong column count', () {
      final file = write('short.csv', '''
${csvHeader.join(',')}
pagkain,Adobo,tight,standard
''');
      final parsed = readCsv(file);
      expect(parsed.structuralErrors.single, contains('expected 7 columns'));
    });

    test('ignores blank lines', () {
      final file = write('blanks.csv', '''
${csvHeader.join(',')}

pagkain,Adobo,tight clue,standard clue,loose clue,1,national

''');
      final parsed = readCsv(file);
      expect(parsed.rows, hasLength(1));
    });

    test('an empty file is an error, not silently zero rows', () {
      final parsed = readCsv(write('empty.csv', ''));
      expect(parsed.isStructurallyValid, isFalse);
      expect(parsed.structuralErrors.single, contains('empty'));
    });
  });

  group('bundle generation (§5)', () {
    List<ContentRow> sampleRows() => [
      const ContentRow(
        topicId: 'pagkain',
        word: 'Sisig',
        tight: 'mainit na ulam sa plate, pang-pulutan',
        standard: 'ulam na sikat sa Pampanga',
        loose: 'isang ulam na inihahain',
        difficulty: '2',
        region: 'national',
        lineNumber: 3,
        sourceFile: 'pagkain.csv',
      ),
      const ContentRow(
        topicId: 'pagkain',
        word: 'Adobo',
        tight: 'ulam na may toyo at suka, matagal lutuin',
        standard: 'isang ulam na kinakain with rice',
        loose: 'isang pagkain sa bahay',
        difficulty: '1',
        region: 'national',
        lineNumber: 2,
        sourceFile: 'pagkain.csv',
      ),
      const ContentRow(
        topicId: 'aktor',
        word: 'Vice Ganda',
        tight: 'host ng noontime show, kilala sa pagpapatawa',
        standard: 'isang sikat na TV personality',
        loose: 'isang tao sa showbiz',
        difficulty: '1',
        region: 'national',
        lineNumber: 2,
        sourceFile: 'aktor.csv',
      ),
    ];

    test('groups by topic and counts words', () {
      final bundle = buildBundle(sampleRows(), contentVersion: '2026-08-23');
      expect(bundle['totalWords'], 3);

      final topics = bundle['topics']! as List;
      expect(topics, hasLength(2));
      expect(
        topics.map((t) => (t as Map)['topicId']),
        ['aktor', 'pagkain'],
        reason: 'topics are sorted so the committed bundle diffs cleanly',
      );

      final pagkain =
          topics.firstWhere(
                (t) => (t as Map)['topicId'] == 'pagkain',
              )
              as Map;
      expect(pagkain['wordCount'], 2);
      expect(
        (pagkain['words']! as List).map((w) => (w as Map)['word']),
        ['Adobo', 'Sisig'],
        reason: 'words are sorted within a topic for the same reason',
      );
    });

    test('the same input produces byte-identical output', () {
      final a = encodeBundle(
        buildBundle(sampleRows(), contentVersion: '2026-08-23'),
      );
      final b = encodeBundle(
        buildBundle(
          sampleRows().reversed.toList(),
          contentVersion: '2026-08-23',
        ),
      );
      expect(
        b,
        a,
        reason: 'row order in the CSV must not change the bundle',
      );
    });

    test('carries the format version and the placeholder flag', () {
      final real = buildBundle(sampleRows(), contentVersion: 'v1');
      expect(real['formatVersion'], bundleFormatVersion);
      expect(real['isPlaceholder'], isFalse);

      final placeholder = buildBundle(
        sampleRows(),
        contentVersion: 'v1',
        isPlaceholder: true,
        note: 'scaffolding',
      );
      expect(placeholder['isPlaceholder'], isTrue);
      expect(placeholder['note'], 'scaffolding');
    });

    test('every bundled word decodes through the engine model', () {
      // The point of this test: a bundle that is merely valid JSON is not
      // enough. It has to load through the same WordBankEntry the app uses,
      // or the shipped fallback fails on a device with no server to fall
      // back to.
      final bundle = buildBundle(sampleRows(), contentVersion: 'v1');
      final decoded = jsonDecode(encodeBundle(bundle)) as Map<String, dynamic>;

      var seen = 0;
      for (final topic in decoded['topics']! as List) {
        for (final word in (topic as Map)['words']! as List) {
          final entry = WordBankEntry.fromJson(word as Map<String, dynamic>);
          expect(entry.word, isNotEmpty);
          expect(entry.clues.tight, isNotEmpty);
          expect(entry.clues.standard, isNotEmpty);
          expect(entry.clues.loose, isNotEmpty);
          expect(entry.difficultyRating, inInclusiveRange(1, 5));
          seen++;
        }
      }
      expect(seen, 3);
    });

    test('a bundled entry serves all three tiers (§14)', () {
      final bundle = buildBundle(sampleRows(), contentVersion: 'v1');
      final topics = bundle['topics']! as List;
      final first =
          ((topics.first as Map)['words']! as List).first
              as Map<String, dynamic>;
      final entry = WordBankEntry.fromJson(first);

      expect(entry.clues.forTier(ClueTier.tight), entry.clues.tight);
      expect(entry.clues.forTier(ClueTier.standard), entry.clues.standard);
      expect(entry.clues.forTier(ClueTier.loose), entry.clues.loose);
    });

    test('encoded output is indented and newline-terminated', () {
      final text = encodeBundle(
        buildBundle(sampleRows(), contentVersion: 'v1'),
      );
      expect(text, endsWith('\n'));
      expect(text, contains('\n  "formatVersion"'));
    });

    test('an empty bundle is refused, because it blanks the fallback', () {
      // `content/` is header-only CSVs until the §6 authoring lands, so the
      // documented `bundle` command produced a perfectly valid empty bundle
      // and overwrote the shipped bank with it. The app then has nothing to
      // draw from, offline, with no server in the loop to notice.
      expect(
        () => buildBundle(const [], contentVersion: 'v1'),
        throwsArgumentError,
      );
      expect(
        buildBundle(const [], contentVersion: 'v1', allowEmpty: true),
        containsPair('totalWords', 0),
        reason: 'the escape hatch still exists for a caller that means it',
      );
      expect(
        buildBundle(sampleRows(), contentVersion: 'v1'),
        containsPair('totalWords', greaterThan(0)),
        reason: 'and a real bank is unaffected by the guard',
      );
    });
  });

  group('the committed CSVs and bundle', () {
    test('every content CSV in content/ validates', () {
      final dir = Directory('../content');
      expect(
        dir.existsSync(),
        isTrue,
        reason: 'run from app/; content/ lives at the repo root',
      );

      final rows = <ContentRow>[];
      final structural = <String>[];
      for (final file in dir.listSync().whereType<File>()) {
        if (!file.path.toLowerCase().endsWith('.csv')) continue;
        final parsed = readCsv(file);
        structural.addAll(parsed.structuralErrors);
        rows.addAll(parsed.rows);
      }

      expect(structural, isEmpty, reason: structural.join('\n'));

      final report = validateRows(rows);
      expect(
        report.rejections,
        isEmpty,
        reason: report.rejections.join('\n'),
      );
    });

    test('a placeholder bundle is impossible to mistake for real content', () {
      final file = File('assets/wordbank/wordbank.json');
      final bundle =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      // The bank is the product (02-CONTENT-PH.md). Scaffolding shipping as if
      // it were authored content is the failure this flag exists to prevent,
      // so if the flag is set the bundle must also say why in plain words.
      if (bundle['isPlaceholder'] == true) {
        expect(
          bundle['note'],
          isA<String>().having(
            (n) => n.toUpperCase(),
            'note',
            contains('PLACEHOLDER'),
          ),
          reason: 'a placeholder bundle must carry a note saying so',
        );
      }
    });

    test('the shipped bundle exists, is loadable, and is labelled', () {
      final file = File('assets/wordbank/wordbank.json');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'the app ships a bundled fallback with every build',
      );

      final bundle =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(bundle['formatVersion'], bundleFormatVersion);

      var words = 0;
      for (final topic in bundle['topics']! as List) {
        for (final word in (topic as Map)['words']! as List) {
          WordBankEntry.fromJson(word as Map<String, dynamic>);
          words++;
        }
      }
      expect(words, bundle['totalWords']);
      expect(words, greaterThan(0));
    });
  });
}
