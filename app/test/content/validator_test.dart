import 'package:test/test.dart';

import '../../tool/content/schema.dart';
import '../../tool/content/validator.dart';

/// A2: "Validator rejects every failure class in 02-CONTENT-PH.md §5 (test
/// each)."
///
/// The word bank is the product, and this validator is the only thing standing
/// between a typo and a table. Each failure class gets its own test, asserted
/// on the stable issue `code` rather than on wording.
void main() {
  ContentRow row({
    String topicId = 'pagkain',
    String word = 'Adobo',
    String tight = 'ulam na may toyo at suka, matagal lutuin',
    String standard = 'isang ulam na kinakain with rice',
    String loose = 'isang pagkain sa bahay',
    String difficulty = '1',
    String region = 'national',
    int line = 2,
  }) => ContentRow(
    topicId: topicId,
    word: word,
    tight: tight,
    standard: standard,
    loose: loose,
    difficulty: difficulty,
    region: region,
    lineNumber: line,
    sourceFile: 'pagkain.csv',
  );

  Set<String> codesFor(
    List<ContentRow> rows, {
    Map<String, List<String>> synonyms = const {},
  }) =>
      validateRows(rows, synonyms: synonyms).issues.map((i) => i.code).toSet();

  group('a well-formed row passes', () {
    test('no rejections and no warnings', () {
      final report = validateRows([row()]);
      expect(report.passes, isTrue);
      expect(report.rejections, isEmpty);
      expect(report.warnings, isEmpty);
      expect(report.rowsChecked, 1);
    });
  });

  group('§5 rejections — each failure class', () {
    test('clue contains the word', () {
      final codes = codesFor([
        row(tight: 'ang Adobo ay may toyo at suka'),
      ]);
      expect(codes, contains('clue-contains-word'));
    });

    test('clue contains a listed synonym', () {
      final codes = codesFor(
        [row(word: 'Halo-halo', tight: 'malamig na haluhalo sa tag-init')],
        synonyms: {
          'Halo-halo': ['haluhalo'],
        },
      );
      expect(codes, contains('clue-contains-word'));
    });

    test('the word is matched case-insensitively and across separators', () {
      expect(containsTerm('ang ADOBO ay masarap', 'Adobo'), isTrue);
      expect(containsTerm('gusto ko ng halo halo', 'Halo-halo'), isTrue);
    });

    test('a longer word merely containing the answer is NOT flagged', () {
      // "Taho" inside "tahong" is a different word. Substring matching would
      // reject a perfectly good clue here.
      expect(containsTerm('binebenta ang tahong sa palengke', 'Taho'), isFalse);
      final report = validateRows([
        row(word: 'Taho', tight: 'binebenta ng naglalakad tuwing umaga'),
      ]);
      expect(report.passes, isTrue);
    });

    test('an empty clue in any tier', () {
      expect(codesFor([row(tight: '')]), contains('empty-clue'));
      expect(codesFor([row(standard: '')]), contains('empty-clue'));
      expect(codesFor([row(loose: '')]), contains('empty-clue'));
    });

    test('an empty word', () {
      expect(codesFor([row(word: '')]), contains('empty-word'));
    });

    test('a duplicate word within a topic', () {
      final codes = codesFor([
        row(),
        row(line: 3),
      ]);
      expect(codes, contains('duplicate-word'));
    });

    test('the same word in DIFFERENT topics is allowed', () {
      final report = validateRows([
        row(word: 'Halo-halo'),
        row(
          topicId: 'brands',
          word: 'Halo-halo',
          tight: 'isang produkto na binebenta sa tindahan',
          standard: 'isang bagay na may logo',
          loose: 'isang bagay na binibili',
          line: 3,
        ),
      ]);
      expect(
        report.rejections.map((i) => i.code),
        isNot(contains('duplicate-word')),
      );
    });

    test('duplicates are detected case-insensitively', () {
      final codes = codesFor([
        row(),
        row(word: 'adobo', line: 3),
      ]);
      expect(codes, contains('duplicate-word'));
    });

    test('difficulty outside 1-5', () {
      expect(
        codesFor([row(difficulty: '0')]),
        contains('difficulty-out-of-range'),
      );
      expect(
        codesFor([row(difficulty: '6')]),
        contains('difficulty-out-of-range'),
      );
      expect(
        codesFor([row(difficulty: '-1')]),
        contains('difficulty-out-of-range'),
      );
    });

    test('difficulty that is not a number', () {
      expect(
        codesFor([row(difficulty: 'easy')]),
        contains('difficulty-not-a-number'),
      );
      expect(
        codesFor([row(difficulty: '')]),
        contains('difficulty-not-a-number'),
      );
    });

    test('an unknown topic id', () {
      expect(codesFor([row(topicId: 'notatopic')]), contains('unknown-topic'));
    });

    test('an empty topic id', () {
      expect(codesFor([row(topicId: '')]), contains('empty-topic'));
    });

    test('an unknown or empty region', () {
      expect(codesFor([row(region: 'atlantis')]), contains('unknown-region'));
      expect(codesFor([row(region: '')]), contains('empty-region'));
    });

    test('the four non-national regions are accepted (§13c)', () {
      for (final region in validRegions) {
        final report = validateRows([row(region: region)]);
        expect(
          report.passes,
          isTrue,
          reason: '$region should be valid so regional packs need no migration',
        );
      }
    });
  });

  group('§5 warnings — surfaced but not blocking', () {
    test('a clue over 90 characters warns and does not reject', () {
      final long = 'a' * 95;
      final report = validateRows([row(loose: long)]);
      expect(report.warnings.map((i) => i.code), contains('clue-too-long'));
      expect(
        report.passes,
        isTrue,
        reason: 'length is a warning in §5, not a rejection',
      );
    });

    test('tight and standard reading almost the same warns (§3)', () {
      final report = validateRows([
        row(
          tight: 'isang ulam na kinakain with rice',
          standard: 'isang ulam na kinakain with rice araw-araw',
        ),
      ]);
      expect(report.warnings.map((i) => i.code), contains('tiers-too-similar'));
      expect(report.passes, isTrue);
    });

    test('well-separated tiers do not warn', () {
      final report = validateRows([row()]);
      expect(report.warnings, isEmpty);
    });

    test('similarity is symmetric and bounded', () {
      expect(tokenSimilarity('a b c', 'a b c'), 1.0);
      expect(tokenSimilarity('a b c', 'd e f'), 0.0);
      expect(
        tokenSimilarity('mainit na ulam', 'ulam na mainit'),
        tokenSimilarity('ulam na mainit', 'mainit na ulam'),
      );
      expect(tokenSimilarity('', 'anything'), 0.0);
    });
  });

  group('report shape', () {
    test('an issue points at the file and line an author can jump to', () {
      final report = validateRows([row(word: '', line: 17)]);
      final issue = report.rejections.first;
      expect(issue.file, 'pagkain.csv');
      expect(issue.line, 17);
      expect(issue.toString(), contains('REJECT'));
      expect(issue.toString(), contains('pagkain.csv:17'));
    });

    test('a warning renders distinctly from a rejection', () {
      final report = validateRows([row(loose: 'a' * 95)]);
      expect(report.warnings.single.toString(), contains('warn'));
      expect(report.warnings.single.toString(), isNot(contains('REJECT')));
    });

    test(
      'several failures on one row are all reported, not just the first',
      () {
        final report = validateRows([
          row(word: '', difficulty: '9', region: 'nowhere', tight: ''),
        ]);
        final codes = report.rejections.map((i) => i.code).toSet();
        expect(
          codes,
          containsAll(<String>[
            'empty-word',
            'difficulty-out-of-range',
            'unknown-region',
            'empty-clue',
          ]),
        );
      },
    );
  });
}
