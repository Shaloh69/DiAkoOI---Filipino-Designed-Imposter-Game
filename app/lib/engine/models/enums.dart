/// Core vocabulary for the DiAkoOi engine.
///
/// Pure Dart. Nothing in `lib/engine/` may import `package:flutter`
/// (CLAUDE.md §Hard rules) — enforced by a test and by CI.
library;

/// Which side a player is on **for one round**. Re-rolled every round (§3).
enum PlayerRole {
  crew,
  imposter;

  bool get isImposter => this == PlayerRole.imposter;
}

/// Authored clue tiers (§14). Nothing is algorithmically derived.
enum ClueTier {
  /// Near-neighbour sharing most attributes; bluff confidently.
  tight,

  /// Functional description, good for one or two safe clues.
  standard,

  /// Broad frame; on your own after the first clue.
  loose;

  /// One step tighter, used by Large Group Mode (§14) and the Reword item
  /// (§9d). Already-tight stays tight rather than throwing.
  ClueTier get oneTighter => switch (this) {
    ClueTier.loose => ClueTier.standard,
    ClueTier.standard => ClueTier.tight,
    ClueTier.tight => ClueTier.tight,
  };
}

/// Content region (§13c). v1 ships `national` only; the field exists so
/// regional packs land later without a migration.
enum ContentRegion { national, luzon, visayas, mindanao }

/// Finite state machine states, in the order of §3.
enum GamePhase {
  lobby,
  vibeRoll,
  playerOnboarding,
  roundStart,
  wordDistribution,
  discussionPhase,
  votingPhase,
  resolution,
  lifeCheck,
  roundEndCheck,
  gameSummary,
  replayPrompt,
}

/// Room status as modelled in §11. Distinct from [GamePhase]: this is the
/// coarse lifecycle the data model records, not the per-step machine.
enum RoomStatus { lobby, onboarding, inRound, voting, resolved, ended }

/// Whether an interference effect can be enforced by the app, relies on the
/// table policing it, or is adjudicated after the fact (§9b, §9f).
enum EventEnforcement { app, social, retroactive }

/// Which toggle group an interference event belongs to (§9a).
enum EventCategory { playerPick, roundStart, item }

/// Item classes (§9d).
enum ItemClass { defence, info, vote, wildcard }

/// The phase in which an item was played. Items resolve against the holder's
/// role in the round they are used, not the round they were picked up (§9d).
enum ItemUsePhase { wordDistribution, discussion, voting, afterTally }

/// Why a player's life total moved. Kept on every delta so the round recap can
/// explain itself and so tests can assert on cause, not just magnitude.
enum LifeChangeSource {
  /// Caught imposter takes 2 (§7).
  caughtImposter,

  /// Accuser of a crew member takes 1 (§7, accuser-pays).
  wrongAccusation,

  /// Reverse Round: naming an imposter costs each accuser (§9c).
  reverseRoundAccuser,

  /// Reverse Round: naming crew costs the accused (§9c).
  reverseRoundAccused,

  /// Sudden Death drains the target (§9c). The sole damage-cap bypass.
  suddenDeath,

  /// The Fool / Fool's Round: the target gains instead of losing (§9b, §9c).
  foolBonus,

  bonusLife,
  lifeDrain,
  stealLifeGain,
  stealLifeLoss,
  tabooSlip,

  /// Mirror item reflected a loss back onto its cause (§9d).
  mirrorReflection,

  /// Restored to 1 after serving a forfeit (§8).
  consequenceRestore,
}
