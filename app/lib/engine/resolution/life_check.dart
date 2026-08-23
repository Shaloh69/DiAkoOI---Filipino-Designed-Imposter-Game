import 'package:diakooi/engine/models/interference.dart';
import 'package:diakooi/engine/models/player.dart';
import 'package:diakooi/engine/models/round.dart';
import 'package:diakooi/engine/models/settings.dart';

/// A forfeit owed by one player after LIFE_CHECK (§8).
///
/// The forfeit itself is open-ended and self-authored — free text, not a fixed
/// menu — so the engine only tracks that one is owed and how many.
class PendingForfeit {
  const PendingForfeit({required this.playerId, required this.count});

  final String playerId;

  /// Normally 1. High Stakes (§9c) makes forfeits triggered this round come in
  /// pairs, so this is 2 for that round.
  final int count;

  @override
  String toString() => 'PendingForfeit($playerId x$count)';
}

/// Result of applying a round's life deltas (§8).
class LifeCheckResult {
  const LifeCheckResult({
    required this.players,
    required this.pendingForfeits,
  });

  /// Players with lives updated. Anyone who hit 0 is still at 0 here —
  /// restoration happens only once the forfeit is actually served.
  final List<Player> players;

  /// Who owes a forfeit this round, in seat order.
  final List<PendingForfeit> pendingForfeits;

  bool get anyForfeits => pendingForfeits.isNotEmpty;
}

/// Lives and consequences (§8).
abstract final class LifeCheck {
  /// Applies [resolution] to [players] and reports who hit 0.
  ///
  /// Lives persist across rounds and are clamped to `[0, livesPerPlayer]`:
  /// Bonus Life is explicitly "capped at the game max" (§9b), and nothing may
  /// drive a total below 0.
  static LifeCheckResult apply({
    required List<Player> players,
    required RoundResolution resolution,
    required RoomSettings settings,
    String? roundModifier,
  }) {
    // High Stakes: forfeits triggered this round come in pairs (§9c).
    final forfeitCount = roundModifier == InterferenceCatalogue.highStakes
        ? 2
        : 1;

    final updated = <Player>[];
    final pending = <PendingForfeit>[];

    for (final player in players) {
      final delta = resolution.deltaFor(player.id);
      final next = (player.currentLives + delta).clamp(
        0,
        settings.livesPerPlayer,
      );
      updated.add(player.copyWith(currentLives: next));

      // Only a player who has just arrived at 0 owes a forfeit. Someone
      // already sitting at 0 from an earlier round is waiting to serve, not
      // accruing another.
      if (next == 0 && player.currentLives > 0) {
        pending.add(
          PendingForfeit(playerId: player.id, count: forfeitCount),
        );
      }
    }

    return LifeCheckResult(players: updated, pendingForfeits: pending);
  }

  /// Records a served forfeit and restores the player to 1 life (§8).
  ///
  /// Parking players at 0 forever left them nothing to lose and turned the
  /// back half of long games into disengaged people collecting punishments.
  /// Serving clears the debt and puts them one hit from the next.
  ///
  /// **Restoration is a floor, not a per-forfeit reward.** With two forfeits
  /// owed (High Stakes), both are served and the player is restored once,
  /// after the second — which is what [remainingAfterThis] expresses.
  static Player serveForfeit({
    required Player player,
    required int roundIndex,
    required String description,
    DateTime? servedAt,
    int remainingAfterThis = 0,
  }) {
    if (remainingAfterThis < 0) {
      throw ArgumentError.value(
        remainingAfterThis,
        'remainingAfterThis',
        'must not be negative',
      );
    }

    final log = [
      ...player.consequenceLog,
      ConsequenceEntry(
        roundIndex: roundIndex,
        description: description,
        servedAt: servedAt ?? DateTime.now(),
      ),
    ];

    // Restore only once every owed forfeit has been served.
    final lives = remainingAfterThis > 0
        ? player.currentLives
        : (player.currentLives < 1 ? 1 : player.currentLives);

    return player.copyWith(consequenceLog: log, currentLives: lives);
  }

  /// Whether the early-end threshold has been met (§8): N players have each
  /// served at least one forfeit.
  static bool earlyEndReached({
    required List<Player> players,
    required RoomSettings settings,
  }) {
    final threshold = settings.earlyEndConsequenceThreshold;
    if (threshold == null) return false;
    final served = players.where((p) => p.forfeitsServed > 0).length;
    return served >= threshold;
  }
}
