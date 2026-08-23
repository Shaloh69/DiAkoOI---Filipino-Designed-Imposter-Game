import 'package:diakooi/engine/engine.dart';
import 'package:diakooi/selfie/selfie_bytes.dart';
import 'package:flutter/foundation.dart';

/// One player's live session state, including the parts that never persist.
@immutable
class SeatedPlayer {
  const SeatedPlayer({required this.player, this.selfie});

  final Player player;

  /// In-memory only, never a path (01-DESIGN.md §4b). Null means the player
  /// skipped and gets a monogram, which §4 makes a first-class path.
  final SelfieBytes? selfie;

  String get id => player.id;

  SeatedPlayer copyWith({Player? player, SelfieBytes? selfie}) => SeatedPlayer(
    player: player ?? this.player,
    selfie: selfie ?? this.selfie,
  );
}

/// The whole game, as one immutable value.
///
/// The engine owns every rule; this owns *where we are*. Resolution is still
/// the pure `resolveRound` — nothing here recomputes damage, and no widget
/// callback decides anything (CLAUDE.md §Hard rules).
@immutable
class GameSession {
  const GameSession({
    required this.phase,
    required this.settings,
    required this.seats,
    this.mayorPlayerId,
    this.vibePackId,
    this.currentRoundIndex = 0,
    this.round,
    this.usedWords = const [],
    this.topicHistory = const [],
    this.pendingVotes = const [],
    this.selectedVoterId,
    this.lastResolution,
    this.pendingForfeits = const [],
    this.onboardedCount = 0,
    this.distributedCount = 0,
    this.hostEnded = false,
    this.roll = const InterferenceRoll(),
    this.pendingTaboo = const [],
    this.itemPickup,
    this.itemUsages = const [],
  });

  /// A session before any setup.
  factory GameSession.initial() => GameSession(
    phase: GamePhase.lobby,
    settings: RoomSettings.validated(
      playerCount: 6,
      topicWeights: TopicPresets.barkadaClassic.weights,
    ),
    seats: const [],
  );

  final GamePhase phase;
  final RoomSettings settings;
  final List<SeatedPlayer> seats;

  /// Fixed for the game and private to that player (§7a).
  final String? mayorPlayerId;
  final String? vibePackId;

  final int currentRoundIndex;

  final Round? round;

  /// Which roundabout is in progress, 0-based.
  ///
  /// Derived rather than stored. Laps completed is already recorded on the
  /// round, and a second copy on the session is a second thing to keep in step
  /// — the kind of duplication that shows up later as an off-by-one in the
  /// speaking order and nowhere else.
  int get currentLap => round?.roundaboutsCompleted ?? 0;
  final List<String> usedWords;
  final List<String> topicHistory;

  /// Votes recorded so far this round, by two-tap (§7).
  final List<Vote> pendingVotes;

  /// The caller tapped first, awaiting the accused. Two-tap is required, not
  /// preferred: accuser-pays cannot resolve without knowing who accused whom.
  final String? selectedVoterId;

  final RoundResolution? lastResolution;
  final List<PendingForfeit> pendingForfeits;

  /// Players who have finished onboarding, and reveals handed out this round.
  final int onboardedCount;
  final int distributedCount;

  final bool hostEnded;

  /// What §9 rolled for the current round. Empty when Interference is off,
  /// which is the default and the whole of rounds 1.
  final InterferenceRoll roll;

  /// Taboo reconciliations still to adjudicate at end of lap (§9b).
  ///
  /// The words are shown to the table only here — during the clue nobody knows
  /// what to listen for, which is the tension the event is built on.
  final List<String> pendingTaboo;

  /// A second-pickup decision waiting on the player (§9d).
  final ItemPickup? itemPickup;

  /// Items played this round, in the order they were used.
  final List<ItemUsage> itemUsages;

  List<Player> get players => [for (final seat in seats) seat.player];

  SeatedPlayer? seatFor(String playerId) {
    for (final seat in seats) {
      if (seat.id == playerId) return seat;
    }
    return null;
  }

  /// Votes recorded out of votes expected — the "7 of 10 recorded" the host
  /// needs so they cannot resolve early (§7).
  int get votesRecorded => pendingVotes.length;
  int get votesExpected => seats.length;
  bool get allVotesRecorded => votesRecorded >= votesExpected;

  /// Whether [accusedId] may still be named.
  ///
  /// Self-votes are rejected by the grid (§7), and a Vote Lock player is immune
  /// for the round (§9b). Both are enforced here rather than in a widget, so
  /// the rule is testable without pumping a UI.
  bool canAccuse({required String voterId, required String accusedId}) {
    if (voterId == accusedId) return false;
    if (pendingVotes.any((v) => v.voterId == voterId)) return false;
    if (isVoteLocked(accusedId)) return false;
    // §9c Spread the Blame: no more than two players may name the same
    // suspect. A full no-duplicates ban is unresolvable — N voters across N
    // tiles gives every tile one vote and a permanent N-way tie.
    if (roll.roundModifier == InterferenceCatalogue.spreadTheBlame &&
        accusersOf(accusedId).length >= spreadTheBlameCap) {
      return false;
    }
    return true;
  }

  /// §9c Spread the Blame's duplicate cap.
  static const spreadTheBlameCap = 2;

  bool hasVoted(String playerId) =>
      pendingVotes.any((v) => v.voterId == playerId);

  /// Live tally for the grid.
  Map<String, int> get liveTally {
    final tally = <String, int>{};
    for (final vote in pendingVotes) {
      tally[vote.accusedId] = (tally[vote.accusedId] ?? 0) + vote.tallyWeight;
    }
    return tally;
  }

