// Builds the JSON word-bank bundle the app ships with (02-CONTENT-PH.md §5).
//
// The bundle is the offline-first fallback: it ships with every build, and the
// server copy is an update rather than a dependency (CLAUDE.md §Hard rules).

import 'dart:convert';

import 'schema.dart';

/// Bundle format version.
///
/// Bumped when the SHAPE changes, not when content does — the loader checks it
/// to refuse a bundle it cannot read, and content updates must not look like
/// format changes.
const int bundleFormatVersion = 1;

/// Builds the bundle map for [rows].
///
/// [contentVersion] identifies this content generation, and is what the app
/// sends as `?since=` when asking the server whether anything is newer.
/// [isPlaceholder] marks a bundle that is NOT authored content, so nothing
/// downstream can mistake scaffolding for the real bank.
///
/// **Throws on empty input** unless [allowEmpty] is set. `content/` holds
/// header-only CSVs until the authoring in 02-CONTENT-PH.md §6 lands, so
/// running the documented bundle command against it produced a valid, empty
/// bundle that silently replaced the shipped bank — leaving the app with
/// nothing to draw from, offline, with no server in the loop to notice. There
/// is no situation in which writing an empty bundle is what someone meant.
Map<String, dynamic> buildBundle(
  List<ContentRow> rows, {
  required String contentVersion,
  bool isPlaceholder = false,
  bool allowEmpty = false,
  String? note,
}) {
  if (rows.isEmpty && !allowEmpty) {
    throw ArgumentError.value(
      rows,
      'rows',
      'refusing to build an empty bundle — it would blank the offline '
          'fallback. Pass allowEmpty only if that is genuinely the intent',
    );
  }

  final byTopic = <String, List<Map<String, dynamic>>>{};
  for (final row in rows) {
    byTopic.putIfAbsent(row.topicId, () => []).add(row.toBundleJson());
  }

  // Sorted so the same input always produces byte-identical output: a bundle
  // that reshuffles on every build makes every diff unreadable.
  final topics = byTopic.keys.toList()..sort();
  for (final topic in topics) {
    byTopic[topic]!.sort(
      (a, b) => (a['word'] as String).compareTo(b['word'] as String),
    );
  }

  return {
    'formatVersion': bundleFormatVersion,
    'contentVersion': contentVersion,
    'isPlaceholder': isPlaceholder,
    'note': ?note,
    'topics': [
      for (final topic in topics)
        {
          'topicId': topic,
          'wordCount': byTopic[topic]!.length,
          'words': byTopic[topic],
        },
    ],
    'totalWords': rows.length,
  };
}

/// Encodes a bundle as indented JSON with a trailing newline.
///
/// Indented rather than minified on purpose: the bundle is committed, so a
/// content change should produce a reviewable diff.
String encodeBundle(Map<String, dynamic> bundle) =>
    '${const JsonEncoder.withIndent('  ').convert(bundle)}\n';
