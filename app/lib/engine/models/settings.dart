import 'package:diakooi/engine/models/enums.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings.freezed.dart';
part 'settings.g.dart';

/// One topic's share of the round-to-round mix (§13b).
///
/// A topic at 0% is excluded entirely rather than merely unlikely.
@freezed
abstract class TopicWeight with _$TopicWeight {
  const factory TopicWeight({
    required String topicId,
    required int weightPercent,
  }) = _TopicWeight;

  factory TopicWeight.fromJson(Map<String, dynamic> json) =>
      _$TopicWeightFromJson(json);
}

/// Interference sub-system toggles (§9a). Nothing fires unless its specific
/// toggle is on, and [enabled] gates all of them.
@freezed
abstract class InterferenceSettings with _$InterferenceSettings {
  const factory InterferenceSettings({
    @Default(false) bool enabled,
    @Default(false) bool playerPickEnabled,
    @Default(false) bool roundStartEnabled,
    @Default(false) bool itemsEnabled,

    /// §12 open item 2: starts at 25%, needs playtest.
    @Default(0.25) double playerPickProbability,

    /// Per-event eligibility. Empty means "every event that is
    /// `defaultEnabled`" — see [InterferenceSettings.isEventEnabled].
    @Default(<String>[]) List<String> enabledEventIds,
  }) = _InterferenceSettings;

  const InterferenceSettings._();

  factory InterferenceSettings.fromJson(Map<String, dynamic> json) =>
      _$InterferenceSettingsFromJson(json);

  bool isEventEnabled(String eventId, {required bool defaultEnabled}) {
    if (enabledEventIds.isEmpty) return defaultEnabled;
    return enabledEventIds.contains(eventId);
  }
}

/// Host setup parameters (§2).
///
/// Construct through [RoomSettings.validated] rather than the raw factory when
/// the values came from user input; it enforces the §2 ranges and the §13b
/// "weights must total 100" rule at the boundary.
@freezed
abstract class RoomSettings with _$RoomSettings {
  const factory RoomSettings({
    required int playerCount,
    required List<TopicWeight> topicWeights,
    @Default(ClueTier.standard) ClueTier clueDifficulty,
    @Default(1) int imposterCount,
    @Default(3) int livesPerPlayer,
    @Default(8) int totalRounds,
    @Default(2) int roundaboutsPerRound,

    /// N players served a forfeit, or null for off (§8).
    int? earlyEndConsequenceThreshold,

    /// Auto at 13+ (§2a).
    @Default(false) bool largeGroupMode,

    /// null = off, which is the default (§6).
    int? clueTimerSeconds,

    /// §2b — default false, and not cosmetic.
    @Default(false) bool hostIsPlayer,
    @Default(InterferenceSettings()) InterferenceSettings interference,
  }) = _RoomSettings;

  const RoomSettings._();

  factory RoomSettings.fromJson(Map<String, dynamic> json) =>
      _$RoomSettingsFromJson(json);

