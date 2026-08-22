import 'package:diakooi/engine/models/enums.dart';
import 'package:diakooi/engine/models/settings.dart';

/// The game's finite state machine (§3).
///
/// Pure and side-effect free: it answers "what comes next" and "is this legal",
/// and holds no state of its own. The caller owns the room and drives it.
abstract final class GameMachine {
  /// Legal transitions, exactly as drawn in §3.
  ///
  /// `roundEndCheck` has two exits — back to `roundStart` for another round, or
  /// on to `gameSummary` — which is the only branch in the diagram.
  static const Map<GamePhase, List<GamePhase>> transitions = {
    GamePhase.lobby: [GamePhase.vibeRoll],
    GamePhase.vibeRoll: [GamePhase.playerOnboarding],

    // Round 1's word distribution is folded into onboarding, so onboarding
    // exits straight to roundStart.
    GamePhase.playerOnboarding: [GamePhase.roundStart],
    GamePhase.roundStart: [
      // Rounds 2+ distribute words as their own phase.
      GamePhase.wordDistribution,
      // Round 1 has already distributed during onboarding.
      GamePhase.discussionPhase,
      // No Roundabouts (§9c) goes straight to voting.
      GamePhase.votingPhase,
    ],
    GamePhase.wordDistribution: [
      GamePhase.discussionPhase,
      GamePhase.votingPhase,
    ],
    GamePhase.discussionPhase: [GamePhase.votingPhase],
    GamePhase.votingPhase: [GamePhase.resolution],
    GamePhase.resolution: [GamePhase.lifeCheck],
    GamePhase.lifeCheck: [GamePhase.roundEndCheck],
    GamePhase.roundEndCheck: [GamePhase.roundStart, GamePhase.gameSummary],
    GamePhase.gameSummary: [GamePhase.replayPrompt],

    // Replay carries all parameters and resets lives and the round counter,
    // keeping names and selfies (§10). The Vibe Pack rerolls unless pinned,
    // which is why replay re-enters at vibeRoll rather than onboarding.
    GamePhase.replayPrompt: [GamePhase.vibeRoll, GamePhase.lobby],
  };

  static bool canTransition(GamePhase from, GamePhase to) =>
      transitions[from]?.contains(to) ?? false;

  /// The next phase, given where the round is.
  ///
  /// Throws [StateError] for a phase with no single successor — `roundEndCheck`
  /// branches, so callers use [afterRoundEndCheck] there instead.
  static GamePhase next(
    GamePhase from, {
    required int roundIndex,
    required bool hasRoundabouts,
  }) => switch (from) {
    GamePhase.lobby => GamePhase.vibeRoll,
    GamePhase.vibeRoll => GamePhase.playerOnboarding,
    GamePhase.playerOnboarding => GamePhase.roundStart,
    GamePhase.roundStart =>
      // Round 1 distributed during onboarding; rounds 2+ get their own phase.
      roundIndex == 0
          ? (hasRoundabouts ? GamePhase.discussionPhase : GamePhase.votingPhase)
          : GamePhase.wordDistribution,
    GamePhase.wordDistribution =>
      hasRoundabouts ? GamePhase.discussionPhase : GamePhase.votingPhase,
    GamePhase.discussionPhase => GamePhase.votingPhase,
    GamePhase.votingPhase => GamePhase.resolution,
    GamePhase.resolution => GamePhase.lifeCheck,
    GamePhase.lifeCheck => GamePhase.roundEndCheck,
    GamePhase.gameSummary => GamePhase.replayPrompt,
    GamePhase.roundEndCheck || GamePhase.replayPrompt => throw StateError(
      '$from branches; use afterRoundEndCheck or start a replay explicitly',
    ),
  };

  /// The `roundEndCheck` branch (§3).
  ///
  /// The game ends at the round limit, at the early-end threshold (§8), or on
  /// host command — [hostEnded] carries that last one.
  static GamePhase afterRoundEndCheck({
    required int completedRounds,
    required RoomSettings settings,
    required int playersWhoServedForfeit,
    bool hostEnded = false,
  }) {
    if (hostEnded) return GamePhase.gameSummary;
    if (completedRounds >= settings.totalRounds) return GamePhase.gameSummary;

    final threshold = settings.earlyEndConsequenceThreshold;
    if (threshold != null && playersWhoServedForfeit >= threshold) {
      return GamePhase.gameSummary;
    }
    return GamePhase.roundStart;
  }

  /// Whether interference may fire in [roundIndex].
  ///
  /// **Suppressed during round 1** (§3, §9f): the table is still learning the
  /// game during onboarding, and a modifier landing before anyone knows the
  /// base rules reads as the app being broken.
  static bool interferenceAllowed({
    required int roundIndex,
    required RoomSettings settings,
  }) => settings.interference.enabled && roundIndex > 0;
}
