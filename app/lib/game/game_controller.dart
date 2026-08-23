import 'package:diakooi/engine/engine.dart';
import 'package:diakooi/game/game_session.dart';
import 'package:diakooi/selfie/selfie_bytes.dart';

/// Sequences the §3 state machine.
///
/// **Every rule stays in the engine.** This decides *when* to call it, never
/// what the answer is: resolution is still the pure top-level `resolveRound`,
/// life changes still go through [LifeCheck], and every draw still goes through
/// a selector with an injected [GameRng]. "No game logic in widget callbacks"
/// (CLAUDE.md §Hard rules) means no game logic here either — a widget calls a
/// method on this, and this calls the engine.
///
/// Interference (§9) is Phase 5. Until then every round resolves with an empty
/// [RoundModifiers] and no items, which is what the defaults already describe:
/// `InterferenceSettings.enabled` is false unless the host turns it on.
class GameController {
  GameController({
    required this.wordBank,
    required this.rng,
    GameSession? initial,
  }) : _session = initial ?? GameSession.initial();

  final List<WordBankEntry> wordBank;

  /// Injected, never global — a seeded instance replays a whole game exactly.
  final GameRng rng;

  GameSession _session;
  GameSession get session => _session;

  final List<String> _trail = [];

  /// Every phase edge this game has walked, as `from->to`.
  ///
  /// Kept because a single step can cross two edges — the round-end check
  /// enters and leaves in one call — so sampling the phase after each method
  /// silently misses transitions. A4 asks whether every transition is
  /// reachable, and this is what makes that answerable rather than asserted.
  List<String> get transitionTrail => List.unmodifiable(_trail);

  /// Guards every transition against the §3 diagram.
  ///
  /// A move the diagram does not draw is a bug in the caller, and failing
  /// loudly here is what makes "every transition reachable, no dead ends"
  /// something a test can hold to account instead of a claim.
  void _moveTo(GamePhase next) {
    if (!GameMachine.canTransition(_session.phase, next)) {
      throw StateError(
        'illegal transition ${_session.phase.name} -> ${next.name} '
        '(01-DESIGN.md §3)',
      );
    }
    _trail.add('${_session.phase.name}->${next.name}');
    _session = _session.copyWith(phase: next);
  }

  /// [_moveTo], but tolerant of already being there.
  ///
  /// Some phases are entered by the step before them — `ROUND_END_CHECK` moves
  /// straight to `ROUND_START`, and Play Again lands on `VIBE_ROLL` — and the
  /// screen for that phase then does its own work on arrival. Strictness still
  /// applies everywhere a repeat would be a real bug: calling [beginVoting]
  /// twice, or resolving a round twice, still throws.
  void _enter(GamePhase phase) {
    if (_session.phase == phase) return;
    _moveTo(phase);
  }

  // ── LOBBY ─────────────────────────────────────────────────────────────

  /// Applies host setup (§2).
  ///
  /// [RoomSettings.validated] has already enforced the §2 ranges, the §13b
  /// weights-total-100 rule and the Large Group auto-switch, so there is
  /// nothing left to re-check here.
  void configure(RoomSettings settings) {
    if (_session.phase != GamePhase.lobby) {
      throw StateError('settings may only change in the lobby (§2)');
    }
    _session = _session.copyWith(settings: settings);
  }

  /// `VIBE_ROLL` — the pack is drawn before onboarding so the theme is up from
  /// screen one (§3).
  void rollVibe(String packId) {
    _enter(GamePhase.vibeRoll);
    _session = _session.copyWith(vibePackId: packId);
  }

  // ── PLAYER_ONBOARDING ─────────────────────────────────────────────────

  void beginOnboarding() => _moveTo(GamePhase.playerOnboarding);

  /// Seats one player. [selfie] null means they skipped and get a monogram —
  /// §4 makes Skip a first-class path, not a degraded one.
  void addPlayer({required String name, SelfieBytes? selfie}) {
    if (_session.phase != GamePhase.playerOnboarding) {
      throw StateError('players are seated during onboarding (§3)');
    }
    if (_session.seats.length >= _session.settings.playerCount) {
      throw StateError(
        'the host set up ${_session.settings.playerCount} seats and they are '
        'all taken',
      );
    }
    final seatOrder = _session.seats.length;
    _session = _session.copyWith(
      seats: [
        ..._session.seats,
        SeatedPlayer(
          player: Player(
            id: 'p$seatOrder',
            name: name,
            seatOrder: seatOrder,
            currentLives: _session.settings.livesPerPlayer,
          ),
          selfie: selfie,
        ),
      ],
      onboardedCount: _session.onboardedCount + 1,
    );
  }

