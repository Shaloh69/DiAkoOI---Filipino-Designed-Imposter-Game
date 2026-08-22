import 'dart:math';

/// Randomness for the engine, always injected and never global.
///
/// Every draw in the game — topic, word, imposters, interference rolls — goes
/// through one of these. Determinism is a requirement, not a convenience: A1
/// asserts that the same seed produces byte-identical transcripts across runs,
/// and that only holds if nothing anywhere reaches for `Random()` directly.
abstract interface class GameRng {
  /// Uniform integer in `[0, max)`. Throws if [max] is not positive.
  int nextInt(int max);

  /// Uniform double in `[0, 1)`.
  double nextDouble();

  /// Uniform element of [items]. Throws [ArgumentError] if empty.
  T pick<T>(List<T> items);

  /// A new list containing [items] in random order. Does not mutate [items].
  List<T> shuffled<T>(List<T> items);

  /// [count] distinct elements of [items], in draw order.
  ///
  /// Throws [ArgumentError] if [count] exceeds the list length — silently
  /// returning fewer would let a bad imposter count produce a game with no
  /// imposters, which is exactly the kind of failure that surfaces as a
  /// confusing round rather than an error.
  List<T> sample<T>(List<T> items, int count);
}

/// The production implementation, backed by `dart:math`'s seeded [Random].
final class SeededRng implements GameRng {
  SeededRng(this.seed) : _random = Random(seed);

  /// Convenience for tests that only care that a value is stable.
  SeededRng.zero() : this(0);

  final int seed;
  final Random _random;

  @override
  int nextInt(int max) {
    if (max <= 0) {
      throw ArgumentError.value(max, 'max', 'must be positive');
    }
    return _random.nextInt(max);
  }

  @override
  double nextDouble() => _random.nextDouble();

  @override
  T pick<T>(List<T> items) {
    if (items.isEmpty) {
      throw ArgumentError.value(
        items,
        'items',
        'cannot pick from an empty list',
      );
    }
    return items[nextInt(items.length)];
  }

  @override
  List<T> shuffled<T>(List<T> items) {
    final copy = [...items];
    // Fisher-Yates driven by our own nextInt, so the sequence depends only on
    // the seed and not on the SDK's shuffle implementation.
    for (var i = copy.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = copy[i];
      copy[i] = copy[j];
      copy[j] = tmp;
    }
    return copy;
  }

  @override
  List<T> sample<T>(List<T> items, int count) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'must not be negative');
    }
    if (count > items.length) {
      throw ArgumentError.value(
        count,
        'count',
        'cannot take $count from ${items.length} items',
      );
    }
    return shuffled(items).take(count).toList();
  }
}
