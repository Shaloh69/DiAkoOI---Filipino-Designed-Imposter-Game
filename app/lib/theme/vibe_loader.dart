import 'dart:convert';

import 'package:diakooi/theme/vibe_pack.dart';
import 'package:flutter/services.dart';

/// Loads Vibe Packs from `assets/vibes/<id>/`.
///
/// Pack ids are **discovered from the asset manifest**, never listed in Dart.
/// That is the whole point of 03-VIBE-SYSTEM.md §2 — adding a pack must not
/// require a code change — and it is what makes the golden matrix extend
/// itself when a seventh pack lands.
abstract interface class VibePackSource {
  /// Every pack id present in the bundle, sorted.
  Future<List<String>> listPackIds();

  /// Raw contents of a file inside a pack directory.
  Future<String> readPackFile(String packId, String fileName);
}

/// Reads packs out of the Flutter asset bundle.
class AssetVibePackSource implements VibePackSource {
  const AssetVibePackSource({this.bundle});

  /// Injected in tests; falls back to [rootBundle] in the app.
  final AssetBundle? bundle;

  AssetBundle get _assets => bundle ?? rootBundle;

  static const _prefix = 'assets/vibes/';

  @override
  Future<List<String>> listPackIds() async {
    // AssetManifest is the only way to enumerate bundled assets at runtime.
    // Listing ids in Dart instead would work today and quietly break the
    // "no Dart change" guarantee the moment someone adds a pack.
    final manifest = await AssetManifest.loadFromAssetBundle(_assets);
    final ids = <String>{};
    for (final asset in manifest.listAssets()) {
      if (!asset.startsWith(_prefix)) continue;
      final rest = asset.substring(_prefix.length);
      final slash = rest.indexOf('/');
      if (slash <= 0) continue;
      ids.add(rest.substring(0, slash));
    }
    return ids.toList()..sort();
  }

  @override
  Future<String> readPackFile(String packId, String fileName) =>
      _assets.loadString('$_prefix$packId/$fileName');
}

/// A pack that failed to load, and why.
class VibePackLoadFailure {
  const VibePackLoadFailure(this.packId, this.reason);

  final String packId;
  final String reason;

  @override
  String toString() => 'VibePackLoadFailure($packId: $reason)';
}

/// The outcome of loading every pack.
class VibePackLibrary {
  const VibePackLibrary({required this.packs, required this.failures});

  final List<VibePack> packs;

  /// Packs that could not be loaded. Surfaced rather than swallowed: a pack
  /// silently missing from the roll is indistinguishable from bad luck.
  final List<VibePackLoadFailure> failures;

  bool get isEmpty => packs.isEmpty;

  VibePack? byId(String id) {
    for (final pack in packs) {
      if (pack.id == id) return pack;
    }
    return null;
  }

  /// Packs whose licence record is complete enough to ship (§1).
  List<VibePack> get shippable => [
    for (final p in packs)
      if (p.licence?.isShippable ?? false) p,
  ];

  /// Packs still carrying a placeholder licence. **Must be empty at release.**
  List<VibePack> get placeholders => [
    for (final p in packs)
      if (!(p.licence?.isShippable ?? false)) p,
  ];
}

/// Reads and parses packs.
class VibePackLoader {
  const VibePackLoader({this.source = const AssetVibePackSource()});

  final VibePackSource source;

  /// Loads every pack in the bundle.
  ///
  /// One malformed pack does not stop the others: a broken `theme.json` should
  /// cost you that pack, not the whole session.
  Future<VibePackLibrary> loadAll() async {
    final ids = await source.listPackIds();
    final packs = <VibePack>[];
    final failures = <VibePackLoadFailure>[];

    for (final id in ids) {
      try {
        packs.add(await load(id));
      } on Object catch (error) {
        failures.add(VibePackLoadFailure(id, error.toString()));
      }
    }

    packs.sort((a, b) => a.id.compareTo(b.id));
    return VibePackLibrary(packs: packs, failures: failures);
  }

  /// Loads one pack: `theme.json` plus its separate `licence.json`.
  Future<VibePack> load(String id) async {
    final themeRaw = await source.readPackFile(id, 'theme.json');
    final themeJson = jsonDecode(themeRaw) as Map<String, dynamic>;

    if (themeJson['id'] != id) {
      throw FormatException(
        'theme.json declares id "${themeJson['id']}" but lives in '
        'assets/vibes/$id/ — the directory name is authoritative',
      );
    }

    var pack = VibePack.fromJson(themeJson);

    // The licence lives in its own file so it can be updated without touching
    // the theme, and so a missing one is loud rather than a default.
    try {
      final licenceRaw = await source.readPackFile(id, 'licence.json');
      final licenceJson = jsonDecode(licenceRaw) as Map<String, dynamic>
        ..remove('_note');
      pack = pack.copyWith(licence: VibeLicence.fromJson(licenceJson));
    } on Object catch (error) {
      throw FormatException(
        'pack "$id" has no readable licence.json — no record, no ship '
        '(03-VIBE-SYSTEM.md §1). $error',
      );
    }

    return pack;
  }
}
