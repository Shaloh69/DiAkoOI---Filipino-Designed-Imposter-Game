import 'dart:async';

import 'package:diakooi/engine/engine.dart';
import 'package:diakooi/game/game_controller.dart';
import 'package:diakooi/game/game_providers.dart';
import 'package:diakooi/game/game_session.dart';
import 'package:diakooi/profiling/frame_recorder.dart';
import 'package:diakooi/profiling/profiling_harness.dart';
import 'package:diakooi/theme/frame_budget.dart';
import 'package:diakooi/theme/motion.dart';
import 'package:diakooi/theme/vibe_providers.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/motion/handoff.dart';
import 'package:diakooi/ui/primitives/primitives.dart';
import 'package:diakooi/ui/widgets/player_avatar.dart';
import 'package:diakooi/ui/widgets/vibe_scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Whether the profiling route exists in this build.
///
/// Debug and profile only. A release build must not carry a screen that writes
/// files and drives a fake roster — and A5 wants a **profile** build anyway,
/// since a debug build's frame times measure the debugger, not the device.
bool get profilingAvailable => kDebugMode || kProfileMode;

/// The A5 profiling harness, driven with no human input.
///
/// **This produces measurements, not estimates.** Nothing here computes a
/// frame time from anything other than `FrameTiming` reported by the engine on
/// the device it is running on. ADR 0008 rejected derived numbers explicitly:
/// a figure with a caveat attached is still a figure people quote without the
/// caveat.
///
/// What it drives, and what it therefore measures:
///
/// - **reveal** — `RevealCard` swept 0→1→0 continuously at real card size.
///   That is the blur §8b names, and it is the card rather than the gesture:
///   the recogniser costs nothing and the filter is the whole risk.
/// - **handoff** — the real `PassInterstitial` inside a real `HandoffBeat`,
///   re-keyed every beat, with avatars in flight.
/// - **voteTally** — the real twenty-tile grid with ballots landing one at a
///   time, on a real roster carrying selfie-sized buffers.
/// - **thermal** — all three, ten rounds, without a pause.
class ProfilingScreen extends ConsumerStatefulWidget {
  const ProfilingScreen({super.key});

  @override
  ConsumerState<ProfilingScreen> createState() => _ProfilingScreenState();
}

