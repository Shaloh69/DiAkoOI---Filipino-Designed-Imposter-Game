/// Turn order rotation (§6a).
///
/// Speaking last is a structural advantage — you have heard everything and can
/// echo consensus, which is exactly what an imposter wants. Two rotations
/// remove it, and both are required:
///
///   * the **starting seat rotates every round**, and
///   * **each lap within a round shifts by one**, so the same player does not
///     close both laps.
abstract final class TurnOrder {
  /// Starting seat for a round: `roundIndex % playerCount` (§6a).
  static int startingIndex({
    required int roundIndex,
    required int playerCount,
  }) {
    _requirePositive(playerCount);
    return roundIndex % playerCount;
  }

  /// Starting seat for one lap within a round.
  ///
  /// The per-lap shift is what stops the same seat closing every lap of a
  /// round; without it only the per-round rotation applies and the last
  /// speaker is fixed for the whole round.
  static int lapStartingIndex({
    required int roundIndex,
    required int lapIndex,
    required int playerCount,
  }) {
    _requirePositive(playerCount);
    return (roundIndex + lapIndex) % playerCount;
  }

  /// Seat indices in speaking order for one lap.
  ///
  /// [reversed] inverts the direction for the Reverse Order modifier (§9c),
  /// which explicitly inverts the §6a rotation.
  static List<int> lapOrder({
    required int roundIndex,
    required int lapIndex,
    required int playerCount,
    bool reversed = false,
  }) {
    _requirePositive(playerCount);
    final start = lapStartingIndex(
      roundIndex: roundIndex,
      lapIndex: lapIndex,
      playerCount: playerCount,
    );
    final step = reversed ? -1 : 1;
    return [
      for (var i = 0; i < playerCount; i++) (start + (step * i)) % playerCount,
    ].map((i) => i < 0 ? i + playerCount : i).toList();
  }

  /// The seat that speaks last in a lap — the position the rotation exists to
  /// share out.
  static int lastSpeakerIndex({
    required int roundIndex,
    required int lapIndex,
    required int playerCount,
    bool reversed = false,
  }) => lapOrder(
    roundIndex: roundIndex,
    lapIndex: lapIndex,
    playerCount: playerCount,
    reversed: reversed,
  ).last;

  static void _requirePositive(int playerCount) {
    if (playerCount <= 0) {
      throw ArgumentError.value(
        playerCount,
        'playerCount',
        'must be positive',
      );
    }
  }
}
