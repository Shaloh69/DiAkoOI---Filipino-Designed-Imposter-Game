import 'package:diakooi/game/game_providers.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/primitives/primitives.dart';
import 'package:diakooi/ui/widgets/hold_to_reveal.dart';
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
        // PassInterstitial carries the §9f constraint banner slot. Nothing
        // fills it in the base game; Interference Mode does, in Phase 5.
        child: PassInterstitial(
          nextPlayerName: seat.player.name,
          avatar: PlayerAvatar(seat: seat, size: 140, tilt: 0.02),
          paceHint: session.settings.largeGroupMode
              // §2a — a nudge, never a timer. Thirteen people is a long lap.
              ? 'Big table. Keep clues to a few words.'
              : null,
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
        onPressed: _hasRead
            ? () {
                notifier.markRevealSeen();
                setState(() => _handedOver = false);
              }
            : null,
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: vibe.gutter),
          child: HoldToReveal(
            content: notifier.revealFor(seat.id),
            isImposter: round.isImposter(seat.id),
            onFirstReveal: () => setState(() => _hasRead = true),
          ),
        ),
      ),
    );
  }
}
