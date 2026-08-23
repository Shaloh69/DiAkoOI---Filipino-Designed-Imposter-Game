import 'package:diakooi/engine/models/settings.dart';
import 'package:diakooi/engine/selection/topic_selector.dart';

/// The host's topic mix while they are editing it (§13b).
///
/// Weights must total exactly 100 and no single weight may exceed what the
/// no-repeat window can actually deliver. Both rules live here rather than in
/// the mixer widget: they are game rules, and a widget callback is the wrong
/// place for one (CLAUDE.md §Hard rules).
///
/// **The ceiling is derived, never hardcoded.** After
/// [TopicSelector.maxConsecutive] draws in a row a topic must yield, so it can
/// never exceed `C / (C + 1)` of all draws. That number moves if the window
/// moves, and it moves again when a host disables topics — with one topic left
/// there is nothing else to draw and the ceiling is 100%. A constant would be
/// silently wrong in both cases (proposal 0001, accepted).
class TopicMix {
  const TopicMix(this.weights);

  factory TopicMix.fromPreset(
    List<TopicWeight> preset, {
    required List<String> allTopicIds,
  }) {
    final byId = {for (final w in preset) w.topicId: w.weightPercent};
    return TopicMix([
      for (final id in allTopicIds)
        TopicWeight(topicId: id, weightPercent: byId[id] ?? 0),
    ]);
  }

  /// Every topic offered to the host, in display order, including those at 0.
  ///
  /// A topic at 0 is **excluded from the draw entirely** (§13b), not merely
  /// unlikely, which is why the mixer shows it as off rather than as a slider
  /// resting on the floor.
  final List<TopicWeight> weights;

  int weightOf(String topicId) {
    for (final w in weights) {
      if (w.topicId == topicId) return w.weightPercent;
    }
    return 0;
  }

  bool isEnabled(String topicId) => weightOf(topicId) > 0;

  List<String> get enabledIds => [
    for (final w in weights)
      if (w.weightPercent > 0) w.topicId,
  ];

  int get enabledCount => enabledIds.length;

  int get total => weights.fold(0, (sum, w) => sum + w.weightPercent);

  /// The highest weight the engine can honour, given how many topics are in.
  int get ceilingPercent => TopicSelector.ceilingPercentFor(enabledCount);

  /// The lowest a slider may go without forcing another topic over the
  /// ceiling.
  ///
  /// Whatever this topic gives up lands on the others, and each of those is
  /// capped too — so with two topics in the mix neither can drop below 34
  /// without pushing the other past what the draw delivers. Turning a topic
  /// **off** is still allowed at any time; that removes it from the draw
  /// rather than starving it, which is a different thing.
  int get floorPercent {
    if (enabledCount <= 1) return 100;
    final headroom = (enabledCount - 1) * ceilingPercent;
    return headroom >= 100 ? 0 : 100 - headroom;
  }

  /// Every weight deliverable, and the total exactly 100.
  bool get isValid =>
      total == 100 &&
      enabledCount > 0 &&
      weights.every((w) => w.weightPercent <= ceilingPercent);

  /// Sets one topic's weight, clamped and with the rest rebalanced to 100.
  ///
  /// The clamp is what proposal 0001 chose over a warning: a host mid-lobby
  /// with people waiting does not read explanatory text, and a UI that accepts
  /// a setting it cannot honour is worse than one that stops. A slider that
  /// stops says so without words.
  TopicMix withWeight(String topicId, int requested) {
    if (!isEnabled(topicId)) return this;
    if (enabledCount <= 1) return this; // the only topic in the draw is 100%.

    final target = requested.clamp(floorPercent, ceilingPercent);
    final others = [
      for (final w in weights)
        if (w.topicId != topicId && w.weightPercent > 0) w,
    ];

    final shares = _allocate(
      shares: [for (final w in others) w.weightPercent.toDouble()],
      total: 100 - target,
      cap: ceilingPercent,
    );

    var i = 0;
    return TopicMix([
      for (final w in weights)
        if (w.topicId == topicId)
          w.copyWith(weightPercent: target)
        else if (w.weightPercent > 0)
          w.copyWith(weightPercent: shares[i++])
        else
          w,
    ]);
  }

  /// Adds a topic to the draw or removes it, rebalancing to 100.
  ///
  /// Turning the last topic off is refused — a draw with nothing in it has no
  /// answer, and §13b would rather the host be stopped than handed an empty
  /// game.
  TopicMix toggle(String topicId, {required bool enabled}) {
    if (enabled == isEnabled(topicId)) return this;
    if (!enabled && enabledCount <= 1) return this;

    final nextEnabled = <String>[
      for (final w in weights)
        if (w.topicId == topicId ? enabled : w.weightPercent > 0) w.topicId,
    ];
    final cap = TopicSelector.ceilingPercentFor(nextEnabled.length);

    // Coming in, a topic starts from an even share; going out, its mass is
    // spread over whatever is left in proportion to what those already had.
    final shares = <double>[
      for (final id in nextEnabled)
        if (id == topicId && enabled)
          100 / nextEnabled.length
        else
          weightOf(id).toDouble(),
    ];
    final allocated = _allocate(shares: shares, total: 100, cap: cap);

    final byId = {
      for (var i = 0; i < nextEnabled.length; i++) nextEnabled[i]: allocated[i],
    };
    return TopicMix([
      for (final w in weights) w.copyWith(weightPercent: byId[w.topicId] ?? 0),
    ]);
  }

  List<TopicWeight> toWeights() => [
    for (final w in weights)
      if (w.weightPercent > 0) w,
  ];

  /// Hands out [total] whole points in proportion to [shares], never giving any
  /// one more than [cap].
  ///
  /// Point by point rather than proportion-then-round: rounding first and
  /// capping after can leave the total off by a point or push a topic over the
  /// ceiling, and both of those are visible to a host who can see the numbers
  /// add up to 99.
  static List<int> _allocate({
    required List<double> shares,
    required int total,
    required int cap,
  }) {
    final n = shares.length;
    final result = List.filled(n, 0);
    if (n == 0 || total <= 0) return result;

    final sum = shares.fold<double>(0, (s, v) => s + v);
    final fractions = sum > 0
        ? [for (final s in shares) s / sum]
        : List.filled(n, 1 / n);

    for (var point = 0; point < total; point++) {
      var best = -1;
      var bestDeficit = double.negativeInfinity;
      for (var i = 0; i < n; i++) {
        if (result[i] >= cap) continue;
        final deficit = fractions[i] * total - result[i];
        if (deficit > bestDeficit) {
          bestDeficit = deficit;
          best = i;
        }
      }
      // Everything is at the cap. Only reachable if the caller asked for more
      // than the caps allow, which floorPercent exists to prevent.
      if (best == -1) break;
      result[best]++;
    }
    return result;
  }
}
