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
///
/// **Why the draw compensates rather than simply excluding.** A naive
/// "exclude the streaking topic and renormalise" loses that topic's share
/// permanently: at 60% it measures about 49% over ten thousand rounds, because
/// every blocked draw is mass the topic never gets back. A1 requires the draw
/// to converge to the host's weights within 2% *and* never violate the window,
/// so the two rules have to be reconciled rather than traded off.
///
/// This draws against each topic's running **deficit** — how far behind its
/// nominal share it currently is — instead of its raw weight. A blocked topic
/// accumulates deficit while it waits and is then strongly favoured once it is
/// eligible again, so the suppressed mass is repaid and the long-run mix
/// matches what the host set. It stays a random draw, and it stays a pure
/// function of the weights and the history, so seeded games stay reproducible.
///
/// The window imposes a hard ceiling of two-in-three, so **any single topic
/// weighted above ~66% cannot be honoured** and will land at the ceiling. That
/// is inherent to the rule, not a defect in this selector. See
/// `docs/adr/0007-topic-draw-deficit-weighting.md`.
abstract final class TopicSelector {
  /// How many consecutive draws of one topic are allowed before it is excluded
  /// from the next draw (§13b).
  static const maxConsecutive = 2;

  /// The highest share any one topic can reach under [maxConsecutive].
  static const double achievableCeiling = maxConsecutive / (maxConsecutive + 1);

  /// Draws the next topic id.
  ///
  /// [topicHistory] is every topic drawn this session, in order. Throws
  /// [StateError] if no topic has a positive weight.
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

    if (pool.length == 1) return pool.first.topicId;

    final drawn = <String, int>{};
    for (final id in topicHistory) {
      drawn[id] = (drawn[id] ?? 0) + 1;
    }
    final drawsSoFar = topicHistory.length;

    // Deficit = share this topic should have had by now, minus what it has.
    // Negative means over-served, so it drops out of contention until the
    // others catch up.
    final deficits = <double>[
      for (final weight in pool)
        (weight.weightPercent / 100) * (drawsSoFar + 1) -
            (drawn[weight.topicId] ?? 0),
    ];

    var total = 0.0;
    for (final deficit in deficits) {
      if (deficit > 0) total += deficit;
    }

    // Everyone is at or ahead of their share — early draws, or a run that has
    // over-served every eligible topic. Fall back to the raw weights.
    if (total <= 0) return _weightedPick(pool, rng);

    var roll = rng.nextDouble() * total;
    for (var i = 0; i < pool.length; i++) {
      final deficit = deficits[i];
      if (deficit <= 0) continue;
      roll -= deficit;
      if (roll < 0) return pool[i].topicId;
    }
    // Floating-point tail on the final positive entry.
    for (var i = pool.length - 1; i >= 0; i--) {
      if (deficits[i] > 0) return pool[i].topicId;
    }
    return pool.last.topicId;
  }

  static String _weightedPick(List<TopicWeight> pool, GameRng rng) {
    final total = pool.fold<int>(0, (sum, w) => sum + w.weightPercent);
    if (total <= 0) return pool.first.topicId;
    var roll = rng.nextDouble() * total;
    for (final weight in pool) {
      roll -= weight.weightPercent;
      if (roll < 0) return weight.topicId;
    }
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
  /// Exposed so tests can assert the window is never violated without reaching
  /// into private state.
  static bool isDrawable(String topicId, List<String> topicHistory) =>
      _blockedTopic(topicHistory) != topicId;
}
