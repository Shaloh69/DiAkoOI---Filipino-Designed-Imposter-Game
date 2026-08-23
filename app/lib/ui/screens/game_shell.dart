import 'package:diakooi/content/word_bank.dart';
import 'package:diakooi/engine/engine.dart';
import 'package:diakooi/game/game_providers.dart';
import 'package:diakooi/profiling/profiling_screen.dart';
import 'package:diakooi/theme/vibe_providers.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/screens/discussion_screen.dart';
import 'package:diakooi/ui/screens/distribution_screen.dart';
import 'package:diakooi/ui/screens/host_setup_screen.dart';
import 'package:diakooi/ui/screens/onboarding_screen.dart';
import 'package:diakooi/ui/screens/resolution_screen.dart';
import 'package:diakooi/ui/screens/summary_screen.dart';
import 'package:diakooi/ui/screens/voting_screen.dart';
import 'package:diakooi/ui/widgets/vibe_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The whole game, as one screen that follows the §3 phase.
///
/// **There is no navigation stack.** A pass-and-play game is a state machine
/// with one device, and a router would let a back gesture return to a screen
/// showing a word that has already been passed on. The system back button is
/// intercepted here instead, and each phase says what backing out means — which
/// is usually nothing.
class GameShell extends ConsumerWidget {
  const GameShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pack = ref.watch(activeVibePackProvider);
    final bank = ref.watch(wordBankProvider).value;
    // Nothing starts until both are in memory. Both are asset reads, so this
    // is a frame or two, never a network wait (CLAUDE.md §Hard rules).
    if (pack == null || bank == null) return const _Booting();

    return Theme(
      data: VibeTheme.materialThemeFor(
        pack,
        reduceMotion: MediaQuery.disableAnimationsOf(context),
      ),
      child: _Phase(bank: bank),
    );
  }
}

class _Phase extends ConsumerWidget {
  const _Phase({required this.bank});

  final WordBank bank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameSessionProvider);
    final notifier = ref.read(gameSessionProvider.notifier);
    final pack = ref.watch(activeVibePackProvider);

    return PopScope(
      // Backing out of a phase would show a word the table has moved past, so
      // the gesture is swallowed. Ending a game is a deliberate choice made on
      // the screen that offers it.
      canPop: false,
      child: switch (session.phase) {
        GamePhase.lobby => HostSetupScreen(
          initial: session.settings,
          availableTopicIds: bank.topicIds,
          // Debug and profile builds only — see [profilingAvailable]. A release
          // build has no route to it at all.
          onOpenProfiling: profilingAvailable
              ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProfilingScreen(),
                  ),
                )
              : null,
          onStart: (settings) => notifier
            ..configure(settings)
            ..rollVibe(pack!.id),
        ),
        // The pack was drawn before this screen and the theme is already up —
        // §3 puts VIBE_ROLL before onboarding so the table sees the night's
        // look from screen one rather than after the phone has gone round.
        GamePhase.vibeRoll => _VibeRoll(onContinue: notifier.beginOnboarding),
        GamePhase.playerOnboarding => const OnboardingScreen(),

        // §3 folds round 1's word distribution into onboarding, so round 1
        // has no WORD_DISTRIBUTION phase — the cards go round while the phase
        // is still ROUND_START. Later rounds get the deal beat below, because
        // the phone has come back to the host and the table needs a moment.
        GamePhase.roundStart =>
          session.round?.roundIndex == session.currentRoundIndex
              ? const DistributionScreen()
              : _RoundStart(
                  onContinue: () => notifier
                    ..startRound()
                    ..beginDistribution(),
                ),
        GamePhase.wordDistribution => const DistributionScreen(),
        GamePhase.discussionPhase => const DiscussionScreen(),
        GamePhase.votingPhase => const VotingScreen(),
        GamePhase.resolution => const ResolutionScreen(),
        GamePhase.lifeCheck => const LifeCheckScreen(),
        // ROUND_END_CHECK never renders: endRound() enters and leaves it in one
        // step. A screen here would be a beat with nothing on it.
        GamePhase.roundEndCheck => const _Booting(),
        GamePhase.gameSummary => const SummaryScreen(),
        GamePhase.replayPrompt => const ReplayPromptScreen(),
      },
    );
  }
}

/// Between rounds: the phone goes back to the host before the next deal.
class _RoundStart extends ConsumerWidget {
  const _RoundStart({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameSessionProvider);

    return VibeScaffold(
      title: 'Round ${session.currentRoundIndex + 1}',
      subtitle: 'New word, new imposter. Only the lives carry over.',
      footer: VibeButton(label: 'Deal', onPressed: onContinue),
      child: const SizedBox.shrink(),
    );
  }
}

/// The pack reveal (§3, §4).
class _VibeRoll extends ConsumerWidget {
  const _VibeRoll({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibe = context.vibe;
    final palette = vibe.palette;
    final pack = ref.watch(activeVibePackProvider);

    return VibeScaffold(
      footer: VibeButton(label: 'Start', onPressed: onContinue),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Tonight's vibe",
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 15,
              fontFamily: vibe.pack.type.body,
            ),
          ),
          SizedBox(height: vibe.gutter),
          Text(
            pack?.displayName ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 40,
              fontWeight: FontWeight.bold,
              fontFamily: vibe.pack.type.display,
            ),
          ),
          SizedBox(height: vibe.gutter),
          Text(
            pack?.watermark.label ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 15,
              fontFamily: vibe.pack.type.body,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown while the packs and the word bank load from the asset bundle.
///
/// Asset reads, never a network call — nothing about starting a game may wait
/// on connectivity (CLAUDE.md §Hard rules).
class _Booting extends StatelessWidget {
  const _Booting();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
