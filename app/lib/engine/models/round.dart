import 'package:diakooi/engine/models/enums.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'round.freezed.dart';
part 'round.g.dart';

/// One recorded accusation (§7). The host records caller then accused, which
/// is why two-tap is required rather than preferred: accuser-pays, Spread the
/// Blame and Near-Unanimous are all impossible without knowing who accused
/// whom.
///
/// [tallyWeight] affects the **tally only, never damage** (§7). A Double Vote
/// or Megaphone player backing a wrong target still loses exactly 1 life.
@freezed
abstract class Vote with _$Vote {
  const factory Vote({
    required String voterId,
    required String accusedId,
    @Default(1) int tallyWeight,
  }) = _Vote;

  factory Vote.fromJson(Map<String, dynamic> json) => _$VoteFromJson(json);
}

/// An item played during the round (§9d). Role-dependent effects resolve
/// against [roleAtUse] — the holder's role in the round they use it, not the
/// round they picked it up.
@freezed
abstract class ItemUsage with _$ItemUsage {
  const factory ItemUsage({
    required String playerId,
    required String itemId,
    required PlayerRole roleAtUse,
    required ItemUsePhase phase,
    String? targetPlayerId,
  }) = _ItemUsage;

  factory ItemUsage.fromJson(Map<String, dynamic> json) =>
      _$ItemUsageFromJson(json);
}

/// An interference event that landed on one player during word distribution
/// (§9b). [payload] carries event-specific data, e.g. Taboo's banned words.
@freezed
abstract class PlayerPickEvent with _$PlayerPickEvent {
  const factory PlayerPickEvent({
    required String playerId,
    required String eventId,
    @Default(<String>[]) List<String> payload,
  }) = _PlayerPickEvent;

  factory PlayerPickEvent.fromJson(Map<String, dynamic> json) =>
      _$PlayerPickEventFromJson(json);
}

/// One player's life change for the round, with the reasons why.
///
/// [sources] exists so the round recap can explain itself and so tests assert
/// on cause rather than only magnitude.
@freezed
abstract class LifeDelta with _$LifeDelta {
  const factory LifeDelta({
    required String playerId,
    required int delta,
    @Default(<LifeChangeSource>[]) List<LifeChangeSource> sources,
  }) = _LifeDelta;

  factory LifeDelta.fromJson(Map<String, dynamic> json) =>
      _$LifeDeltaFromJson(json);
}

/// The outcome of one round's voting (§11).
@freezed
abstract class RoundResolution with _$RoundResolution {
  const factory RoundResolution({
    String? targetPlayerId,
    @Default(false) bool targetWasImposter,

    /// Nobody loses a life: an unresolvable tie (§7a), Near-Unanimous falling
    /// short, or a Veto (§9c, §9d).
    @Default(false) bool wasWash,
    @Default(<LifeDelta>[]) List<LifeDelta> lifeDeltas,

    /// Players whose loss was reduced by the §7b clamp. Surfaced so the recap
    /// can say "capped", and so the property test can assert the clamp fired.
    @Default(<String>[]) List<String> cappedPlayerIds,
  }) = _RoundResolution;

  const RoundResolution._();

  factory RoundResolution.fromJson(Map<String, dynamic> json) =>
      _$RoundResolutionFromJson(json);

  /// Net change for one player, 0 if untouched.
  int deltaFor(String playerId) {
    for (final d in lifeDeltas) {
      if (d.playerId == playerId) return d.delta;
    }
    return 0;
  }
}

/// One round (§11).
@freezed
abstract class Round with _$Round {
  const factory Round({
    required String id,
    required int roundIndex,
    required int startingPlayerIndex,
    required String topicId,
    required String word,
    required String imposterClue,
    required ClueTier clueTierUsed,
    required List<String> imposterPlayerIds,
    @Default(0) int roundaboutsCompleted,
    @Default(1) int roundaboutsRequired,

    /// The §9c modifier for this round, or null when Interference is off or
    /// nothing rolled.
    String? roundModifier,
    @Default(<PlayerPickEvent>[]) List<PlayerPickEvent> playerPickEvents,
    @Default(<Vote>[]) List<Vote> votes,
    @Default(<ItemUsage>[]) List<ItemUsage> itemUsages,
    RoundResolution? resolution,
  }) = _Round;

  const Round._();

  factory Round.fromJson(Map<String, dynamic> json) => _$RoundFromJson(json);

  bool isImposter(String playerId) => imposterPlayerIds.contains(playerId);

  /// Role lookup for resolution. Every player not assigned imposter is crew —
  /// all crew share one real word, and no event may change a role mid-round
  /// (§9b consistency rule).
  PlayerRole roleOf(String playerId) =>
      isImposter(playerId) ? PlayerRole.imposter : PlayerRole.crew;
}
