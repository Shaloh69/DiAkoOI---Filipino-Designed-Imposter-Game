import 'package:diakooi/engine/engine.dart' show GameRng, SeededRng;
import 'package:diakooi/theme/vibe_loader.dart';
import 'package:diakooi/theme/vibe_pack.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The pack library, loaded once from the asset bundle.
final vibeLibraryProvider = FutureProvider<VibePackLibrary>((ref) async {
  const loader = VibePackLoader();
  return loader.loadAll();
});

/// Randomness for the pack draw.
///
/// Overridden in tests with a seeded instance so a drawn pack is reproducible;
/// never a global `Random()`.
final vibeRngProvider = Provider<GameRng>(
  (ref) => SeededRng(DateTime.now().microsecondsSinceEpoch),
);

/// The pack pinned by the host, or null to reroll each session (01-DESIGN §2).
///
/// A Notifier rather than the legacy StateProvider: Riverpod 3 moved
/// StateProvider to `legacy.dart`, and new code should not reach for it.
class PinnedVibePackId extends Notifier<String?> {
  @override
  String? build() => null;

  /// Pin [packId] for the session, or pass null to reroll each time.
  ///
  /// A method rather than a setter: a setter would require a matching getter
  /// that only shadows `state`, which reads worse at every call site.
  // ignore: use_setters_to_change_properties
  void pin(String? packId) => state = packId;
}

final pinnedVibePackIdProvider = NotifierProvider<PinnedVibePackId, String?>(
  PinnedVibePackId.new,
);

/// Packs drawn earlier this session, most recent last.
///
/// Used for the §4 no-repeat rule: a pack cannot be drawn twice in a row unless
/// it is the only one enabled.
class VibeHistory extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void record(String packId) => state = [...state, packId];

  void clear() => state = const [];
}

final vibeHistoryProvider = NotifierProvider<VibeHistory, List<String>>(
  VibeHistory.new,
);

/// Draws the session's pack at `VIBE_ROLL` (01-DESIGN §3).
///
/// Returns null while the library is still loading or if it is empty — callers
/// render a neutral shell rather than blocking, because nothing about a game
/// may depend on a network or a slow asset read.
final activeVibePackProvider = Provider<VibePack?>((ref) {
  final library = ref.watch(vibeLibraryProvider).value;
  if (library == null || library.isEmpty) return null;

  final pinned = ref.watch(pinnedVibePackIdProvider);
  if (pinned != null) {
    final pack = library.byId(pinned);
    if (pack != null) return pack;
    // A pinned id that no longer exists (pack removed between builds) falls
    // through to a draw rather than leaving the session themeless.
  }

  final history = ref.watch(vibeHistoryProvider);
  return drawPack(
    packs: library.packs,
    history: history,
    rng: ref.watch(vibeRngProvider),
  );
});

/// Picks a pack, honouring the §4 no-repeat rule.
///
/// Pure and separately testable: a pack cannot repeat consecutively **unless it
/// is the only one available**, in which case repeating beats having no theme.
VibePack drawPack({
  required List<VibePack> packs,
  required List<String> history,
  required GameRng rng,
}) {
  if (packs.isEmpty) {
    throw ArgumentError.value(packs, 'packs', 'cannot draw from an empty set');
  }
  if (packs.length == 1) return packs.first;

  final last = history.isEmpty ? null : history.last;
  final eligible = [
    for (final pack in packs)
      if (pack.id != last) pack,
  ];
  return rng.pick(eligible.isEmpty ? packs : eligible);
}
