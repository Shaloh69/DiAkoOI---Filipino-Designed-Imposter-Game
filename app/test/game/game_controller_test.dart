import 'dart:typed_data';

import 'package:diakooi/engine/engine.dart';
import 'package:diakooi/game/game_controller.dart';
import 'package:diakooi/game/game_session.dart';
import 'package:diakooi/selfie/selfie_bytes.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  group('the §3 state machine, driven end to end', () {
    test('a full game reaches the summary and back to a new lobby', () {
      final controller = seatedController(playerCount: 5, totalRounds: 2);

      playRound(controller);
      expect(controller.endRound(), GamePhase.roundStart);

      playRound(controller);
      expect(controller.endRound(), GamePhase.gameSummary);

      controller.promptReplay();
      expect(controller.session.phase, GamePhase.replayPrompt);

      controller.newGame();
      expect(controller.session.phase, GamePhase.lobby);
    });

    test('every transition the diagram draws is exercised', () {
      // The controller records every edge it walks. Sampling the phase after
      // each call is not enough — the round-end check enters and leaves in one
      // step — and "no dead ends" is worth nothing as a claim unless something
      // enumerates the diagram and checks it.
      final controller =
          GameController(wordBank: fakeBank(), rng: SeededRng(11))
            ..configure(settingsFor(playerCount: 4, totalRounds: 2))
            ..rollVibe('tugtog')
            ..beginOnboarding();
      for (var i = 0; i < 4; i++) {
        controller.addPlayer(name: 'P$i');
      }

      for (var round = 0; round < 2; round++) {
        playRound(controller);
        controller.endRound();
      }
      controller
        ..promptReplay()
        ..replay();

      // The other exit from replayPrompt, taken from a second game.
      final second = seatedController(playerCount: 4, totalRounds: 1);
      playRound(second);
      second
        ..endRound()
        ..promptReplay()
        ..newGame();

      final walked = {...controller.transitionTrail, ...second.transitionTrail};

      final all = <String>{
        for (final entry in GameMachine.transitions.entries)
          for (final to in entry.value) '${entry.key.name}->${to.name}',
      };

      // The two the base game cannot reach: both need a round with zero
      // roundabouts, which only the §9c No Roundabouts modifier produces, and
      // Interference is Phase 5. Named rather than hidden behind a subset
      // check, so Phase 5 wiring them makes this fail and be updated
      // deliberately.
      const gatedOnInterference = {
        'roundStart->votingPhase',
        'wordDistribution->votingPhase',
      };

      expect(
        all.difference(walked),
        gatedOnInterference,
        reason:
            'an edge in §3 that a normal game never walks is a dead end unless '
            'it is one of the two No Roundabouts edges',
      );
      expect(
        walked.difference(all),
        isEmpty,
        reason: 'the controller walked an edge §3 does not draw',
      );
    });

    test('the No Roundabouts edges work when a round carries them', () {
      // Phase 5 produces this state through the §9c modifier. Proving the
      // controller already handles it means Phase 5 wires an event rather than
      // adding a new code path.
      final base = seatedController(playerCount: 4)..startRound();
      final controller = GameController(
        wordBank: fakeBank(),
        rng: SeededRng(3),
        initial: base.session.copyWith(
          round: base.session.round!.copyWith(roundaboutsRequired: 0),
        ),
      )..beginDistribution();
      expect(controller.session.phase, GamePhase.votingPhase);
    });

    test('an illegal move fails loudly rather than half-applying', () {
      final controller = seatedController(playerCount: 4);
      expect(controller.beginVoting, throwsStateError);
      expect(
        controller.session.phase,
        GamePhase.playerOnboarding,
        reason: 'a rejected transition must leave the session where it was',
      );
    });
  });

  group('host setup (§2)', () {
    test('Large Group Mode engages at 13 and caps roundabouts', () {
      final small = settingsFor(playerCount: 12, roundaboutsPerRound: 3);
      final large = settingsFor(playerCount: 13, roundaboutsPerRound: 3);

      expect(small.largeGroupMode, isFalse);
      expect(small.effectiveRoundabouts, 3);
      expect(large.largeGroupMode, isTrue);
      expect(
        large.effectiveRoundabouts,
        1,
        reason: 'three laps at 13 players is thirty-nine turns (§2a)',
      );
    });

    test('a 20-player setup seats everyone and plays a round', () {
      final controller = seatedController(playerCount: 20, totalRounds: 1);
      expect(controller.rosterComplete, isTrue);
      playRound(controller);
      expect(controller.session.votesRecorded, 20);
      expect(controller.endRound(), GamePhase.gameSummary);
    });

    test('settings cannot change once the game has left the lobby', () {
      final controller = seatedController(playerCount: 4);
      expect(
        () => controller.configure(settingsFor(playerCount: 6)),
        throwsStateError,
      );
    });

    test('a player beyond the roster is refused, not silently seated', () {
      final controller = seatedController(playerCount: 4);
      expect(() => controller.addPlayer(name: 'Gatecrasher'), throwsStateError);
    });
  });

  group('voting (§7)', () {
    test('a self-vote is rejected', () {
      final controller = _atVoting()..selectVoter('p0');

      expect(controller.recordAccusation('p0'), isFalse);
      expect(controller.session.pendingVotes, isEmpty);
      expect(controller.recordAccusation('p1'), isTrue);
      expect(controller.session.pendingVotes, hasLength(1));
    });

    test('a caller cannot vote twice', () {
      final controller = _atVoting()
        ..selectVoter('p0')
        ..recordAccusation('p1')
        ..selectVoter('p0');

      expect(
        controller.session.selectedVoterId,
        isNull,
        reason: 'a caller who has already voted cannot be selected again',
      );
      expect(controller.recordAccusation('p2'), isFalse);
    });

    test('the tally and the accuser list track the recorded pairs', () {
      final controller = _atVoting()
        ..selectVoter('p0')
        ..recordAccusation('p2')
        ..selectVoter('p1')
        ..recordAccusation('p2');

      expect(controller.session.liveTally['p2'], 2);
      expect(controller.session.accusersOf('p2'), ['p0', 'p1']);
      expect(controller.session.votesRecorded, 2);
      expect(controller.session.votesExpected, 4);
      expect(controller.session.allVotesRecorded, isFalse);
    });

    test('an undone accusation frees the caller to vote again', () {
      final controller = _atVoting()
        ..selectVoter('p0')
        ..recordAccusation('p1')
        ..undoAccusation('p0')
        ..selectVoter('p0');

      expect(controller.recordAccusation('p2'), isTrue);
      expect(controller.session.liveTally, {'p2': 1});
    });

    test('resolving before every vote is in is refused', () {
      final controller = _atVoting()
        ..selectVoter('p0')
        ..recordAccusation('p1');

      expect(
        controller.resolve,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('1 of 4'),
          ),
        ),
      );
      expect(
        controller.session.phase,
        GamePhase.votingPhase,
        reason: 'a refused resolve must not advance the phase',
      );
    });

    test('the Mayor breaks a tie through the engine, not the UI', () {
      // Two each on two candidates. The Mayor is at the table, so whichever
      // side they backed is the one that takes the hit (§7a).
      final controller = _atVoting(seed: 5);
      final mayor = controller.session.mayorPlayerId!;
      final others = controller.session.seats
          .map((s) => s.id)
          .where((id) => id != mayor)
          .toList();

      controller
        ..selectVoter(mayor)
        ..recordAccusation(others[0])
        ..selectVoter(others[0])
        ..recordAccusation(others[1])
        ..selectVoter(others[1])
        ..recordAccusation(others[0])
        ..selectVoter(others[2])
        ..recordAccusation(others[1]);

      final resolution = controller.resolve();
      expect(
        resolution.targetPlayerId,
        others[0],
        reason: 'a 2-2 tie resolves to the side the Mayor backed (§7a)',
      );
      expect(resolution.wasWash, isFalse);
    });
  });

  group('resolution and life check (§7, §8)', () {
    test('accusing a crew member costs the accuser a life', () {
      final controller = seatedController(playerCount: 5, totalRounds: 1)
        ..startRound();
      final round = controller.session.round!;
      final imposter = round.imposterPlayerIds.first;
      final crew = controller.session.seats
          .map((s) => s.id)
          .firstWhere((id) => !round.isImposter(id));

      controller
        ..beginDistribution()
        ..beginDiscussion();
      while (controller.lapsRemaining) {
        controller.completeLap();
      }
      controller.beginVoting();
      for (final seat in controller.session.seats) {
        controller
          ..selectVoter(seat.id)
          ..recordAccusation(seat.id == crew ? imposter : crew);
      }

      final resolution = controller.resolve();
      expect(resolution.targetPlayerId, crew);
      expect(resolution.targetWasImposter, isFalse);

      controller.applyLifeCheck();
      for (final seat in controller.session.seats) {
        if (seat.id == crew || seat.id == imposter) continue;
        expect(
          seat.player.currentLives,
          lessThan(3),
          reason: 'accuser-pays: backing a wrong target costs a life (§7)',
        );
      }
    });

    test('a served forfeit is logged as free text and restores one life', () {
      final base = seatedController(playerCount: 4, totalRounds: 1);
      final controller = GameController(
        wordBank: fakeBank(),
        rng: SeededRng(2),
        initial: base.session.copyWith(
          seats: [
            for (final seat in base.session.seats)
              if (seat.id == 'p0')
                seat.copyWith(player: seat.player.copyWith(currentLives: 0))
              else
                seat,
          ],
        ),
      )..serveForfeit(playerId: 'p0', description: 'Kumanta ng Pusong Bato');

      final player = controller.session.seatFor('p0')!.player;
      expect(player.currentLives, 1);
      expect(
        player.consequenceLog.single.description,
        'Kumanta ng Pusong Bato',
      );
      expect(player.forfeitsServed, 1);
      expect(controller.session.pendingForfeits, isEmpty);
    });

    test('the early-end threshold ends the game before the round limit', () {
      final controller = seatedController(
        playerCount: 4,
        settings: settingsFor(
          playerCount: 4,
          totalRounds: 8,
          earlyEndConsequenceThreshold: 1,
        ),
      );
      playRound(controller);
      controller.serveForfeit(playerId: 'p0', description: 'Sayaw');
      expect(controller.endRound(), GamePhase.gameSummary);
    });

    test('the host can call the game at the next round end', () {
      final controller = seatedController(playerCount: 4, totalRounds: 8);
      playRound(controller);
      controller.endGameEarly();
      expect(controller.endRound(), GamePhase.gameSummary);
    });
  });

  group('replay vs new game (§4b, §10)', () {
    test('replay keeps the roster and its selfies, and resets lives', () {
      final selfie = _selfie();
      final controller = _threeUp(selfie);

      playRound(controller);
      controller
        ..endRound()
        ..promptReplay()
        ..replay();

      expect(controller.session.phase, GamePhase.vibeRoll);
      expect(controller.session.seats.map((s) => s.player.name), [
        'Ana',
        'Ben',
        'Cy',
      ]);
      expect(
        controller.session.seats.every((s) => s.player.currentLives == 3),
        isTrue,
      );
      expect(controller.session.currentRoundIndex, 0);
      expect(controller.session.usedWords, isEmpty);
      expect(
        selfie.isShredded,
        isFalse,
        reason:
            'the roster is still at the table — §4b discards on New Game, not '
            'on Play Again',
      );
    });

    test('new game shreds every selfie and clears the roster', () {
      final selfie = _selfie();
      final controller = _threeUp(selfie);

      playRound(controller);
      controller
        ..endRound()
        ..promptReplay()
        ..newGame();

      expect(controller.session.seats, isEmpty);
      expect(selfie.isShredded, isTrue);
      expect(() => selfie.polaroid, throwsStateError);
    });
  });

  group('awards (§10)', () {
    test('an award nobody qualifies for is omitted, not handed out', () {
      final awards = computeAwards([
        const Player(id: 'p0', name: 'Ana', seatOrder: 0, currentLives: 3),
        const Player(id: 'p1', name: 'Ben', seatOrder: 1, currentLives: 3),
      ]);
      expect(
        awards,
        isEmpty,
        reason:
            'nobody accused, bluffed, served a forfeit or was voted for — an '
            'arbitrary tie-break would read as a bug at the table',
      );
    });

    test('a played game produces awards backed by real stats', () {
      final controller = seatedController(playerCount: 5, totalRounds: 2);
      playRound(controller);
      controller.endRound();
      playRound(controller);
      controller.endRound();
      final awards = controller.awards;
      expect(awards, isNotEmpty);
      for (final award in awards) {
        expect(
          controller.session.seatFor(award.playerId),
          isNotNull,
          reason: 'an award must name someone at the table',
        );
      }
      expect(
        awards.map((a) => a.id).toSet().length,
        awards.length,
        reason: 'no award is issued twice',
      );

      final totalVotes = controller.session.players.fold<int>(
        0,
        (sum, p) => sum + p.stats.votesReceived,
      );
      expect(
        totalVotes,
        10,
        reason: 'five ballots across two rounds, all recorded',
      );
    });

    test('rounds as imposter accrue every round, caught or not', () {
      final controller = seatedController(playerCount: 5, totalRounds: 2);
      playRound(controller);
      controller.endRound();
      playRound(controller);

      final imposterRounds = controller.session.players.fold<int>(
        0,
        (sum, p) => sum + p.stats.roundsAsImposter,
      );
      expect(imposterRounds, 2, reason: 'one imposter per round, two rounds');
    });
  });

  group('turn order (§6a)', () {
    test('the lap order rotates within a round and between rounds', () {
      final controller = seatedController(playerCount: 4, totalRounds: 2)
        ..startRound()
        ..beginDistribution()
        ..beginDiscussion();

      final firstLap = controller.currentLapOrder();
      controller.completeLap();
      final secondLap = controller.currentLapOrder();

      expect(
        firstLap.last,
        isNot(secondLap.last),
        reason: 'the same seat must not close both laps of a round (§6a)',
      );
      expect(firstLap.toSet(), secondLap.toSet());
      expect(firstLap, hasLength(4));
    });
  });
}

GameController _atVoting({int seed = 7}) {
  final controller = seatedController(playerCount: 4, seed: seed)
    ..startRound()
    ..beginDistribution()
    ..beginDiscussion();
  while (controller.lapsRemaining) {
    controller.completeLap();
  }
  return controller..beginVoting();
}

SelfieBytes _selfie() =>
    SelfieBytes(polaroid: Uint8List(8), gridTile: Uint8List(4));

GameController _threeUp(SelfieBytes selfie) =>
    GameController(wordBank: fakeBank(), rng: SeededRng(9))
      ..configure(settingsFor(playerCount: 3, totalRounds: 1))
      ..rollVibe('tugtog')
      ..beginOnboarding()
      ..addPlayer(name: 'Ana', selfie: selfie)
      ..addPlayer(name: 'Ben')
      ..addPlayer(name: 'Cy');