  /// Whether [accusedId] is immune from being named this round (§9b Vote
  /// Lock). The grid refuses the tap rather than recording a vote it will
  /// then discard.
  bool isVoteLocked(String accusedId) =>
      roll.eventFor(accusedId) == InterferenceCatalogue.voteLock;

  /// Tally weight for one caller's accusation (§9b Double Vote, §9d
  /// Megaphone). **Weight is tally only — damage is always 1** (§7).
  int tallyWeightFor(String voterId) {
    final doubled =
        roll.eventFor(voterId) == InterferenceCatalogue.doubleVote ||
        itemUsages.any(
          (u) =>
              u.playerId == voterId &&
              u.itemId == InterferenceCatalogue.itemMegaphone,
        );
    return doubled ? 2 : 1;
  }

  /// Accusers of one tile, so their thumbnails can stack under it (§7).
  List<String> accusersOf(String accusedId) => [
    for (final vote in pendingVotes)
      if (vote.accusedId == accusedId) vote.voterId,
  ];

  bool get isComplete =>
      hostEnded ||
      currentRoundIndex >= settings.totalRounds ||
      LifeCheck.earlyEndReached(players: players, settings: settings);

  GameSession copyWith({
    GamePhase? phase,
    RoomSettings? settings,
    List<SeatedPlayer>? seats,
    String? mayorPlayerId,
    String? vibePackId,
    int? currentRoundIndex,
    Round? round,
    List<String>? usedWords,
    List<String>? topicHistory,
    List<Vote>? pendingVotes,
    String? selectedVoterId,
    bool clearSelectedVoter = false,
    RoundResolution? lastResolution,
    List<PendingForfeit>? pendingForfeits,
    int? onboardedCount,
    int? distributedCount,
    bool? hostEnded,
    InterferenceRoll? roll,
    List<String>? pendingTaboo,
    ItemPickup? itemPickup,
    bool clearItemPickup = false,
    List<ItemUsage>? itemUsages,
  }) => GameSession(
    phase: phase ?? this.phase,
    settings: settings ?? this.settings,
    seats: seats ?? this.seats,
    mayorPlayerId: mayorPlayerId ?? this.mayorPlayerId,
    vibePackId: vibePackId ?? this.vibePackId,
    currentRoundIndex: currentRoundIndex ?? this.currentRoundIndex,
    round: round ?? this.round,
    usedWords: usedWords ?? this.usedWords,
    topicHistory: topicHistory ?? this.topicHistory,
    pendingVotes: pendingVotes ?? this.pendingVotes,
    selectedVoterId: clearSelectedVoter
        ? null
        : (selectedVoterId ?? this.selectedVoterId),
    lastResolution: lastResolution ?? this.lastResolution,
    pendingForfeits: pendingForfeits ?? this.pendingForfeits,
    onboardedCount: onboardedCount ?? this.onboardedCount,
    distributedCount: distributedCount ?? this.distributedCount,
    hostEnded: hostEnded ?? this.hostEnded,
    roll: roll ?? this.roll,
    pendingTaboo: pendingTaboo ?? this.pendingTaboo,
    itemPickup: clearItemPickup ? null : (itemPickup ?? this.itemPickup),
    itemUsages: itemUsages ?? this.itemUsages,
  );
}

/// The five end-of-game awards (§10).
///
/// Cosmetic — there is no hard win condition, and adding one would fight the
/// forfeit loop. But accuser-pays means Sharpest Read genuinely correlates with
/// taking fewer forfeits, so the summary reflects real play.
@immutable
class Award {
  const Award({
    required this.id,
    required this.title,
    required this.playerId,
    required this.detail,
  });

  final String id;
  final String title;
  final String playerId;
  final String detail;
}

/// Computes the §10 awards.
///
/// Returns nothing for an award nobody qualifies for, rather than handing it to
/// an arbitrary player on a tie-break nobody can see.
List<Award> computeAwards(List<Player> players) {
  if (players.isEmpty) return const [];

  Award? best({
    required String id,
    required String title,
    required num Function(Player) score,
    required String Function(Player) detail,
    required bool Function(Player) eligible,
  }) {
    final candidates = players.where(eligible).toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => score(b).compareTo(score(a)));
    final top = candidates.first;
    if (score(top) <= 0) return null;
    return Award(
      id: id,
      title: title,
      playerId: top.id,
      detail: detail(top),
    );
  }

  return [
    for (final award in <Award?>[
      best(
        id: 'sharpest_read',
        title: 'Sharpest Read',
        score: (p) => p.stats.accusationAccuracy,
        detail: (p) =>
            '${(p.stats.accusationAccuracy * 100).round()}% of accusations '
            'landed on a real imposter',
        eligible: (p) => p.stats.accusationsMade > 0,
      ),
      best(
        id: 'best_bluffer',
        title: 'Best Bluffer',
        score: (p) => p.stats.roundsAsImposterUncaught,
        detail: (p) =>
            '${p.stats.roundsAsImposterUncaught} rounds as imposter without '
            'being targeted',
        eligible: (p) => p.stats.roundsAsImposter > 0,
      ),
      best(
        id: 'most_consequences',
        title: 'Most Consequences',
        score: (p) => p.consequenceLog.length,
        detail: (p) => '${p.consequenceLog.length} forfeits served',
        eligible: (p) => true,
      ),
      best(
        id: 'most_wanted',
        title: 'Most Wanted',
        score: (p) => p.stats.votesReceived,
        detail: (p) => '${p.stats.votesReceived} votes received',
        eligible: (p) => true,
      ),
      best(
        id: 'interference_magnet',
        title: 'Interference Magnet',
        score: (p) => p.stats.interferenceEventsReceived,
        detail: (p) =>
            '${p.stats.interferenceEventsReceived} interference events',
        eligible: (p) => true,
      ),
    ])
      ?award,
  ];
}
