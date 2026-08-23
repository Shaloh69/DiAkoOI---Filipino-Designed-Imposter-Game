import 'package:diakooi/game/game_providers.dart';
import 'package:diakooi/game/game_session.dart';
import 'package:diakooi/theme/motion.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/primitives/primitives.dart';
import 'package:diakooi/ui/widgets/player_avatar.dart';
import 'package:diakooi/ui/widgets/vibe_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The voting grid (§7).
///
/// **Two-tap: caller first, then accused.** Not a preference — accuser-pays
/// cannot resolve without knowing who accused whom, and neither can Spread the
/// Blame or Near-Unanimous later. A single-tap grid loses the information the
/// rule is built on.
///
/// Every rule shown here is enforced in the session, not in these callbacks: a
/// self-vote and a second vote from the same caller are both refused by
/// [GameSession.canAccuse].
class VotingScreen extends ConsumerWidget {
  const VotingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibe = context.vibe;
    final session = ref.watch(gameSessionProvider);
    final notifier = ref.read(gameSessionProvider.notifier);
    final voterId = session.selectedVoterId;
    final tally = session.liveTally;

    return VibeScaffold(
      title: voterId == null ? 'Who is accusing?' : 'Who do they name?',
      subtitle: voterId == null
          ? '${session.votesRecorded} of ${session.votesExpected} recorded'
          : '${session.seatFor(voterId)!.player.name} points at…',
      footer: Column(
        children: [
          if (voterId != null)
            VibeButton(
              label: 'Never mind',
              emphasis: VibeEmphasis.quiet,
              onPressed: notifier.clearVoterSelection,
            )
          else
            VibeButton(
              label: session.allVotesRecorded
                  ? 'Reveal'
                  : 'Waiting on '
                        '${session.votesExpected - session.votesRecorded}',
              onPressed: session.allVotesRecorded ? notifier.resolve : null,
            ),
        ],
      ),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          mainAxisSpacing: vibe.gutter,
          crossAxisSpacing: vibe.gutter,
          childAspectRatio: 0.72,
        ),
        itemCount: session.seats.length,
        itemBuilder: (context, index) {
          final seat = session.seats[index];
          final hasVoted = session.hasVoted(seat.id);
          final isSelected = seat.id == voterId;

          // Selecting a caller: anyone who has not voted. Naming the accused:
          // anyone but the caller. The session decides both; this only asks.
          final selectable = voterId == null
              ? !hasVoted
              : session.canAccuse(voterId: voterId, accusedId: seat.id);

          return AnimatedOpacity(
            // Tiles dim as they stop being valid targets rather than blinking
            // out, so the grid reads as narrowing rather than as redrawing.
            duration: vibe.beats.tally,
            curve: vibe.beats.arrive,
            opacity: selectable || isSelected ? 1 : 0.35,
            child: GestureDetector(
              onTap: selectable
                  ? () {
                      if (voterId == null) {
                        notifier.selectVoter(seat.id);
                      } else {
                        notifier.recordAccusation(seat.id);
                      }
                    }
                  : null,
              child: _Tile(
                seat: seat,
                livesTotal: session.settings.livesPerPlayer,
                voteCount: tally[seat.id] ?? 0,
                isSelected: isSelected,
                hasVoted: hasVoted,
                accusers: [
                  for (final id in session.accusersOf(seat.id))
                    session.seatFor(id)!,
                ],
                onUndo: hasVoted && voterId == null
                    ? () => notifier.undoAccusation(seat.id)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.seat,
    required this.livesTotal,
    required this.voteCount,
    required this.isSelected,
    required this.hasVoted,
    required this.accusers,
    required this.onUndo,
  });

  final SeatedPlayer seat;
  final int livesTotal;
  final int voteCount;
  final bool isSelected;

  /// Whether this player has already cast their accusation, so the grid can
  /// show the ballot filling up without showing who they named.
  final bool hasVoted;
  final List<SeatedPlayer> accusers;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The tile lifts under the caller's finger. Scale rather than colour,
        // so the cue survives a pack whose accents are close together.
        AnimatedScale(
          scale: isSelected && !vibe.reduceMotion ? 1.04 : 1,
          duration: vibe.beats.micro,
          curve: vibe.beats.arrive,
          child: AnimatedContainer(
            duration: vibe.beats.tally,
            curve: vibe.beats.arrive,
            // foregroundDecoration, not decoration: a bordered Container
            // insets its child by the border width, which shrank the tile
            // enough to overflow its own column.
            foregroundDecoration: BoxDecoration(
              borderRadius: vibe.cardRadius,
              border: Border.all(
                color: isSelected ? palette.interference : Colors.transparent,
                width: 3,
              ),
            ),
            child: PlayerTile(
              name: seat.player.name,
              avatar: PlayerAvatar(seat: seat, size: 64, framed: false),
              livesRemaining: seat.player.currentLives,
              livesTotal: livesTotal,
              voteCount: voteCount,
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: AnimatedScale(
            // The ballot mark lands rather than appearing, so the host sees
            // the vote register without having to read the counter.
            scale: hasVoted ? 1 : 0,
            duration: vibe.beats.micro,
            curve: vibe.beats.arrive,
            child: GestureDetector(
              onTap: onUndo,
              child: Container(
                padding: EdgeInsets.all(vibe.gutter * 0.35),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check, size: 14, color: palette.textMuted),
              ),
            ),
          ),
        ),
        if (accusers.isNotEmpty)
          Positioned(
            left: vibe.gutter * 0.5,
            bottom: -vibe.gutter * 0.5,
            child: Row(
              children: [
                // Who pointed, stacked under the tile. Accuser-pays only means
                // something if the table can see who is exposed, so each
                // thumbnail arrives on its own beat rather than the row
                // appearing whole.
                for (var i = 0; i < accusers.length && i < 4; i++)
                  Padding(
                    padding: EdgeInsets.only(right: vibe.gutter * 0.25),
                    child: _StackedAccuser(
                      key: ValueKey(accusers[i].id),
                      seat: accusers[i],
                      index: i,
                    ),
                  ),
                if (accusers.length > 4)
                  Text(
                    '+${accusers.length - 4}',
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 11,
                      fontFamily: vibe.pack.type.body,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One accuser thumbnail, dropping into the stack under a tile.
///
/// Each is staggered by its position, so a near-unanimous vote lands as a
/// visible cascade rather than as a row that was suddenly there.
class _StackedAccuser extends StatelessWidget {
  const _StackedAccuser({required this.seat, required this.index, super.key});

  final SeatedPlayer seat;
  final int index;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final avatar = PlayerAvatar(seat: seat, size: 22, framed: false);
    if (vibe.reduceMotion) return avatar;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: vibe.beats.tally + vibe.beats.stagger * index,
      curve: vibe.beats.arrive,
      // Clamped: a bouncy pack's curve overshoots past 1 and Opacity asserts
      // on that. The overshoot belongs on the transform, not the alpha.
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * -10),
          child: child,
        ),
      ),
      child: avatar,
    );
  }
}
