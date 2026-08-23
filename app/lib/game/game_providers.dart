import 'package:diakooi/content/word_bank.dart';
import 'package:diakooi/engine/engine.dart';
import 'package:diakooi/game/game_controller.dart';
import 'package:diakooi/game/game_session.dart';
import 'package:diakooi/selfie/selfie_bytes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The bundled word bank, loaded once.
///
/// A `FutureProvider` over an asset read, never a network call — nothing about
/// starting a game may depend on connectivity (CLAUDE.md §Hard rules).
final wordBankProvider = FutureProvider<WordBank>((ref) => WordBank.load());

/// Randomness for every draw in the game.
///
/// Overridden with a seeded instance in tests so a whole game replays exactly;
/// never a bare `Random()` anywhere in the app.
final gameRngProvider = Provider<GameRng>(
  (ref) => SeededRng(DateTime.now().microsecondsSinceEpoch),
);

/// The live game.
///
/// Holds a [GameController] and republishes its session after each call. The
/// notifier is deliberately thin: it forwards, it does not decide. Anything
/// that looks like a rule belongs in the engine.
class GameSessionNotifier extends Notifier<GameSession> {
  late GameController _controller;

  @override
  GameSession build() {
    final bank = ref.watch(wordBankProvider).value;
    // Rebuilt when the bank arrives. Nothing can start before then, so there
    // is no state to carry across.
    _controller = GameController(
      wordBank: bank?.entries ?? const [],
      rng: ref.watch(gameRngProvider),
    );
    return _controller.session;
  }

  /// True once the word bank has loaded and a game can actually start.
  bool get isReady => ref.read(wordBankProvider).hasValue;

  T _run<T>(T Function(GameController c) action) {
    final controller = _controller;
    final result = action(controller);
    state = controller.session;
    return result;
  }

  void configure(RoomSettings settings) => _run((c) => c.configure(settings));

  void rollVibe(String packId) => _run((c) => c.rollVibe(packId));

  void beginOnboarding() => _run((c) => c.beginOnboarding());

  void addPlayer({required String name, SelfieBytes? selfie}) =>
      _run((c) => c.addPlayer(name: name, selfie: selfie));

  void startRound() => _run((c) => c.startRound());

  void beginDistribution() => _run((c) => c.beginDistribution());

  String revealFor(String playerId) => _controller.revealFor(playerId);

  void markRevealSeen() => _run((c) => c.markRevealSeen());

  // ── Interference (§9) ───────────────────────────────────────────────

  void offerItem(String playerId) => _run((c) => c.offerItem(playerId));

  void takeOfferedItem() => _run((c) => c.takeOfferedItem());

  void declineOfferedItem() => _run((c) => c.declineOfferedItem());

  void useItem({
    required String playerId,
    required ItemUsePhase phase,
    String? targetPlayerId,
  }) => _run(
    (c) => c.useItem(
      playerId: playerId,
      phase: phase,
      targetPlayerId: targetPlayerId,
    ),
  );

  void reconcileTaboo({required String playerId, required bool slipped}) =>
      _run((c) => c.reconcileTaboo(playerId: playerId, slipped: slipped));

  List<String> get tabooToReconcile => _controller.tabooToReconcile;

  void beginDiscussion() => _run((c) => c.beginDiscussion());

  void completeLap() => _run((c) => c.completeLap());

  void beginVoting() => _run((c) => c.beginVoting());

  void selectVoter(String voterId) => _run((c) => c.selectVoter(voterId));

  void clearVoterSelection() => _run((c) => c.clearVoterSelection());

  bool recordAccusation(String accusedId) =>
      _run((c) => c.recordAccusation(accusedId));

  void undoAccusation(String voterId) => _run((c) => c.undoAccusation(voterId));

  RoundResolution resolve() => _run((c) => c.resolve());

  LifeCheckResult applyLifeCheck() => _run((c) => c.applyLifeCheck());

  void serveForfeit({
    required String playerId,
    required String description,
    int remainingAfterThis = 0,
  }) => _run(
    (c) => c.serveForfeit(
      playerId: playerId,
      description: description,
      remainingAfterThis: remainingAfterThis,
    ),
  );

  GamePhase endRound() => _run((c) => c.endRound());

  void endGameEarly() => _run((c) => c.endGameEarly());

  void promptReplay() => _run((c) => c.promptReplay());

  void replay() => _run((c) => c.replay());

  void newGame() => _run((c) => c.newGame());

  List<Award> get awards => _controller.awards;

  /// Every §3 edge this game has walked. See [GameController.transitionTrail].
  List<String> get transitionTrail => _controller.transitionTrail;

  List<int> currentLapOrder() => _controller.currentLapOrder();

  bool get lapsRemaining => _controller.lapsRemaining;

  bool get rosterComplete => _controller.rosterComplete;

  bool get allRevealsSeen => _controller.allRevealsSeen;
}

final gameSessionProvider = NotifierProvider<GameSessionNotifier, GameSession>(
  GameSessionNotifier.new,
);