  bool get rosterComplete =>
      _session.seats.length == _session.settings.playerCount;

  /// Designates the Mayor once the roster is known (§7a).
  ///
  /// Secret, and fixed for the whole game. An imposter Mayor quietly steering a
  /// tie is the best case the role produces, so it is drawn from everyone.
  void designateMayor() {
    if (_session.seats.isEmpty) {
      throw StateError('cannot designate a Mayor before anyone is seated');
    }
    _session = _session.copyWith(mayorPlayerId: rng.pick(_session.seats).id);
  }

  // ── ROUND_START ───────────────────────────────────────────────────────

  /// Draws the topic, word and imposters for the next round (§3).
  void startRound() {
    if (!rosterComplete) {
      throw StateError(
        '${_session.seats.length} of ${_session.settings.playerCount} seats '
        'filled — onboarding is not finished',
      );
    }
    if (_session.mayorPlayerId == null) designateMayor();
    // Round 2 onwards arrives here already in ROUND_START, put there by the
    // round-end check.
    _enter(GamePhase.roundStart);

    final roundIndex = _session.currentRoundIndex;

    final topicId = TopicSelector.draw(
      settings: _session.settings,
      topicHistory: _session.topicHistory,
      rng: rng,
    );
    final entry = WordSelector.draw(
      topicId: topicId,
      bank: wordBank,
      usedWords: _session.usedWords,
      rng: rng,
    );
    final clue = WordSelector.clueFor(
      entry: entry,
      settings: _session.settings,
    );
    final imposters = ImposterAssigner.assign(
      players: _session.players,
      count: ImposterAssigner.countForRound(settings: _session.settings),
      rng: rng,
    );

    _session = _session.copyWith(
      round: Round(
        id: 'r$roundIndex',
        roundIndex: roundIndex,
        startingPlayerIndex: TurnOrder.startingIndex(
          roundIndex: roundIndex,
          playerCount: _session.seats.length,
        ),
        topicId: topicId,
        word: entry.word,
        imposterClue: clue.clue,
        clueTierUsed: clue.tier,
        imposterPlayerIds: imposters,
        roundaboutsRequired: _session.settings.effectiveRoundabouts,
      ),
      usedWords: [..._session.usedWords, entry.word],
      topicHistory: [..._session.topicHistory, topicId],
      pendingVotes: const [],
      clearSelectedVoter: true,
      distributedCount: 0,
      pendingForfeits: const [],
      // Roles are redrawn every round, so "rounds as imposter" accrues here
      // rather than at resolution — a round that ends in a wash still counted.
      seats: [
        for (final seat in _session.seats)
          if (imposters.contains(seat.id))
            seat.copyWith(
              player: seat.player.copyWith(
                stats: seat.player.stats.copyWith(
                  roundsAsImposter: seat.player.stats.roundsAsImposter + 1,
                ),
              ),
            )
          else
            seat,
      ],
    );
  }

  // ── WORD_DISTRIBUTION ─────────────────────────────────────────────────

  /// Hands out reveal cards.
  ///
  /// Round 1's distribution is folded into onboarding (§3), so round 1 skips
  /// this phase and rounds 2+ get their own pass around the table.
  void beginDistribution() {
    final round = _requireRound();
    _moveTo(
      GameMachine.next(
        GamePhase.roundStart,
        roundIndex: round.roundIndex,
        hasRoundabouts: round.roundaboutsRequired > 0,
      ),
    );
  }

  /// What [playerId] sees on their reveal card (§5).
  ///
  /// Delegates to [Round.revealFor] — the single place crew-vs-imposter is
  /// decided, so the UI cannot get it subtly different.
  String revealFor(String playerId) => _requireRound().revealFor(playerId);

  /// One more reveal handed over, for the "5 of 8 done" progress on the pass
  /// interstitial.
  void markRevealSeen() => _session = _session.copyWith(
    distributedCount: _session.distributedCount + 1,
  );

  bool get allRevealsSeen => _session.distributedCount >= _session.seats.length;

  // ── DISCUSSION_PHASE ──────────────────────────────────────────────────

  void beginDiscussion() => _enter(GamePhase.discussionPhase);

  /// Speaking order for the current lap, as seat indices (§6a).
  ///
  /// Both rotations apply: the starting seat moves every round, and each lap
  /// shifts by one so the same player does not close every lap.
  List<int> currentLapOrder() => TurnOrder.lapOrder(
    roundIndex: _session.currentRoundIndex,
    lapIndex: _session.currentLap,
    playerCount: _session.seats.length,
  );

