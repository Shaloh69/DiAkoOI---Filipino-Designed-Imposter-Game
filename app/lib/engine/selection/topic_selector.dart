import 'package:diakooi/engine/models/settings.dart';
import 'package:diakooi/engine/rng/seeded_rng.dart';

/// Weighted topic draw with the §13b no-repeat window.
///
/// The host does not pick a topic per round; they set a mix and the app rolls
/// against it. Two constraints sit on top of the raw weights:
///
///   * a word cannot repeat within a session, and
///   * the same topic cannot be drawn more than twice in a row, regardless of
///     weight.
///
/// The second is not a fairness tweak — a 60% weight produces visible streaks
/// that feel broken to a table even though the maths is right.
abstract final class TopicSelector {
  /// How many consecutive draws of one topic are allowed before it is excluded
  /// from the next draw (§13b).
  static const maxConsecutive = 2;

  /// Draws the next topic id.
  ///
  /// [topicHistory] is every topic drawn this session in order; only its tail
  /// matters. Throws [StateError] if no topic has a positive weight.
  static String draw({
    required RoomSettings settings,
    required List<String> topicHistory,
    required GameRng rng,
  }) {
    final eligible = settings.eligibleTopics;
    if (eligible.isEmpty) {
      throw StateError('no topic has a weight above 0 (§13b)');
    }

    final blocked = _blockedTopic(topicHistory);
    var pool = eligible;
    if (blocked != null) {
      final filtered = [
        for (final w in eligible)
          if (w.topicId != blocked) w,
      ];
      // Only apply the streak rule when something else can actually be drawn.
      // With a single eligible topic the alternative is drawing nothing, which
      // would strand the round.
      if (filtered.isNotEmpty) pool = filtered;
    }

    final total = pool.fold<int>(0, (sum, w) => sum + w.weightPercent);
    // Roll once against the pool's own total rather than a fixed 100, so
    // excluding a streaking topic renormalises instead of leaving a dead band
    // that would silently bias toward whichever topic the roll fell through to.
    var roll = rng.nextDouble() * total;
    for (final weight in pool) {
      roll -= weight.weightPercent;
      if (roll < 0) return weight.topicId;
    }
    // Floating-point tail: the accumulated subtraction can leave a vanishing
    // positive remainder on the final entry.
    return pool.last.topicId;
  }

  /// The topic that has just been drawn [maxConsecutive] times in a row, or
  /// null if there is no such streak.
  static String? _blockedTopic(List<String> topicHistory) {
    if (topicHistory.length < maxConsecutive) return null;
    final tail = topicHistory.sublist(topicHistory.length - maxConsecutive);
    final first = tail.first;
    for (final id in tail) {
      if (id != first) return null;
    }
    return first;
  }

  /// Whether [topicId] may legally be drawn next given [topicHistory].
  ///
  /// Exposed so tests can assert the window is never violated without
  /// reaching into private state.
  static bool isDrawable(String topicId, List<String> topicHistory) =>
      _blockedTopic(topicHistory) != topicId;
}
