import 'dart:convert';

import 'package:diakooi/engine/engine.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// The bundled word bank (02-CONTENT-PH.md §6).
///
/// **The bundle ships with the app and is never fetched to start a game.** The
/// server copy is an update, not a dependency (CLAUDE.md §Hard rules) — a
/// table in airplane mode plays the same game as one on wifi.
class WordBank {
  const WordBank({
    required this.entries,
    required this.contentVersion,
    required this.isPlaceholder,
  });

  /// Parses the bundle format written by the content pipeline.
  factory WordBank.fromJson(Map<String, dynamic> json) {
    final entries = <WordBankEntry>[];
    for (final topic in json['topics']! as List) {
      for (final word in (topic as Map)['words']! as List) {
        entries.add(WordBankEntry.fromJson(word as Map<String, dynamic>));
      }
    }
    return WordBank(
      entries: entries,
      contentVersion: json['contentVersion'] as String? ?? 'unknown',
      isPlaceholder: json['isPlaceholder'] as bool? ?? false,
    );
  }

  final List<WordBankEntry> entries;
  final String contentVersion;

  /// True while the bundle is machine-generated scaffolding rather than
  /// authored content. Surfaced so nothing can quietly ship on it.
  final bool isPlaceholder;

  /// Topic ids that actually have words, so the host mixer cannot offer a
  /// topic the draw would immediately fail on.
  Set<String> get topicIds => {for (final e in entries) e.topicId};

  int countFor(String topicId) =>
      entries.where((e) => e.topicId == topicId).length;

  static const assetPath = 'assets/wordbank/wordbank.json';

  static Future<WordBank> load({AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString(assetPath);
    return WordBank.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }
}
