import 'package:diakooi/engine/models/enums.dart';
import 'package:diakooi/engine/models/player.dart';
import 'package:diakooi/engine/models/round.dart';
import 'package:diakooi/engine/models/settings.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'room.freezed.dart';
part 'room.g.dart';

/// The whole game (§11).
///
/// Deliberately absent, and not to be reintroduced: `Room.code` — there is
/// nothing to join on one device, so it is a v2 concern.
@freezed
abstract class Room with _$Room {
  const factory Room({
    required String id,
    required RoomSettings settings,
    required List<Player> players,

    /// Fixed for the whole game and private to that player (§7a). Null only
    /// before the game starts.
    String? mayorPlayerId,
    String? vibePackId,
    @Default(false) bool vibePinned,
    @Default(RoomStatus.lobby) RoomStatus status,
    @Default(0) int currentRoundIndex,
    @Default(<Round>[]) List<Round> rounds,

    /// Words already used this session. A word cannot repeat within a session
    /// (§13b no-repeat window).
    @Default(<String>[]) List<String> usedWords,

    /// Topic ids in draw order, used to enforce "not more than twice in a row"
    /// (§13b).
    @Default(<String>[]) List<String> topicHistory,
  }) = _Room;

  const Room._();

  factory Room.fromJson(Map<String, dynamic> json) => _$RoomFromJson(json);

  Player? playerById(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Players in seat order, which is the pass order before §6a rotation.
  List<Player> get seated =>
      [...players]..sort((a, b) => a.seatOrder.compareTo(b.seatOrder));

  Round? get currentRound {
    if (rounds.isEmpty) return null;
    for (final round in rounds.reversed) {
      if (round.roundIndex == currentRoundIndex) return round;
    }
    return rounds.last;
  }

  /// Players who have served at least one forfeit, for the early-end
  /// threshold (§8).
  int get playersWhoServedForfeit =>
      players.where((p) => p.forfeitsServed > 0).length;

  /// True when the early-end threshold is set and has been reached (§8).
  bool get earlyEndReached {
    final threshold = settings.earlyEndConsequenceThreshold;
    if (threshold == null) return false;
    return playersWhoServedForfeit >= threshold;
  }

  /// The game is over at the round limit or the early-end threshold (§10).
  /// The host may also end it manually, which is not modelled here.
  bool get isComplete =>
      currentRoundIndex >= settings.totalRounds || earlyEndReached;
}
