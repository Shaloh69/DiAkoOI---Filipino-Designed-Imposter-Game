import 'dart:async';

import 'package:diakooi/content/topics.dart';
import 'package:diakooi/game/game_providers.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/primitives/primitives.dart';
import 'package:diakooi/ui/screens/taboo_screen.dart';
import 'package:diakooi/ui/widgets/player_avatar.dart';
import 'package:diakooi/ui/widgets/vibe_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The roundabout (§6).
///
/// The phone sits in the middle. It shows whose turn it is and how many laps
/// are left, and otherwise stays out of the way — the game is the conversation,
/// and a screen that demands attention during it is competing with the thing it
/// exists to support.
class DiscussionScreen extends ConsumerStatefulWidget {
  const DiscussionScreen({super.key});

  @override
  ConsumerState<DiscussionScreen> createState() => _DiscussionScreenState();
}

class _DiscussionScreenState extends ConsumerState<DiscussionScreen> {
  int _speaker = 0;
  Timer? _ticker;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// The soft clue timer (§6). Off by default, and a nudge when it is on —
  /// nothing happens when it runs out. It exists for tables that stall, not to
  /// turn a conversation into a drill.
  void _restartTimer(int? seconds) {
    _ticker?.cancel();
    if (seconds == null) return;
    _secondsLeft = seconds;
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _secondsLeft = _secondsLeft > 0 ? _secondsLeft - 1 : 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;
    final session = ref.watch(gameSessionProvider);
    final notifier = ref.read(gameSessionProvider.notifier);
    final round = session.round;
    if (round == null) return const SizedBox.shrink();

    // §9b: Taboo is settled at the end of the lap, before the next one and
    // before voting. The screen takes over until every one is adjudicated.
    final pending = notifier.tabooToReconcile;
    if (pending.isNotEmpty && !notifier.lapsRemaining) {
      return TabooScreen(playerId: pending.first);
    }

    final order = notifier.currentLapOrder();
    final seats = session.seats;
    final speaking = seats[order[_speaker % order.length]];
    final lapNumber = round.roundaboutsCompleted + 1;
    final isLastSpeaker = _speaker >= order.length - 1;
    final nextName = seats[order[(_speaker + 1) % order.length]].player.name;
    final timerSeconds = session.settings.clueTimerSeconds;

    return VibeScaffold(
      title: TopicCatalogue.nameFor(round.topicId),
      banner: session.activeBanners.isEmpty
          ? null
          : ConstraintBanner(
              text: session.activeBanners.map((e) => e.name).join(' · '),
            ),
      subtitle:
          'Roundabout $lapNumber of ${round.roundaboutsRequired} · '
          'one word each',
      footer: Column(
        children: [
          VibeButton(
            label: isLastSpeaker
                ? (lapNumber < round.roundaboutsRequired
                      ? 'Lap done — go again'
                      : 'Everyone has spoken')
                : 'Next: $nextName',
            onPressed: () {
              if (!isLastSpeaker) {
                setState(() => _speaker++);
                _restartTimer(timerSeconds);
                return;
              }
              notifier.completeLap();
              if (notifier.lapsRemaining) {
                setState(() => _speaker = 0);
                _restartTimer(timerSeconds);
              } else {
                _ticker?.cancel();
                notifier.beginVoting();
              }
            },
          ),
          SizedBox(height: vibe.gutter * 0.5),
          VibeButton(
            label: 'Skip to the vote',
            emphasis: VibeEmphasis.quiet,
            onPressed: () {
              _ticker?.cancel();
              while (notifier.lapsRemaining) {
                notifier.completeLap();
              }
              notifier.beginVoting();
            },
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PlayerAvatar(seat: speaking, size: 160, tilt: -0.02),
          SizedBox(height: vibe.gutter * 1.5),
          Text(
            speaking.player.name,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              fontFamily: vibe.pack.type.display,
            ),
          ),
          SizedBox(height: vibe.gutter * 0.5),
          Text(
            'Say one word about it. Not the word itself.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 15,
              fontFamily: vibe.pack.type.body,
            ),
          ),
          if (timerSeconds != null) ...[
            SizedBox(height: vibe.gutter * 1.5),
            Text(
              _secondsLeft > 0 ? '$_secondsLeft' : 'anytime now',
              style: TextStyle(
                color: _secondsLeft > 0
                    ? palette.textMuted
                    : palette.interference,
                fontSize: 20,
                fontFamily: vibe.pack.type.display,
              ),
            ),
          ],
          SizedBox(height: vibe.gutter * 2),
          _LapProgress(
            speaker: _speaker,
            total: order.length,
            lap: lapNumber,
            laps: round.roundaboutsRequired,
          ),
        ],
      ),
    );
  }
}

class _LapProgress extends StatelessWidget {
  const _LapProgress({
    required this.speaker,
    required this.total,
    required this.lap,
    required this.laps,
  });

  final int speaker;
  final int total;
  final int lap;
  final int laps;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;

    return Semantics(
      label: 'Speaker ${speaker + 1} of $total, roundabout $lap of $laps',
      child: Wrap(
        spacing: vibe.gutter * 0.5,
        runSpacing: vibe.gutter * 0.5,
        alignment: WrapAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= speaker ? palette.crew : palette.surfaceAlt,
              ),
            ),
        ],
      ),
    );
  }
}
