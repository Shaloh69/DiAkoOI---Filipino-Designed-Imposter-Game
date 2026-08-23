// CSV schema and parsing for the word bank (02-CONTENT-PH.md §5).
//
// Deliberately dependency-free and standalone: the plan is explicit that the
// validator is a script, NOT the admin console. Authors must be able to check
// their own CSV before anyone imports anything.

import 'dart:convert';
import 'dart:io';

/// The header row every content CSV must carry, in this order.
const List<String> csvHeader = [
  'topic_id',
  'word',
  'clue_tight',
  'clue_standard',
  'clue_loose',
  'difficulty',
  'region',
];

/// Regions a word may be tagged with (01-DESIGN.md §13c). v1 ships `national`
/// only; the others exist so regional packs land without a migration.
const List<String> validRegions = ['national', 'luzon', 'visayas', 'mindanao'];

/// The twelve launch topics (01-DESIGN.md §13a), in the §1 wave order.
const Map<String, List<String>> topicWaves = {
  'wave1': ['pagkain', 'aktor', 'kpop', 'buhaypinoy', 'teleserye'],
  'wave2': ['opm', 'lugar', 'brands', 'basketball'],
  'wave3': ['internet', 'anime', 'kasaysayan'],
};

List<String> get allTopicIds => [
  ...topicWaves['wave1']!,
  ...topicWaves['wave2']!,
  ...topicWaves['wave3']!,
];

/// One parsed CSV row.
class ContentRow {
  const ContentRow({
    required this.topicId,
    required this.word,
    required this.tight,
    required this.standard,
    required this.loose,
    required this.difficulty,
    required this.region,
    required this.lineNumber,
    required this.sourceFile,
  });

  final String topicId;
  final String word;
  final String tight;
  final String standard;
  final String loose;

  /// Raw text, so a non-numeric value can be reported rather than swallowed.
  final String difficulty;
  final String region;

  /// 1-based line in [sourceFile], so an author can jump straight to it.
  final int lineNumber;
  final String sourceFile;

  List<String> get clues => [tight, standard, loose];

  Map<String, dynamic> toBundleJson() => {
    'topicId': topicId,
    'word': word,
    'clues': {'tight': tight, 'standard': standard, 'loose': loose},
    'difficultyRating': int.tryParse(difficulty.trim()) ?? 3,
    'region': region.trim().isEmpty ? 'national' : region.trim(),
  };
}

/// A CSV parser that understands quoted fields and embedded commas.
///
/// Clues routinely contain commas — "ulam na may toyo at suka, matagal
/// lutuin" — so splitting on commas would silently corrupt the bank. Doubled
/// quotes (`""`) are an escaped quote, per RFC 4180.
class CsvParser {
  const CsvParser();

  /// Splits one CSV line into fields.
  List<String> parseLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(char);
        }
      } else if (char == '"') {
        inQuotes = true;
      } else if (char == ',') {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    fields.add(buffer.toString());
    return fields;
  }

  /// Serialises one field, quoting only when it has to.
  String encodeField(String value) {
    final needsQuotes =
        value.contains(',') || value.contains('"') || value.contains('\n');
    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  String encodeLine(List<String> fields) => fields.map(encodeField).join(',');
}

/// Result of reading a CSV file: rows plus any structural problems.
class ParsedCsv {
  ParsedCsv({required this.rows, required this.structuralErrors});

  final List<ContentRow> rows;

  /// Header or column-count problems, which stop rows being trusted at all.
  final List<String> structuralErrors;

  bool get isStructurallyValid => structuralErrors.isEmpty;
}

/// Reads a content CSV.
ParsedCsv readCsv(File file) {
  const parser = CsvParser();
  final errors = <String>[];
  final rows = <ContentRow>[];
  final name = file.path.split(Platform.pathSeparator).last;

  final lines = const LineSplitter()
      .convert(file.readAsStringSync())
      .where((l) => l.trim().isNotEmpty)
      .toList();

  if (lines.isEmpty) {
    return ParsedCsv(
      rows: const [],
      structuralErrors: ['$name: file is empty'],
    );
  }

  final header = parser.parseLine(lines.first).map((h) => h.trim()).toList();
  if (header.length != csvHeader.length ||
      !List.generate(
        csvHeader.length,
        (i) => header[i] == csvHeader[i],
      ).every((ok) => ok)) {
    errors.add(
      '$name:1: header must be exactly "${csvHeader.join(',')}", '
      'got "${header.join(',')}"',
    );
    return ParsedCsv(rows: const [], structuralErrors: errors);
  }

  for (var i = 1; i < lines.length; i++) {
    final lineNumber = i + 1;
    final fields = parser.parseLine(lines[i]);
    if (fields.length != csvHeader.length) {
      errors.add(
        '$name:$lineNumber: expected ${csvHeader.length} columns, '
        'got ${fields.length}',
      );
      continue;
    }
    rows.add(
      ContentRow(
        topicId: fields[0].trim(),
        word: fields[1].trim(),
        tight: fields[2].trim(),
        standard: fields[3].trim(),
        loose: fields[4].trim(),
        difficulty: fields[5].trim(),
        region: fields[6].trim(),
        lineNumber: lineNumber,
        sourceFile: name,
      ),
    );
  }

  return ParsedCsv(rows: rows, structuralErrors: errors);
}