  /// Marks one roundabout finished (§6).
  void completeLap() {
    final round = _requireRound();
    if (_session.phase != GamePhase.discussionPhase) {
      throw StateError('roundabouts happen during discussion (§6)');
    }
    _session = _session.copyWith(
      round: round.copyWith(
        roundaboutsCompleted: round.roundaboutsCompleted + 1,
      ),
    );
  }

  bool get lapsRemaining {
    final round = _session.round;
    if (round == null) return false;
    return round.roundaboutsCompleted < round.roundaboutsRequired;
  }

  // ── VOTING_PHASE ──────────────────────────────────────────────────────

  void beginVoting() => _moveTo(GamePhase.votingPhase);

  /// First tap: the caller.
  ///
  /// Two-tap is required rather than preferred — accuser-pays cannot resolve
  /// without knowing who accused whom (§7).
  void selectVoter(String voterId) {
    if (_session.hasVoted(voterId)) return;
    _session = _session.copyWith(selectedVoterId: voterId);
  }

  void clearVoterSelection() =>
      _session = _session.copyWith(clearSelectedVoter: true);

  /// Second tap: the accused.
  ///
  /// Returns false when the pair is illegal — a self-vote, or a caller who has
  /// already voted — so the grid can refuse the tap without knowing the rule.
  bool recordAccusation(String accusedId) {
    final voterId = _session.selectedVoterId;
    if (voterId == null) return false;
    if (!_session.canAccuse(voterId: voterId, accusedId: accusedId)) {
      return false;
    }
    _session = _session.copyWith(
      pendingVotes: [
        ..._session.pendingVotes,
        Vote(voterId: voterId, accusedId: accusedId),
      ],
      clearSelectedVoter: true,
    );
    return true;
  }

  /// Withdraws a recorded accusation, for a host mis-tap.
  void undoAccusation(String voterId) => _session = _session.copyWith(
    pendingVotes: [
      for (final vote in _session.pendingVotes)
        if (vote.voterId != voterId) vote,
    ],
  );

  // ── RESOLUTION ────────────────────────────────────────────────────────

  /// Resolves the round through the engine's pure function (§7).
  ///
  /// Refuses to run until every vote is in. The grid shows "7 of 10 recorded"
  /// precisely so a host cannot resolve three people early and hand two of them
  /// a forfeit they had no say in.
  RoundResolution resolve() {
    final round = _requireRound();
    if (!_session.allVotesRecorded) {
      throw StateError(
        'only ${_session.votesRecorded} of ${_session.votesExpected} votes '
        'recorded (§7)',
      );
    }
    _moveTo(GamePhase.resolution);

    final resolution = resolveRound(
      votes: _session.pendingVotes,
      roles: {
        for (final seat in _session.seats) seat.id: round.roleOf(seat.id),
      },
      modifiers: const RoundModifiers(),
      itemUsages: const [],
      currentLives: {
        for (final seat in _session.seats) seat.id: seat.player.currentLives,
      },
      mayorPlayerId: _session.mayorPlayerId,
    );

    _session = _session.copyWith(
      round: round.copyWith(
        votes: _session.pendingVotes,
        resolution: resolution,
      ),
      lastResolution: resolution,
      seats: _withVoteStats(resolution, round),
    );
    return resolution;
  }

  List<SeatedPlayer> _withVoteStats(
    RoundResolution resolution,
    Round round,
  ) => [
    for (final seat in _session.seats)
      seat.copyWith(
        player: seat.player.copyWith(
          stats: seat.player.stats.copyWith(
            accusationsMade:
                seat.player.stats.accusationsMade +
                (_session.hasVoted(seat.id) ? 1 : 0),
            accusationsCorrect:
                seat.player.stats.accusationsCorrect +
                (_accusedAnImposter(seat.id, round) ? 1 : 0),
            votesReceived:
                seat.player.stats.votesReceived +
                _session.accusersOf(seat.id).length,
            // Best Bluffer: an imposter the table did not land on. A wash
            // counts — surviving an unresolvable tie is still surviving.
            roundsAsImposterUncaught:
                seat.player.stats.roundsAsImposterUncaught +
                (round.isImposter(seat.id) &&
                        resolution.targetPlayerId != seat.id
                    ? 1
                    : 0),
          ),
        ),
      ),
  ];

  bool _accusedAnImposter(String voterId, Round round) {
    for (final vote in _session.pendingVotes) {
      if (vote.voterId == voterId) return round.isImposter(vote.accusedId);
    }
    return false;
  }

  // ── LIFE_CHECK ────────────────────────────────────────────────────────

