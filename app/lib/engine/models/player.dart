import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'player.freezed.dart';
part 'player.g.dart';

/// One served forfeit (§8). `consequenceLog` length is the headline end-screen
/// stat.
@freezed
abstract class ConsequenceEntry with _$ConsequenceEntry {
  const factory ConsequenceEntry({
    required int roundIndex,

    /// Free text, self-authored by the player. Not a fixed menu (§8).
    required String description,
    DateTime? servedAt,
  }) = _ConsequenceEntry;

  const ConsequenceEntry._();

  factory ConsequenceEntry.fromJson(Map<String, dynamic> json) =>
      _$ConsequenceEntryFromJson(json);

  bool get isServed => servedAt != null;
}

/// Cosmetic end-of-game statistics (§10). No hard win condition.
@freezed
abstract class PlayerStats with _$PlayerStats {
  const factory PlayerStats({
    @Default(0) int accusationsMade,
    @Default(0) int accusationsCorrect,
    @Default(0) int roundsAsImposter,
    @Default(0) int roundsAsImposterUncaught,
    @Default(0) int votesReceived,
    @Default(0) int interferenceEventsReceived,
  }) = _PlayerStats;

  const PlayerStats._();

  factory PlayerStats.fromJson(Map<String, dynamic> json) =>
      _$PlayerStatsFromJson(json);

  /// Sharpest Read (§10): share of accusations that landed on a real imposter.
  double get accusationAccuracy =>
      accusationsMade == 0 ? 0 : accusationsCorrect / accusationsMade;
}

/// A player at the table (§11).
///
/// [selfieBytes] is **in-memory only and never a path** (§4b). It is excluded
/// from JSON entirely so it cannot be serialised into a store by accident —
/// see `docs/adr/0005-extended-ram-and-selfie-privacy.md` for the exact scope
/// of that guarantee.
@freezed
abstract class Player with _$Player {
  const factory Player({
    required String id,
    required String name,
    required int seatOrder,
    required int currentLives,
    @JsonKey(includeFromJson: false, includeToJson: false)
    Uint8List? selfieBytes,
    String? monogramColor,
    String? heldItem,
    @Default(<ConsequenceEntry>[]) List<ConsequenceEntry> consequenceLog,
    @Default(PlayerStats()) PlayerStats stats,
  }) = _Player;

  const Player._();

  factory Player.fromJson(Map<String, dynamic> json) => _$PlayerFromJson(json);

  bool get isOut => currentLives <= 0;

  bool get hasItem => heldItem != null;

  /// Forfeits served, which drives the early-end threshold (§8).
  int get forfeitsServed => consequenceLog.where((c) => c.isServed).length;
}
