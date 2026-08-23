import 'package:diakooi/engine/engine.dart';
import 'package:diakooi/game/game_providers.dart';
import 'package:diakooi/game/game_session.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/motion/handoff.dart';
import 'package:diakooi/ui/primitives/primitives.dart';
import 'package:diakooi/ui/widgets/hold_to_reveal.dart';
import 'package:diakooi/ui/widgets/interference_card.dart';
import 'package:diakooi/ui/widgets/player_avatar.dart';
import 'package:diakooi/ui/widgets/vibe_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Word distribution: pass, hold, pass again (§3, §5).
///
/// The interstitial exists so the phone changes hands with nothing on screen.
/// Going straight from one player's card to the next player's card means a
/// half-second where the previous word is still up in someone else's hand.
class DistributionScreen extends ConsumerStatefulWidget {
  const DistributionScreen({super.key});

  @override
  ConsumerState<DistributionScreen> createState() => _DistributionScreenState();
}

class _DistributionScreenState extends ConsumerState<DistributionScreen> {
  bool _handedOver = false;
  bool _hasRead = false;

  /// The §9b card and any item prompt for this player, private to them.
  List<Widget> _interference(
    BuildContext context,
    GameSession session,
    String playerId,
  ) {
    final notifier = ref.read(gameSessionProvider.notifier);
    final gutter = context.vibe.gutter;
    final eventId = session.roll.eventFor(playerId);
    final tabooWords = session.roll.tabooWords[playerId] ?? const [];
    final card = eventId == null ? null : interferenceCardFor(eventId);
    if (card == null && tabooWords.isEmpty) return const [];

    return [
      SizedBox(height: gutter * 1.5),
      ?card,
      if (tabooWords.isNotEmpty) ...[
        SizedBox(height: gutter),
        // Shown only to them. The table learns the words at end of lap, which
        // is what keeps the clue tense — nobody knows what to listen for.
        InterferenceCard(
          title: 'Do not say',
          body: tabooWords.join(' · '),
          footnote: 'The table finds out at the end of the lap.',
        ),
      ],
      if (session.itemPickup?.playerId == playerId) ...[
        SizedBox(height: gutter),
        _ItemPrompt(
          pickup: session.itemPickup!,
          onTake: notifier.takeOfferedItem,
          onKeep: notifier.declineOfferedItem,
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final session = ref.watch(gameSessionProvider);
    final notifier = ref.read(gameSessionProvider.notifier);
    final round = session.round;
    if (round == null) return const SizedBox.shrink();

    final index = session.distributedCount;
    if (index >= session.seats.length) {
      return VibeScaffold(
        title: 'Everyone has their word',
        subtitle: 'Put the phone down in the middle and start talking.',
        footer: VibeButton(
          // Legal from both ROUND_START (round 1, folded into onboarding) and
          // WORD_DISTRIBUTION (every round after), so one call covers both.
          label: 'Start the roundabout',
          onPressed: notifier.beginDiscussion,
        ),
        child: const SizedBox.shrink(),
      );
    }

    final seat = session.seats[index];

    if (!_handedOver) {
      return VibeScaffold(
        footer: VibeButton(
          label: 'I am ${seat.player.name}',
          onPressed: () => setState(() {
            _handedOver = true;
            _hasRead = false;
          }),
        ),
        // The §9f constraint banner slot, filled from whatever the round is
        // carrying. Empty when Interference is off, which is the default.
        child: HandoffBeat(
          // The beat is keyed on who the phone is going to, so it fires once
          // per handoff and never on an unrelated rebuild.
          beatKey: '${round.id}-${seat.id}',
          child: PassInterstitial(
            nextPlayerName: seat.player.name,
            constraintBanner: session.activeBanners.isEmpty
                ? null
                : ConstraintBanner(
                    text: session.activeBanners.map((e) => e.name).join(' · '),
                  ),
            avatar: HandoffHero(
              tag: handoffHeroTag(
                playerId: seat.id,
                roundIndex: round.roundIndex,
              ),
              child: PlayerAvatar(seat: seat, size: 140, tilt: 0.02),
            ),
            paceHint: session.settings.largeGroupMode
                // §2a — a nudge, never a timer. Thirteen people is a long lap.
                ? 'Big table. Keep clues to a few words.'
                : null,
          ),
        ),
      );
    }

    return VibeScaffold(
      title: 'Round ${round.roundIndex + 1}',
      subtitle:
          '${index + 1} of ${session.seats.length} · '
          '${seat.player.name}',
      footer: VibeButton(
        label: 'Done — pass it on',
        onPressed: _hasRead && session.itemPickup == null
            ? () {
                notifier.markRevealSeen();
                setState(() => _handedOver = false);
              }
            : null,
      ),
      child: HandoffBeat(
        beatKey: '${round.id}-${seat.id}-card',
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: vibe.gutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HoldToReveal(
                  content: notifier.revealFor(seat.id),
                  isImposter: round.isImposter(seat.id),
                  onFirstReveal: () {
                    setState(() => _hasRead = true);
                    // Offered only once they have read the word, so the §9d
                    // prompt never competes with it for attention.
                    notifier.offerItem(seat.id);
                  },
                ),
                // The §9b card, private to this player and only after they
                // have read their word — two surprises at once is one too
                // many, and the word is the one they came for.
                if (_hasRead) ..._interference(context, session, seat.id),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The §9d use-or-lose prompt.
///
/// A second pickup never swaps silently: §9d calls a roll that appears to do
/// nothing the worst outcome for a surprise system, so the choice is put in
/// front of the player and Continue waits for it.
class _ItemPrompt extends StatelessWidget {
  const _ItemPrompt({
    required this.pickup,
    required this.onTake,
    required this.onKeep,
  });

  final ItemPickup pickup;
  final VoidCallback onTake;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return Column(
      children: [
        InterferenceCard(
          title: 'Use it or lose it',
          body: pickup.offeredItemId
              .replaceAll('item_', '')
              .replaceAll('_', ' '),
          footnote:
              'You are already holding something. Take the new one and the '
              'old one is gone.',
        ),
        SizedBox(height: vibe.gutter),
        Row(
          children: [
            Expanded(
              child: VibeButton(label: 'Take the new one', onPressed: onTake),
            ),
            SizedBox(width: vibe.gutter),
            Expanded(
              child: VibeButton(
                label: 'Keep what I have',
                emphasis: VibeEmphasis.quiet,
                onPressed: onKeep,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
