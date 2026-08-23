import 'package:diakooi/engine/models/content.dart';
import 'package:diakooi/engine/models/enums.dart';
import 'package:diakooi/engine/models/interference.dart';
import 'package:diakooi/engine/models/player.dart';
import 'package:diakooi/engine/models/settings.dart';
import 'package:diakooi/engine/rng/seeded_rng.dart';

/// Imposter assignment (§3).
///
/// Rolled fresh every round — a player being imposter in round 3 says nothing
/// about round 4. No interference event may change a role mid-round (§9b
/// consistency rule), so this runs once at `ROUND_START` and is then fixed.
abstract final class ImposterAssigner {
  /// Picks [count] imposters from [players].
  ///
  /// Draws from every player at the table, including those on 0 lives: a
  /// player at 0 is restored to 1 after serving (§8), so there is no
  /// "eliminated" state to exclude.
  static List<String> assign({
    required List<Player> players,
    required int count,
    required GameRng rng,
  }) {
    if (players.isEmpty) {
      throw ArgumentError.value(players, 'players', 'cannot be empty');
    }
    if (count < 1) {
      throw ArgumentError.value(count, 'count', 'must be at least 1');
    }
    if (count >= players.length) {
      throw ArgumentError.value(
        count,
        'count',
        'must leave at least one crew member '
            '(${players.length} players, $count imposters)',
      );
    }
    return rng.sample(players, count).map((p) => p.id).toList();
  }

  /// The imposter count for a round after the Double Imposter modifier (§9c).
  ///
  /// Double Imposter sets the count to `min(base + 1, 4)` **before**
  /// assignment, so the extra imposter receives the vague clue like any other.
  /// At 4 it cannot raise anything, and §9c says it rerolls into a different
  /// event — [isDoubleImposterEligible] is how the caller checks that before
  /// committing to the roll.
  static int countForRound({
    required RoomSettings settings,
    String? roundModifier,
  }) {
    final base = settings.imposterCount;
    if (roundModifier != InterferenceCatalogue.doubleImposter) return base;
    return base + 1 > RoomSettings.maxImposters
        ? RoomSettings.maxImposters
        : base + 1;
  }

  /// Whether Double Imposter can actually do anything this round (§9c).
  ///
  /// False when already at the cap, or when the extra imposter would leave no
  /// crew — rolling it then would be a visible no-op.
  static bool isDoubleImposterEligible(RoomSettings settings) =>
      settings.imposterCount < RoomSettings.maxImposters &&
      settings.imposterCount + 1 < settings.playerCount;
}

/// Word and clue selection (§13b, §14).
abstract final class WordSelector {
  /// Draws a word for [topicId] that has not been used this session.
  ///
  /// Throws [StateError] when the topic is exhausted rather than silently
  /// repeating: a repeated word inside one session is a §13b violation, and a
  /// table notices immediately.
  static WordBankEntry draw({
    required String topicId,
    required List<WordBankEntry> bank,
    required List<String> usedWords,
    required GameRng rng,
  }) {
    final used = usedWords.toSet();
    final available = [
      for (final entry in bank)
        if (entry.topicId == topicId && !used.contains(entry.word)) entry,
    ];
    if (available.isEmpty) {
      throw StateError(
        'no unused words left for topic "$topicId" (§13b no-repeat window)',
      );
    }
    return rng.pick(available);
  }

  /// The clue the imposter receives (§14).
  ///
  /// [settings] supplies the host's tier, already nudged one step tighter in
  /// Large Group Mode because at 12+ there is far more information on the
  /// table. The Reword item (§9d) tightens it one further for the round it is
  /// used in.
  static ({String clue, ClueTier tier}) clueFor({
    required WordBankEntry entry,
    required RoomSettings settings,
    bool rewordUsed = false,
  }) {
    var tier = settings.effectiveClueTier;
    if (rewordUsed) tier = tier.oneTighter;
    return (clue: entry.clues.forTier(tier), tier: tier);
  }
}
