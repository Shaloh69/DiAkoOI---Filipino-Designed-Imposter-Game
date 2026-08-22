// Word-bank validation (02-CONTENT-PH.md §5).
//
// Rejections block an import; warnings do not. That split is the spec's, and
// it matters: a warning that blocked would make authors edit around the tool
// instead of thinking, and a rejection that only warned would let a broken
// word reach a table.

import 'schema.dart';

enum Severity {
  /// Blocks import (§5).
  reject,

  /// Surfaces for judgement but does not block (§5).
  warn,
}

class ValidationIssue {
  const ValidationIssue({
    required this.severity,
    required this.code,
    required this.message,
    required this.file,
    required this.line,
    this.word,
  });

  final Severity severity;

  /// Stable identifier, so tests assert on the failure class rather than on
  /// wording that will be edited.
  final String code;
  final String message;
  final String file;
  final int line;
  final String? word;

  bool get isRejection => severity == Severity.reject;

  @override
  String toString() {
    final tag = severity == Severity.reject ? 'REJECT' : 'warn  ';
    final subject = word == null ? '' : ' [$word]';
    return '$tag $file:$line$subject $code: $message';
  }
}

class ValidationReport {
  ValidationReport(this.issues, {required this.rowsChecked});

  final List<ValidationIssue> issues;
  final int rowsChecked;

  List<ValidationIssue> get rejections =>
      issues.where((i) => i.isRejection).toList();
  List<ValidationIssue> get warnings =>
      issues.where((i) => !i.isRejection).toList();

  bool get passes => rejections.isEmpty;
}

/// Maximum clue length before it becomes hard to read on a reveal card (§5).
const int clueLengthWarnThreshold = 90;

/// Similarity above which tight and standard are flagged as too close (§3).
///
/// If tight and standard read nearly the same, the host's difficulty setting
/// does nothing and their choice is fake.
const double tierSimilarityWarnThreshold = 0.6;

