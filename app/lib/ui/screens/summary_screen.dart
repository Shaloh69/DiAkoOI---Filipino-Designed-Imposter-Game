import 'package:diakooi/game/game_providers.dart';
import 'package:diakooi/game/game_session.dart';
import 'package:diakooi/theme/vibe_providers.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/widgets/player_avatar.dart';
import 'package:diakooi/ui/widgets/vibe_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The end screen (§10).
///
/// **No winner.** The awards are cosmetic and there is deliberately no hard win
/// condition — one would fight the forfeit loop, which is the actual engine of
/// the evening. An award nobody qualifies for is simply absent rather than
/// handed to someone on an invisible tie-break.
class SummaryScreen extends ConsumerWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibe = context.vibe;
    final palette = vibe.palette;
    final session = ref.watch(gameSessionProvider);
    final notifier = ref.read(gameSessionProvider.notifier);
    final awards = notifier.awards;
    final forfeits = session.players.fold<int>(
      0,
      (sum, p) => sum + p.consequenceLog.length,
    );

    return VibeScaffold(
      title: 'Tapos na',
      subtitle:
          '${session.currentRoundIndex} rounds · $forfeits consequences served',
      footer: VibeButton(
        label: 'What next?',
        onPressed: notifier.promptReplay,
      ),
      child: ListView(
        children: [
          if (awards.isEmpty)
            Text(
              'Short game — nothing to hand out.',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 15,
                fontFamily: vibe.pack.type.body,
              ),
            ),
          for (final award in awards)
            _AwardCard(award: award, seat: session.seatFor(award.playerId)!),
          SizedBox(height: vibe.gutter * 2),
          Text(
            'CONSEQUENCE LOG',
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              fontFamily: vibe.pack.type.body,
            ),
          ),
          SizedBox(height: vibe.gutter * 0.5),
          for (final player in session.players)
            for (final entry in player.consequenceLog)
              Padding(
                padding: EdgeInsets.symmetric(vertical: vibe.gutter * 0.25),
                child: Text(
                  'R${entry.roundIndex + 1} · ${player.name} — '
                  '${entry.description}',
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 14,
                    fontFamily: vibe.pack.type.body,
                  ),
                ),
              ),
          if (forfeits == 0)
            Text(
              'Nobody ran out of lives. Suspiciously polite.',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 14,
                fontFamily: vibe.pack.type.body,
              ),
            ),
        ],
      ),
    );
  }
}

class _AwardCard extends StatelessWidget {
  const _AwardCard({required this.award, required this.seat});

  final Award award;
  final SeatedPlayer seat;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;

    return Container(
      margin: EdgeInsets.only(bottom: vibe.gutter),
      padding: EdgeInsets.all(vibe.gutter),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: vibe.cardRadius,
      ),
      child: Row(
        children: [
          PlayerAvatar(seat: seat, size: 56, framed: false),
          SizedBox(width: vibe.gutter),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  award.title,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: vibe.pack.type.display,
                  ),
                ),
                Text(
                  seat.player.name,
                  style: TextStyle(
                    color: palette.crew,
                    fontSize: 15,
                    fontFamily: vibe.pack.type.body,
                  ),
                ),
                Text(
                  award.detail,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 13,
                    fontFamily: vibe.pack.type.body,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Play Again or New Game (§10, §4b).
///
/// The distinction matters beyond convenience: **Play Again keeps the roster
/// and its selfies; New Game tears both down and shreds the bytes.** That is
/// the only point in the app where a selfie stops being resident, so the choice
/// is presented plainly rather than as a back arrow.
class ReplayPromptScreen extends ConsumerWidget {
  const ReplayPromptScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibe = context.vibe;
    final palette = vibe.palette;
    final session = ref.watch(gameSessionProvider);
    final notifier = ref.read(gameSessionProvider.notifier);

    return VibeScaffold(
      title: 'Ulit?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          VibeButton(
            label: 'Play again — same ${session.seats.length}',
            onPressed: () {
              // Recording the pack that just played is what makes the reroll a
              // reroll: §4's no-repeat rule excludes the last one, so the
              // history has to be written before the draw runs again.
              final packId = session.vibePackId;
              if (packId != null) {
                ref.read(vibeHistoryProvider.notifier).record(packId);
              }
              notifier.replay();
            },
          ),
          SizedBox(height: vibe.gutter * 0.5),
          Text(
            'Same names and faces, lives reset, and a new Vibe Pack.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 13,
              fontFamily: vibe.pack.type.body,
            ),
          ),
          SizedBox(height: vibe.gutter * 2),
          VibeButton(
            label: 'New game',
            emphasis: VibeEmphasis.quiet,
            onPressed: () {
              final packId = session.vibePackId;
              if (packId != null) {
                ref.read(vibeHistoryProvider.notifier).record(packId);
              }
              notifier.newGame();
            },
          ),
          SizedBox(height: vibe.gutter * 0.5),
          Text(
            'Clears the table. Every photo is discarded.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 13,
              fontFamily: vibe.pack.type.body,
            ),
          ),
        ],
      ),
    );
  }
}
