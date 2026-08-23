import 'dart:convert';
import 'dart:io';

import 'package:diakooi/theme/vibe_loader.dart';
import 'package:diakooi/theme/vibe_pack.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:flutter/material.dart';

/// Loads packs straight off disk for tests.
///
/// The golden matrix is built from whatever packs exist in `assets/vibes/`, not
/// from a list in Dart. That is what makes "adding a seventh pack requires zero
/// Dart changes" true rather than aspirational — the matrix extends itself.
class DiskVibePackSource implements VibePackSource {
  const DiskVibePackSource({this.root = 'assets/vibes'});

  final String root;

  @override
  Future<List<String>> listPackIds() async {
    final dir = Directory(root);
    if (!dir.existsSync()) return const [];
    final ids = <String>[];
    for (final entity in dir.listSync()) {
      if (entity is! Directory) continue;
      final name = entity.path.split(Platform.pathSeparator).last;
      if (File('$root/$name/theme.json').existsSync()) ids.add(name);
    }
    return ids..sort();
  }

  @override
  Future<String> readPackFile(String packId, String fileName) async =>
      File('$root/$packId/$fileName').readAsStringSync();
}

/// An in-memory source, for the test that proves a new pack needs no Dart.
class InMemoryVibePackSource implements VibePackSource {
  const InMemoryVibePackSource(this.files);

  /// `packId -> { fileName -> contents }`.
  final Map<String, Map<String, String>> files;

  @override
  Future<List<String>> listPackIds() async => files.keys.toList()..sort();

  @override
  Future<String> readPackFile(String packId, String fileName) async {
    final pack = files[packId];
    if (pack == null || !pack.containsKey(fileName)) {
      throw FileSystemException('not found', '$packId/$fileName');
    }
    return pack[fileName]!;
  }
}

/// Every pack in `assets/vibes/`, loaded once.
Future<List<VibePack>> loadAllPacks() async {
  const loader = VibePackLoader(source: DiskVibePackSource());
  final library = await loader.loadAll();
  if (library.failures.isNotEmpty) {
    throw StateError('packs failed to load: ${library.failures}');
  }
  return library.packs;
}

/// Wraps [child] in a pack's theme, sized for a golden.
///
/// Deliberately not a Scaffold: goldens are component-level, not screen-level
/// (06-TESTING-STRATEGY.md §3), and a Scaffold drags in Material chrome that
/// makes the diff unreadable.
Widget themedForGolden(
  VibePack pack,
  Widget child, {
  bool reduceMotion = false,
  double textScale = 1.0,
}) {
  final theme = VibeTheme.materialThemeFor(pack, reduceMotion: reduceMotion);
  return MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reduceMotion,
    ),
    // Alchemist supplies a Directionality inside a golden, but a plain widget
    // test does not — and Stack and Semantics both require one.
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: theme,
        child: ColoredBox(
          color: pack.palette.bg,
          child: Padding(padding: const EdgeInsets.all(12), child: child),
        ),
      ),
    ),
  );
}

/// A minimal valid `theme.json`, for tests that build packs on the fly.
String syntheticThemeJson(String id, {String displayName = 'Synthetic'}) =>
    jsonEncode({
      'id': id,
      'displayName': displayName,
      'palette': {
        'bg': '#101010',
        'surface': '#1B1B1B',
        'surfaceAlt': '#262626',
        'textPrimary': '#F5F5F5',
        'textMuted': '#A0A0A0',
        'crew': '#66E08A',
        'imposter': '#E0A066',
        'interference': '#B98CE0',
        'danger': '#E06666',
      },
      'type': {'display': 'Inter', 'body': 'Inter', 'scaleRatio': 1.25},
      'motion': {
        'profile': 'precise',
        'stiffness': 300.0,
        'damping': 1.0,
        'baseMs': 200,
      },
      'texture': {
        'card': 'flat',
        'grainOpacity': 0.0,
        'crewShape': 'rounded',
        'imposterShape': 'notched',
        'cardRadius': 12.0,
        'gutter': 8.0,
      },
      'watermark': {
        'track': 'Synthetic',
        'artist': 'Nobody',
        'position': 'bottomCenter',
      },
    });

/// A minimal valid `licence.json`.
String syntheticLicenceJson({bool placeholder = true}) => jsonEncode({
  'source': placeholder ? 'PLACEHOLDER' : 'Kenney',
  'type': placeholder ? 'PLACEHOLDER' : 'CC0',
  'url': 'https://example.invalid',
  'attribution': 'none required',
  'isPlaceholder': placeholder,
});
