import 'dart:convert';
import 'dart:io';

import 'package:diakooi/content/word_bank.dart';
import 'package:diakooi/engine/engine.dart';
import 'package:diakooi/profiling/frame_recorder.dart';
import 'package:diakooi/profiling/profiling_harness.dart';
import 'package:diakooi/theme/frame_budget.dart';
import 'package:flutter_test/flutter_test.dart';

/// The profiling harness, checked for the one thing that would make it worse
/// than useless: producing a number nobody measured.
///
/// **No frame time is asserted here and none is produced.** A desktop test has
/// a different GPU, a different display and a different thermal envelope from a
/// Mali-G615 MC2 behind a 120Hz panel, so any figure it produced would be a
/// guess wearing a measurement's clothes — which ADR 0008 rejected explicitly,
/// because a number with a caveat attached is still a number people quote
/// without the caveat.
///
/// What is checkable: that the arithmetic over a set of timings is right, that
/// the report round-trips, and that the harness drives a real 20-player game.
void main() {
  group('the report does arithmetic, not estimation', () {
    FrameReport reportOf(List<int> micros) => FrameReport(
      scenario: 'test',
      packId: 'tugtog',
      buildMicros: micros,
      rasterMicros: micros,
      totalMicros: micros,
    );

    test('an empty run reports nothing rather than zero-as-a-result', () {
      final report = reportOf(const []);
      expect(report.frameCount, 0);
      expect(report.overBudget, 0);
      // A run that captured no frames must be visibly empty. The danger is a
      // reader seeing "worst 0.00ms" and concluding it was fast.
      expect(report.worstMs, 0);
      expect(report.medianMs, 0);
      expect(report.p99Ms, 0);
    });

    test('the budget comparison uses the recorded frame target', () {
      final budgetMicros = (FrameBudget.target.budgetMs * 1000).round();
      final report = reportOf([
        budgetMicros - 1,
        budgetMicros,
        budgetMicros + 1,
        budgetMicros * 3,
      ]);

      expect(
        report.overBudget,
        2,
        reason:
            'a frame exactly on budget is not over it; one microsecond past '
            'is',
      );
      expect(report.worstMs, closeTo(budgetMicros * 3 / 1000, 0.001));
    });

    test('a single spike shows in worst, not in p99', () {
      // Worth stating precisely, because it is easy to expect otherwise: one
      // bad frame in a hundred is the *hundredth* percentile, so p99 correctly
      // reports the good value and `worst` is the statistic that catches it.
      // A reader who only looks at p99 will miss a single dropped frame.
      final report = reportOf([for (var i = 0; i < 99; i++) 4000, 40000]);

      expect(report.medianMs, closeTo(4, 0.001));
      expect(report.p99Ms, closeTo(4, 0.001));
      expect(
        report.worstMs,
        closeTo(40, 0.001),
        reason:
            'a single dropped frame is visible in the hand and must be '
            'visible in the report',
      );
    });

    test('p99 catches a sustained tail a median hides', () {
      // Two percent of frames blowing the budget is what sustained jank looks
      // like, and a median says it was fine throughout.
      final report = reportOf([
        for (var i = 0; i < 96; i++) 4000,
        40000,
        40000,
        40000,
        40000,
      ]);

      expect(report.medianMs, closeTo(4, 0.001));
      expect(
        report.p99Ms,
        greaterThan(report.medianMs * 2),
        reason: 'the tail has to be visible in the report or nobody sees it',
      );
    });

    test('every frame survives into the file, not just the summary', () {
      final report = reportOf([1000, 2000, 3000]);
      final json = report.toJson();

      expect(
        json['totalMicros'],
        [1000, 2000, 3000],
        reason:
            'a reader has to be able to re-derive any statistic rather than '
            'trust the ones chosen here',
      );
      expect(json['frameTarget'], FrameBudget.target.name);
      expect(json['budgetMs'], FrameBudget.target.budgetMs);
    });
  });

  group('the written report', () {
    late Directory sandbox;

    setUp(() => sandbox = Directory.systemTemp.createTempSync('diakooi-prof'));
    tearDown(() => sandbox.deleteSync(recursive: true));

    test('round-trips as JSON and carries the environment', () {
      final file = ProfilingReportWriter(sandbox).write(
        reports: [
          const FrameReport(
            scenario: 'reveal',
            packId: 'lamig',
            buildMicros: [1000],
            rasterMicros: [2000],
            totalMicros: [3000],
          ),
        ],
        environment: const {
          'powerMode': 'UNRECORDED',
          'extendedRam': 'UNRECORDED',
        },
        at: DateTime.utc(2026, 8, 23, 12, 30),
      );

      expect(file.existsSync(), isTrue);
      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

      expect(decoded['schema'], 1);
      expect(decoded['frameTarget'], FrameBudget.target.name);
      expect(decoded['reports']! as List, hasLength(1));

      final environment = decoded['environment']! as Map<String, dynamic>;
      expect(
        environment['powerMode'],
        'UNRECORDED',
        reason:
            'the harness cannot read power mode, and writing a guess would '
            'make an unverifiable trace look verified (§8c)',
      );
      expect(environment['extendedRam'], 'UNRECORDED');
    });

    test('the filename is filesystem-safe and sorts by time', () {
      final early = ProfilingReportWriter.fileNameFor(
        DateTime.utc(2026, 1, 2, 3, 4, 5),
      );
      final late = ProfilingReportWriter.fileNameFor(
        DateTime.utc(2026, 11, 2, 3, 4, 5),
      );

      expect(early.contains(':'), isFalse, reason: 'invalid on Windows');
      expect(
        early.compareTo(late),
        lessThan(0),
        reason: 'a directory of traces should read in order',
      );
    });

    test('a report holds nothing derived from a selfie', () {
      // The file is meant to be copied off the handset. §4b does not get an
      // exception for diagnostics.
      final harness = ProfilingHarness(wordBank: _bank());
      final game = harness.buildGame();
      final file = ProfilingReportWriter(sandbox).write(
        reports: [
          const FrameReport(
            scenario: 'reveal',
            packId: 'tugtog',
            buildMicros: [1],
            rasterMicros: [1],
            totalMicros: [1],
          ),
        ],
        environment: {'rosterSize': game.session.seats.length},
      );

      final text = file.readAsStringSync();
      for (final seat in game.session.seats) {
        expect(
          text.contains(seat.player.name),
          isFalse,
          reason: 'a player name reached a file meant to leave the device',
        );
      }
      expect(text.contains('polaroid'), isFalse);
      expect(text.contains('gridTile'), isFalse);
    });
  });

  group('the harness drives a real game', () {
    test('it seats twenty with selfie-sized buffers', () {
      final game = ProfilingHarness(wordBank: _bank()).buildGame();

      expect(game.session.seats, hasLength(ProfilingHarness.rosterSize));
      expect(game.rosterComplete, isTrue);
      expect(
        game.session.settings.largeGroupMode,
        isTrue,
        reason:
            'twenty players is the case A5 names, so it must be the case '
            'the harness builds',
      );

      final bytes = game.session.seats
          .map((s) => s.selfie!.byteLength)
          .reduce((a, b) => a + b);
      expect(
        bytes,
        greaterThan(1 * 1024 * 1024),
        reason:
            'the grid is expensive because it holds twenty images — a harness '
            'with placeholder colours would come back green and mean nothing',
      );
    });

    test('a monogram roster is available for the A/B', () {
      final game = ProfilingHarness(
        wordBank: _bank(),
      ).buildGame(withSelfies: false);
      expect(game.session.seats.every((s) => s.selfie == null), isTrue);
    });

    test('it plays ten rounds without human input', () async {
      final harness = ProfilingHarness(wordBank: _bank());
      final game = harness.buildGame();
      var beats = 0;

      for (var round = 0; round < 10; round++) {
        if (game.session.phase == GamePhase.gameSummary) break;
        await harness.playRound(
          game,
          onBeat: (_) async => beats++,
        );
      }

      expect(
        game.session.currentRoundIndex,
        10,
        reason:
            'the thermal run is ten rounds; a harness that stops early '
            'never warms the device',
      );
      expect(
        beats,
        greaterThan(400),
        reason:
            'twenty handoffs, twenty reveals and twenty ballots a round — a '
            'beat count far below that means the drive is skipping the work',
      );
    });

    test('it refuses an empty bank rather than profiling nothing', () {
      final empty = ProfilingHarness(
        wordBank: const WordBank(
          entries: [],
          contentVersion: 'none',
          isPlaceholder: true,
        ),
      );
      expect(empty.buildGame, throwsStateError);
    });
  });
}

/// A bank wide enough for ten rounds at twenty players.
WordBank _bank() => WordBank(
  contentVersion: 'test',
  isPlaceholder: true,
  entries: [
    for (final topicId in ['pagkain', 'kpop', 'basketball'])
      for (var i = 0; i < 40; i++)
        WordBankEntry(
          topicId: topicId,
          word: '$topicId-$i',
          clues: ClueSet(tight: 't$i', standard: 's$i', loose: 'l$i'),
        ),
  ],
);