/// Validates rows against §5, plus the §2 authoring rules that can be checked
/// mechanically.
///
/// [synonyms] maps a word to additional forms that also count as giving it
/// away — "Halo-halo" should not be revealed by "haluhalo".
ValidationReport validateRows(
  List<ContentRow> rows, {
  Map<String, List<String>> synonyms = const {},
}) {
  final issues = <ValidationIssue>[];
  final seenPerTopic = <String, Map<String, int>>{};

  for (final row in rows) {
    void add(Severity severity, String code, String message) {
      issues.add(
        ValidationIssue(
          severity: severity,
          code: code,
          message: message,
          file: row.sourceFile,
          line: row.lineNumber,
          word: row.word.isEmpty ? null : row.word,
        ),
      );
    }

    // ── Identity ────────────────────────────────────────────────────────
    if (row.word.isEmpty) {
      add(Severity.reject, 'empty-word', 'word is empty');
    }
    if (row.topicId.isEmpty) {
      add(Severity.reject, 'empty-topic', 'topic_id is empty');
    } else if (!allTopicIds.contains(row.topicId)) {
      add(
        Severity.reject,
        'unknown-topic',
        'topic_id "${row.topicId}" is not one of the 12 launch topics',
      );
    }

    // ── Duplicate word within a topic (§5) ──────────────────────────────
    if (row.word.isNotEmpty && row.topicId.isNotEmpty) {
      final key = row.word.toLowerCase();
      final seen = seenPerTopic.putIfAbsent(row.topicId, () => {});
      final firstLine = seen[key];
      if (firstLine != null) {
        add(
          Severity.reject,
          'duplicate-word',
          'duplicate of the entry on line $firstLine in this topic',
        );
      } else {
        seen[key] = row.lineNumber;
      }
    }

    // ── Clue presence (§5) ──────────────────────────────────────────────
    const tierNames = ['tight', 'standard', 'loose'];
    for (var i = 0; i < row.clues.length; i++) {
      if (row.clues[i].isEmpty) {
        add(
          Severity.reject,
          'empty-clue',
          '${tierNames[i]} clue is empty — all three tiers are required',
        );
      }
    }

    // ── Clue must not contain the word or a synonym (§5, §2 rule 1) ─────
    final forbidden = <String>[
      if (row.word.isNotEmpty) row.word,
      ...?synonyms[row.word],
      ...?synonyms[row.word.toLowerCase()],
    ];
    for (var i = 0; i < row.clues.length; i++) {
      final clue = row.clues[i];
      if (clue.isEmpty) continue;
      for (final term in forbidden) {
        if (term.trim().isEmpty) continue;
        if (containsTerm(clue, term)) {
          add(
            Severity.reject,
            'clue-contains-word',
            '${tierNames[i]} clue contains "$term"',
          );
          break;
        }
      }
    }

    // ── Clue length (§5 — warn, not reject) ─────────────────────────────
    for (var i = 0; i < row.clues.length; i++) {
      final length = row.clues[i].length;
      if (length > clueLengthWarnThreshold) {
        add(
          Severity.warn,
          'clue-too-long',
          '${tierNames[i]} clue is $length characters, over '
              '$clueLengthWarnThreshold — hard to read on the card',
        );
      }
    }

    // ── Tier separation (§3 — warn) ─────────────────────────────────────
    if (row.tight.isNotEmpty && row.standard.isNotEmpty) {
      final similarity = tokenSimilarity(row.tight, row.standard);
      if (similarity > tierSimilarityWarnThreshold) {
        add(
          Severity.warn,
          'tiers-too-similar',
          'tight and standard are ${(similarity * 100).round()}% similar — '
              'the host difficulty setting does nothing if the tiers match',
        );
      }
    }

    // ── Difficulty (§5) ─────────────────────────────────────────────────
    final difficulty = int.tryParse(row.difficulty);
    if (difficulty == null) {
      add(
        Severity.reject,
        'difficulty-not-a-number',
        'difficulty "${row.difficulty}" is not a number',
      );
    } else if (difficulty < 1 || difficulty > 5) {
      add(
        Severity.reject,
        'difficulty-out-of-range',
        'difficulty $difficulty is outside 1-5',
      );
    }

    // ── Region (§2 rule 8, 01-DESIGN §13c) ──────────────────────────────
    if (row.region.isEmpty) {
      add(Severity.reject, 'empty-region', 'region is empty');
    } else if (!validRegions.contains(row.region)) {
      add(
        Severity.reject,
        'unknown-region',
        'region "${row.region}" must be one of ${validRegions.join(', ')}',
      );
    }
  }

  return ValidationReport(issues, rowsChecked: rows.length);
}

/// Whether [text] contains [term] as a word, case- and accent-insensitively.
///
/// Substring matching alone is wrong in both directions: it would miss
/// "Halo-halo" inside "halo halo", and it would falsely flag "Taho" inside
/// "tahong". Normalising separators and then matching on token boundaries
/// handles both.
bool containsTerm(String text, String term) {
  final haystack = _normalise(text);
  final needle = _normalise(term);
  if (needle.isEmpty) return false;

  var index = haystack.indexOf(needle);
  while (index != -1) {
    final beforeOk = index == 0 || haystack[index - 1] == ' ';
    final afterIndex = index + needle.length;
    final afterOk =
        afterIndex >= haystack.length || haystack[afterIndex] == ' ';
    if (beforeOk && afterOk) return true;
    index = haystack.indexOf(needle, index + 1);
  }
  return false;
}

/// Overlap between two clues, as the Jaccard index of their word sets.
///
/// Deliberately not cosine over embeddings: this runs in CI and in an author's
/// terminal with no model available, and the failure it has to catch — two
/// tiers that read almost identically — is a lexical one.
double tokenSimilarity(String a, String b) {
  final left = _tokens(a);
  final right = _tokens(b);
  if (left.isEmpty || right.isEmpty) return 0;
  final intersection = left.intersection(right).length;
  final union = left.union(right).length;
  return union == 0 ? 0 : intersection / union;
}

Set<String> _tokens(String text) =>
    _normalise(text).split(' ').where((t) => t.isNotEmpty).toSet();

String _normalise(String text) {
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    if (RegExp('[a-z0-9à-ÿ]').hasMatch(char)) {
      buffer.write(char);
    } else {
      buffer.write(' ');
    }
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}
