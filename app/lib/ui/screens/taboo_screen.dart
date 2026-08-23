import 'package:diakooi/game/game_providers.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/widgets/interference_card.dart';
import 'package:diakooi/ui/widgets/player_avatar.dart';
import 'package:diakooi/ui/widgets/vibe_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Taboo reconciliation, at the end of the lap (§9b).
///
/// **The words are secret during the clue and public now.** That split is the
/// whole design: nobody knows what to listen for while it is being said, which
/// is where the tension lives, and the penalty is still adjudicable afterwards
/// because the table can be shown what to judge. An earlier draft gave the
/// words privately and asked the group to catch violations they could not see.
///
/// The app cannot hear the room, so the host taps what the table says out loud.
class TabooScreen extends ConsumerWidget {
  const TabooScreen({required this.playerId, super.key});

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibe = context.vibe;
    final session = ref.watch(gameSessionProvider);
    final notifier = ref.read(gameSessionProvider.notifier);
    final seat = session.seatFor(playerId);
    final words = session.roll.tabooWords[playerId] ?? const [];
    if (seat == null || words.isEmpty) return const SizedBox.shrink();

    return VibeScaffold(
      title: 'Did ${seat.player.name} slip?',
      subtitle:
          'Ask the table. They were listening — they just did not know '
          'for what.',
      footer: Row(
        children: [
          Expanded(
            child: VibeButton(
              label: 'Clean',
              emphasis: VibeEmphasis.quiet,
              onPressed: () =>
                  notifier.reconcileTaboo(playerId: playerId, slipped: false),
            ),
          ),
          SizedBox(width: vibe.gutter),
          Expanded(
            child: VibeButton(
              label: 'Slipped',
              emphasis: VibeEmphasis.danger,
              onPressed: () =>
                  notifier.reconcileTaboo(playerId: playerId, slipped: true),
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PlayerAvatar(seat: seat, size: 120, tilt: 0.03),
          SizedBox(height: vibe.gutter * 2),
          // §9e: the banned words land one at a time, like evidence going down
          // on a table. Each carries its own beat via InterferenceCard.
          for (var i = 0; i < words.length; i++) ...[
            if (i > 0) SizedBox(height: vibe.gutter),
            InterferenceCard(
              key: ValueKey(words[i]),
              title: 'Banned word ${i + 1}',
              body: words[i],
            ),
          ],
          SizedBox(height: vibe.gutter * 2),
          Text(
            'A slip costs one life, capped like any other loss.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: vibe.palette.textMuted,
              fontSize: 13,
              fontFamily: vibe.pack.type.body,
            ),
          ),
        ],
      ),
    );
  }
}