  /// Applies the §2 ranges and §13b weight rule, and derives [largeGroupMode].
  ///
  /// Throws [ArgumentError] rather than silently clamping: a room built from a
  /// bad config should fail loudly at setup, not produce a subtly wrong game.
  factory RoomSettings.validated({
    required int playerCount,
    required List<TopicWeight> topicWeights,
    ClueTier clueDifficulty = ClueTier.standard,
    int? imposterCount,
    int livesPerPlayer = 3,
    int totalRounds = 8,
    int roundaboutsPerRound = 2,
    int? earlyEndConsequenceThreshold,
    int? clueTimerSeconds,
    bool hostIsPlayer = false,
    InterferenceSettings interference = const InterferenceSettings(),
  }) {
    if (playerCount < minPlayers || playerCount > maxPlayers) {
      throw ArgumentError.value(
        playerCount,
        'playerCount',
        'must be $minPlayers-$maxPlayers (§2)',
      );
    }
    if (livesPerPlayer < minLives || livesPerPlayer > maxLives) {
      throw ArgumentError.value(
        livesPerPlayer,
        'livesPerPlayer',
        'must be $minLives-$maxLives (§2)',
      );
    }
    if (totalRounds < 1) {
      throw ArgumentError.value(totalRounds, 'totalRounds', 'must be >= 1');
    }
    if (roundaboutsPerRound < minRoundabouts ||
        roundaboutsPerRound > maxRoundabouts) {
      throw ArgumentError.value(
        roundaboutsPerRound,
        'roundaboutsPerRound',
        'must be $minRoundabouts-$maxRoundabouts (§2)',
      );
    }

    final resolvedImposters =
        imposterCount ?? defaultImposterCount(playerCount);
    if (resolvedImposters < minImposters || resolvedImposters > maxImposters) {
      throw ArgumentError.value(
        resolvedImposters,
        'imposterCount',
        'must be $minImposters-$maxImposters (§2)',
      );
    }
    if (resolvedImposters >= playerCount) {
      throw ArgumentError.value(
        resolvedImposters,
        'imposterCount',
        'must leave at least one crew member',
      );
    }
    if (earlyEndConsequenceThreshold != null &&
        (earlyEndConsequenceThreshold < 1 ||
            earlyEndConsequenceThreshold > 3)) {
      throw ArgumentError.value(
        earlyEndConsequenceThreshold,
        'earlyEndConsequenceThreshold',
        'must be 1-3 or null (§8)',
      );
    }

    if (topicWeights.isEmpty) {
      throw ArgumentError.value(
        topicWeights,
        'topicWeights',
        'at least one topic is required',
      );
    }
    final total = topicWeights.fold<int>(0, (sum, w) => sum + w.weightPercent);
    if (total != 100) {
      throw ArgumentError.value(
        total,
        'topicWeights',
        'weights must total 100 (§13b), got $total',
      );
    }
    if (topicWeights.any((w) => w.weightPercent < 0)) {
      throw ArgumentError.value(
        topicWeights,
        'topicWeights',
        'weights may not be negative',
      );
    }
    final ids = topicWeights.map((w) => w.topicId).toSet();
    if (ids.length != topicWeights.length) {
      throw ArgumentError.value(
        topicWeights,
        'topicWeights',
        'duplicate topicId',
      );
    }

    return RoomSettings(
      playerCount: playerCount,
      topicWeights: topicWeights,
      clueDifficulty: clueDifficulty,
      imposterCount: resolvedImposters,
      livesPerPlayer: livesPerPlayer,
      totalRounds: totalRounds,
      roundaboutsPerRound: roundaboutsPerRound,
      earlyEndConsequenceThreshold: earlyEndConsequenceThreshold,
      largeGroupMode: playerCount >= largeGroupThreshold,
      clueTimerSeconds: clueTimerSeconds,
      hostIsPlayer: hostIsPlayer,
      interference: interference,
    );
  }

  /// Player count at or above which Large Group Mode engages (§2a).
  static const largeGroupThreshold = 13;

  static const minPlayers = 3;
  static const maxPlayers = 20;
  static const minLives = 1;
  static const maxLives = 5;
  static const minImposters = 1;
  static const maxImposters = 4;
  static const minRoundabouts = 1;
  static const maxRoundabouts = 3;

  /// Default imposter count for a table size (§2).
  static int defaultImposterCount(int playerCount) {
    if (playerCount <= 6) return 1;
    if (playerCount <= 11) return 2;
    if (playerCount <= 16) return 3;
    return 4;
  }

  /// Topics eligible to be drawn — anything above 0% (§13b).
  List<TopicWeight> get eligibleTopics => [
    for (final w in topicWeights)
      if (w.weightPercent > 0) w,
  ];

  /// Roundabouts actually run, after the §2a cap.
  int get effectiveRoundabouts => largeGroupMode
      ? 1
      : roundaboutsPerRound.clamp(minRoundabouts, maxRoundabouts);

  /// The clue tier the imposter receives, one step tighter in Large Group Mode
  /// because at 12+ there is far more information on the table (§14).
  ClueTier get effectiveClueTier =>
      largeGroupMode ? clueDifficulty.oneTighter : clueDifficulty;
}
