import 'dart:async';
import 'dart:typed_data';

import 'package:diakooi/content/word_bank.dart';
import 'package:diakooi/engine/engine.dart';
import 'package:diakooi/game/game_controller.dart';
import 'package:diakooi/selfie/selfie_bytes.dart';

/// The scenarios A5 names, in the order the procedure runs them.
///
/// Each maps to one thing `05-IMPLEMENTATION-PLAN.md` A5 asks about, so a
/// report can be read straight against the checklist rather than interpreted.
enum ProfilingScenario {
  /// Hold-to-reveal, sustained. §8b's named risk and the reason the frame
  /// target is still open.
  reveal,

  /// Confirm → handoff → interstitial, repeatedly. The beat that runs most
  /// often in a game.
  handoff,

  /// The 20-player grid with votes landing. A5 calls this one out by name
  /// because tile count is where a grid stops being cheap.
  voteTally,

  /// Ten rounds back to back, for the thermal run. Frame times must not
  /// degrade as the device warms (§8c).
  thermal,
}

extension ProfilingScenarioLabel on ProfilingScenario {
  String get label => switch (this) {
    ProfilingScenario.reveal => 'reveal (sustained hold)',
    ProfilingScenario.handoff => 'handoff beat',
    ProfilingScenario.voteTally => '20-player vote tally',
    ProfilingScenario.thermal => '10-round thermal run',
  };

  /// What the procedure in BLOCKED.md expects this to exercise.
  String get exercises => switch (this) {
    ProfilingScenario.reveal =>
      'the blur clearing under a thumb, at real card size (§8b)',
    ProfilingScenario.handoff =>
      'the pass beat, back to back, with avatars in flight',
    ProfilingScenario.voteTally =>
      'twenty tiles reacting as twenty ballots land',
    ProfilingScenario.thermal =>
      'ten rounds without a pause, to catch a technique that holds cold and '
          'not warm',
  };
}

/// Builds and drives a full game with no human input.
///
/// **A real roster, a real controller, real selfie-sized buffers.** A harness
/// that profiled a simplified screen would measure something nobody plays: the
/// 20-player grid is expensive precisely because it holds twenty images, and a
/// version with placeholder colours instead would come back green and mean
/// nothing.
class ProfilingHarness {
  ProfilingHarness({required this.wordBank, int seed = 20260823})
    : _rng = SeededRng(seed);

  final WordBank wordBank;
  final GameRng _rng;

  static const rosterSize = 20;

  /// Stand-in selfie bytes at the real rendition sizes.
  ///
  /// Not photographs — a 1×1 PNG scaled up would measure the wrong decode — but
  /// buffers of the size the real path produces, so the memory footprint under
  /// test matches the shipping one. §8d's "memory flat across 10 rounds" is
  /// about the size of what is resident, not its content.
  static SelfieBytes _syntheticSelfie(int seed) {
    Uint8List fill(int bytes) => Uint8List.fromList(
      List<int>.generate(bytes, (i) => (i * 31 + seed) & 0xFF),
    );
    // Roughly what a PNG at these targets weighs.
    return SelfieBytes(polaroid: fill(96 * 1024), gridTile: fill(28 * 1024));
  }

  /// A seated 20-player game, ready to deal.
  GameController buildGame({bool withSelfies = true}) {
    final settings = RoomSettings.validated(
      playerCount: rosterSize,
      topicWeights: _weightsFromBank(),
      totalRounds: 10,
    );
    final controller = GameController(wordBank: wordBank.entries, rng: _rng)
      ..configure(settings)
      ..rollVibe('tugtog')
      ..beginOnboarding();

    for (var i = 0; i < rosterSize; i++) {
      controller.addPlayer(
        name: 'Player ${i + 1}',
        selfie: withSelfies ? _syntheticSelfie(i) : null,
      );
    }
    return controller;
  }

  /// An even mix over whatever the bank can actually fill.
  ///
  /// The same renormalising the host mixer does. A harness that asked for a
  /// topic the bank cannot fill would throw at ROUND_START and profile nothing.
  List<TopicWeight> _weightsFromBank() {
    final ids = wordBank.topicIds.toList()..sort();
    if (ids.isEmpty) {
      throw StateError('the bundled word bank is empty — nothing to profile');
    }
    final mix = TopicMix.fromPreset(
      [for (final id in ids) TopicWeight(topicId: id, weightPercent: 1)],
      allTopicIds: ids,
    );
    return mix.toWeights();
  }

  /// Plays one whole round through the controller, with [onBeat] called at
  /// each point a screen would animate.
  ///
  /// Returning a `Future` from [onBeat] is what lets the driver pump frames
  /// there — the controller itself is synchronous and pure, and stays that way.
  Future<void> playRound(
    GameController controller, {
    required Future<void> Function(ProfilingScenario beat) onBeat,
  }) async {
    controller.startRound();

    for (final seat in controller.session.seats) {
      await onBeat(ProfilingScenario.handoff);
      controller.revealFor(seat.id);
      await onBeat(ProfilingScenario.reveal);
      controller.markRevealSeen();
    }

    controller.beginDiscussion();
    while (controller.lapsRemaining) {
      controller.completeLap();
    }

    controller.beginVoting();
    final seats = controller.session.seats;
    for (var i = 0; i < seats.length; i++) {
      controller
        ..selectVoter(seats[i].id)
        ..recordAccusation(seats[(i + 1) % seats.length].id);
      await onBeat(ProfilingScenario.voteTally);
    }

    controller
      ..resolve()
      ..applyLifeCheck();

    for (final forfeit in [...controller.session.pendingForfeits]) {
      controller.serveForfeit(
        playerId: forfeit.playerId,
        description: 'profiling run',
        remainingAfterThis: forfeit.count - 1,
      );
    }
    controller.endRound();
  }
}
