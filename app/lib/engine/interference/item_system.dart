import 'package:diakooi/engine/models/interference.dart';
import 'package:diakooi/engine/models/player.dart';
import 'package:diakooi/engine/rng/seeded_rng.dart';

/// What a second pickup asks the holder to decide (§9d).
///
/// **Silent fizzling is the failure this exists to prevent.** §9d is explicit:
/// an interference roll that appears to do nothing is the worst outcome for a
/// surprise system, so a player who already holds an item is asked to play it
/// or drop it rather than having the new one quietly discarded.
enum ItemPickupOutcome {
  /// They held nothing. The new item is simply theirs.
  taken,

  /// They held something, and now have to choose. Nothing has changed yet.
  mustChoose,
}

/// The prompt a second pickup raises.
class ItemPickup {
  const ItemPickup({
    required this.playerId,
    required this.offeredItemId,
    required this.heldItemId,
    required this.outcome,
  });

  final String playerId;
  final String offeredItemId;

  /// What they are already holding, or null when the slot was empty.
  final String? heldItemId;

  final ItemPickupOutcome outcome;

  bool get needsDecision => outcome == ItemPickupOutcome.mustChoose;
}

/// One item held at a time, use-or-lose on a second pickup (§9d).
///
/// Pure and separately testable. Nothing here decides what an item *does* —
/// that is `resolveRound`, which already implements Shield, Mirror, Veto,
/// Megaphone and Reword. This owns the slot: who holds what, and what happens
/// when a second one arrives.
abstract final class ItemSystem {
  /// Offers [itemId] to a player, without changing anything.
  ///
  /// Returning a decision rather than applying one is deliberate: §9d puts the
  /// choice on the reveal card, in front of the player, and a system that
  /// silently swapped would make that screen a lie.
  static ItemPickup offer({
    required Player player,
    required String itemId,
  }) => ItemPickup(
    playerId: player.id,
    offeredItemId: itemId,
    heldItemId: player.heldItem,
    outcome: player.hasItem
        ? ItemPickupOutcome.mustChoose
        : ItemPickupOutcome.taken,
  );

  /// Takes the offered item, discarding whatever was held.
  ///
  /// Used both for an empty slot and for "drop the old one" after the prompt.
  static Player take({required Player player, required String itemId}) {
    _requireKnownItem(itemId);
    return player.copyWith(heldItem: itemId);
  }

  /// Empties the slot — the item was played, or dropped.
  static Player clear(Player player) => player.copyWith(heldItem: null);

  /// Rerolls a Wild Card into a different item (§9d).
  ///
  /// **Never into another Wild Card.** A wildcard that rerolls into itself is
  /// the same silent nothing §9d rejects, one step removed.
  static String rerollWildCard(GameRng rng) {
    final pool = [
      for (final id in InterferenceCatalogue.itemIds)
        if (id != InterferenceCatalogue.itemWildCard) id,
    ];
    return rng.pick(pool);
  }

  /// The item a player is actually playing, resolving Wild Card first.
  static String resolveOnUse({required String itemId, required GameRng rng}) {
    _requireKnownItem(itemId);
    return itemId == InterferenceCatalogue.itemWildCard
        ? rerollWildCard(rng)
        : itemId;
  }

  /// Whether the table should see a badge next to this player (§9d).
  ///
  /// The badge says someone is holding *something*, never what.
  static bool showsBadge(Player player) => player.hasItem;

  static void _requireKnownItem(String itemId) {
    if (!InterferenceCatalogue.itemIds.contains(itemId)) {
      throw ArgumentError.value(
        itemId,
        'itemId',
        'not an item in the §9d catalogue',
      );
    }
  }
}