  /// Applies the resolution to lives and reports who owes a forfeit (§8).
  LifeCheckResult applyLifeCheck() {
    final resolution = _session.lastResolution;
    if (resolution == null) throw StateError('nothing to apply');
    _moveTo(GamePhase.lifeCheck);

    final result = LifeCheck.apply(
      players: _session.players,
      resolution: resolution,
      settings: _session.settings,
      roundModifier: _session.round?.roundModifier,
    );

    _session = _session.copyWith(
      seats: [
        for (var i = 0; i < _session.seats.length; i++)
          _session.seats[i].copyWith(player: result.players[i]),
      ],
      pendingForfeits: result.pendingForfeits,
    );
    return result;
  }

  /// Records a served forfeit.
  ///
  /// [description] is free text the player authors themselves — §8 is explicit
  /// that this is not a fixed menu. [remainingAfterThis] is what keeps High
  /// Stakes honest: restoration is a floor reached once every owed forfeit has
  /// been served, not a reward paid per forfeit.
  void serveForfeit({
    required String playerId,
    required String description,
    int remainingAfterThis = 0,
  }) {
    final index = _session.seats.indexWhere((s) => s.id == playerId);
    if (index == -1) throw ArgumentError.value(playerId, 'playerId', 'unknown');

    final seats = [..._session.seats];
    seats[index] = seats[index].copyWith(
      player: LifeCheck.serveForfeit(
        player: seats[index].player,
        roundIndex: _session.currentRoundIndex,
        description: description,
        remainingAfterThis: remainingAfterThis,
      ),
    );

    _session = _session.copyWith(
      seats: seats,
      pendingForfeits: remainingAfterThis > 0
          ? _session.pendingForfeits
          : [
              for (final f in _session.pendingForfeits)
                if (f.playerId != playerId) f,
            ],
    );
  }

  // ── ROUND_END_CHECK ───────────────────────────────────────────────────

  /// Decides whether another round follows (§3).
  ///
  /// The only branch in the diagram: the round limit, the §8 early-end
  /// threshold, or the host calling it.
  GamePhase endRound() {
    _moveTo(GamePhase.roundEndCheck);
    _session = _session.copyWith(
      currentRoundIndex: _session.currentRoundIndex + 1,
    );

    final next = GameMachine.afterRoundEndCheck(
      completedRounds: _session.currentRoundIndex,
      settings: _session.settings,
      playersWhoServedForfeit: _session.players
          .where((p) => p.forfeitsServed > 0)
          .length,
      hostEnded: _session.hostEnded,
    );
    _moveTo(next);
    return next;
  }

  /// The host may call the game at any point (§8). It takes effect at the next
  /// round-end check rather than mid-round, so nobody is cut off mid-vote.
  void endGameEarly() => _session = _session.copyWith(hostEnded: true);

  // ── GAME_SUMMARY / REPLAY ─────────────────────────────────────────────

  /// The §10 awards. Cosmetic — there is no hard win condition.
  List<Award> get awards => computeAwards(_session.players);

  void promptReplay() => _moveTo(GamePhase.replayPrompt);

  /// **Play Again** — same roster (§10).
  ///
  /// Keeps names and selfies, resets lives, stats and the round counter, and
  /// re-enters at `VIBE_ROLL` because the pack rerolls. Selfies are **not**
  /// shredded: the roster is still at the table, and §4b discards on New Game.
  void replay() {
    _moveTo(GamePhase.vibeRoll);
    _session = GameSession(
      phase: GamePhase.vibeRoll,
      settings: _session.settings,
      seats: [
        for (final seat in _session.seats)
          SeatedPlayer(
            player: Player(
              id: seat.id,
              name: seat.player.name,
              seatOrder: seat.player.seatOrder,
              currentLives: _session.settings.livesPerPlayer,
            ),
            selfie: seat.selfie,
          ),
      ],
      vibePackId: _session.vibePackId,
      onboardedCount: _session.seats.length,
    );
  }

  /// **New Game** — full teardown (§4b, §10).
  ///
  /// Selfies are shredded here and nowhere else. This is the one point where
  /// the roster ends, so it is the one point where the bytes should stop being
  /// resident (§8e mitigation 3). Settings survive: a host who just spent two
  /// minutes on the topic mixer should not lose it to a different roster.
  void newGame() {
    _moveTo(GamePhase.lobby);
    for (final seat in _session.seats) {
      seat.selfie?.shred();
    }
    _session = GameSession.initial().copyWith(settings: _session.settings);
  }

  Round _requireRound() {
    final round = _session.round;
    if (round == null) throw StateError('no round in progress');
    return round;
  }
}