class _ProfilingScreenState extends ConsumerState<ProfilingScreen>
    with TickerProviderStateMixin {
  final _recorder = FrameRecorder();
  final _reports = <FrameReport>[];

  late final AnimationController _sweep = AnimationController(
    vsync: this,
    // A full clear and close, repeatedly. Not a design timing — a sweep rate
    // for the measurement, deliberately faster than a person to keep the
    // filter under continuous load.
    duration: FrameBudget.target.budget * 60,
  );

  GameController? _game;
  ProfilingScenario? _running;
  int _voteCount = 0;
  int _handoffSeat = 0;
  int _roundsDone = 0;
  String? _writtenTo;
  String _status = 'Idle.';

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  GameController _ensureGame() {
    final bank = ref.read(wordBankProvider).value!;
    return _game ??= ProfilingHarness(wordBank: bank).buildGame()..startRound();
  }

  /// Runs one scenario for [seconds], recording every frame.
  Future<void> _run(ProfilingScenario scenario, {required int seconds}) async {
    final pack = ref.read(activeVibePackProvider)!;
    setState(() {
      _running = scenario;
      _status = 'Running ${scenario.label}…';
    });
    _ensureGame();
    await Future<void>.delayed(Duration.zero);

    _sweep.repeat(reverse: true);
    _recorder.start();

    final ticker = Timer.periodic(
      // The drive rate for whatever the scenario steps. Also not a design
      // timing: it is how often the harness pokes the UI.
      const Duration(milliseconds: 120),
      (_) => setState(() {
        _voteCount++;
        _handoffSeat++;
      }),
    );

    await Future<void>.delayed(Duration(seconds: seconds));

    ticker.cancel();
    _sweep.stop();
    final report = _recorder.stop(
      scenario: scenario.label,
      packId: pack.id,
    );

    setState(() {
      _reports.add(report);
      _running = null;
      _status = report.toString();
    });
  }

  /// Ten rounds back to back (§8c). Frame times must not degrade as the
  /// device warms, which is only visible if the run is long enough to warm it.
  Future<void> _thermal() async {
    final game = _ensureGame();
    final harness = ProfilingHarness(
      wordBank: ref.read(wordBankProvider).value!,
    );

    for (var round = 0; round < 10; round++) {
      if (!mounted) return;
      setState(() {
        _roundsDone = round + 1;
        _status = 'Thermal run: round ${round + 1} of 10';
      });
      await _run(ProfilingScenario.reveal, seconds: 6);
      await _run(ProfilingScenario.voteTally, seconds: 6);
      if (game.session.phase == GamePhase.gameSummary) break;
      await harness.playRound(
        game,
        onBeat: (_) => Future<void>.delayed(Duration.zero),
      );
    }
  }

  Future<void> _writeReport() async {
    final directory = await getApplicationDocumentsDirectory();
    final pack = ref.read(activeVibePackProvider)!;
    final file = ProfilingReportWriter(directory).write(
      reports: _reports,
      environment: {
        // Recorded as questions, not as answers. The harness cannot read the
        // device's power mode or whether Extended RAM is on, and inventing a
        // value would make an unverifiable trace look verified — see the
        // procedure in BLOCKED.md, which the human fills in beside this file.
        'buildMode': kDebugMode ? 'debug (INVALID for A5)' : 'profile/release',
        'packId': pack.id,
        'rosterSize': ProfilingHarness.rosterSize,
        'roundsCompleted': _roundsDone,
        'powerMode': 'UNRECORDED — must be default, see 06-TESTING §8c',
        'extendedRam': 'UNRECORDED — must be enabled, see 06-TESTING §8d',
        'device': 'UNRECORDED — fill in before filing this trace',
      },
    );
    if (!mounted) return;
    setState(() {
      _writtenTo = file.path;
      _status = 'Wrote ${file.path}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;
    final game = _game;

    return VibeScaffold(
      title: 'Profiling harness',
      subtitle: kDebugMode
          // Said loudly, because a debug trace looks exactly like a valid one
          // in the report file.
          ? 'DEBUG BUILD — these numbers measure the debugger, not the device. '
                'Rebuild with --profile.'
          : 'Target ${FrameBudget.target.hz}Hz · '
                '${FrameBudget.target.budgetMs}ms per frame',
      footer: Column(
        children: [
          VibeButton(
            label: 'Run all four scenarios',
            onPressed: _running != null
                ? null
                : () async {
                    await _run(ProfilingScenario.reveal, seconds: 10);
                    await _run(ProfilingScenario.handoff, seconds: 10);
                    await _run(ProfilingScenario.voteTally, seconds: 10);
                    await _thermal();
                    await _writeReport();
                  },
          ),
          SizedBox(height: vibe.gutter * 0.5),
          VibeButton(
            label: 'Write report',
            emphasis: VibeEmphasis.quiet,
            onPressed: _reports.isEmpty || _running != null
                ? null
                : _writeReport,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _status,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 13,
              fontFamily: vibe.pack.type.body,
            ),
          ),
          if (_writtenTo != null)
            SelectableText(
              _writtenTo!,
              style: TextStyle(
                color: palette.crew,
                fontSize: 12,
                fontFamily: vibe.pack.type.body,
              ),
            ),
          SizedBox(height: vibe.gutter),
          // The stage. Whatever is under test renders here at real size, so
          // the numbers are about the real widget rather than a stand-in.
          Expanded(
            child: game == null
                ? const SizedBox.shrink()
                : _Stage(
                    scenario: _running,
                    sweep: _sweep,
                    game: game,
                    voteCount: _voteCount,
                    handoffSeat: _handoffSeat,
                  ),
          ),
          for (final report in _reports)
            Text(
              report.toString(),
              style: TextStyle(
                color: report.overBudget > 0
                    ? palette.danger
                    : palette.textMuted,
                fontSize: 11,
                fontFamily: vibe.pack.type.body,
              ),
            ),
        ],
      ),
    );
  }
}

/// Renders the widget under test at the size a player sees it.
class _Stage extends StatelessWidget {
  const _Stage({
    required this.scenario,
    required this.sweep,
    required this.game,
    required this.voteCount,
    required this.handoffSeat,
  });

  final ProfilingScenario? scenario;
  final Animation<double> sweep;
  final GameController game;
  final int voteCount;
  final int handoffSeat;

  @override
  Widget build(BuildContext context) {
    final session = game.session;
    final seats = session.seats;
    final round = session.round;

    return switch (scenario) {
      null => const SizedBox.shrink(),
      ProfilingScenario.reveal || ProfilingScenario.thermal => AnimatedBuilder(
        animation: sweep,
        builder: (context, _) => Center(
          child: RevealCard(
            content: round?.word ?? 'Jollibee',
            revealProgress: sweep.value,
          ),
        ),
      ),
      ProfilingScenario.handoff => HandoffBeat(
        beatKey: handoffSeat ~/ 2,
        child: PassInterstitial(
          nextPlayerName: seats[handoffSeat % seats.length].player.name,
          avatar: HandoffHero(
            tag: 'profiling-${handoffSeat % seats.length}',
            child: PlayerAvatar(
              seat: seats[handoffSeat % seats.length],
              size: 140,
            ),
          ),
        ),
      ),
      ProfilingScenario.voteTally => _VoteGrid(
        seats: seats,
        livesTotal: session.settings.livesPerPlayer,
        landed: voteCount,
      ),
    };
  }
}

/// The twenty-tile grid A5 names, with ballots landing one at a time.
class _VoteGrid extends StatelessWidget {
  const _VoteGrid({
    required this.seats,
    required this.livesTotal,
    required this.landed,
  });

  final List<SeatedPlayer> seats;
  final int livesTotal;
  final int landed;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        mainAxisSpacing: vibe.gutter,
        crossAxisSpacing: vibe.gutter,
        childAspectRatio: 0.72,
      ),
      itemCount: seats.length,
      itemBuilder: (context, index) {
        final votes = ((landed - index) ~/ seats.length).clamp(0, 5);
        return AnimatedScale(
          scale: index == landed % seats.length ? 1.04 : 1,
          duration: vibe.beats.micro,
          curve: vibe.beats.arrive,
          child: PlayerTile(
            name: seats[index].player.name,
            avatar: PlayerAvatar(
              seat: seats[index],
              size: 64,
              framed: false,
            ),
            livesRemaining: seats[index].player.currentLives,
            livesTotal: livesTotal,
            voteCount: votes,
          ),
        );
      },
    );
  }
}
