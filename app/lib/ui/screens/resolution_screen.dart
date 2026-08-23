import 'package:diakooi/content/topics.dart';
import 'package:diakooi/engine/engine.dart';
import 'package:diakooi/game/game_providers.dart';
import 'package:diakooi/theme/motion.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/motion/handoff.dart';
import 'package:diakooi/ui/primitives/primitives.dart';
import 'package:diakooi/ui/widgets/player_avatar.dart';
import 'package:diakooi/ui/widgets/vibe_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The reveal, the life check and the round recap (§7, §8).
///
/// Nothing here computes anything. `resolveRound` already produced the target,
/// the deltas and the cap list, and [LifeCheck] already applied them — this
/// screen reads that out. Recomputing a total here would be a second source of
/// truth for the one thing the whole game turns on.
class ResolutionScreen extends ConsumerWidget {
  const ResolutionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibe = context.vibe;
    final palette = vibe.palette;
    final session = ref.watch(gameSessionProvider);
    final notifier = ref.read(gameSessionProvider.notifier);
    final round = session.round;
    final resolution = session.lastResolution;
    if (round == null || resolution == null) return const SizedBox.shrink();

    final target = resolution.targetPlayerId == null
        ? null
        : session.seatFor(resolution.targetPlayerId!);

    return VibeScaffold(
      title: resolution.wasWash
          ? 'Nobody takes it'
          : resolution.targetWasImposter
          ? 'Nahuli!'
          : 'Mali kayo',
      subtitle: resolution.wasWash
          // §7a: an unresolvable tie is a wash, and saying so plainly beats a
          // coin flip nobody can audit.
          ? 'The vote could not settle. No lives change this round.'
          : resolution.targetWasImposter
          ? 'The table caught an imposter.'
          : 'That was a crew member. Everyone who pointed pays.',
      footer: VibeButton(
        label: 'Life check',
        onPressed: notifier.applyLifeCheck,
      ),
      child: ListView(
        children: [
          Center(
            child: Column(
              children: [
                if (target != null)
                  _Weighted(
                    child: HandoffHero(
                      tag: handoffHeroTag(
                        playerId: target.id,
                        roundIndex: round.roundIndex,
                      ),
                      child: PlayerAvatar(seat: target, size: 160, tilt: 0.03),
                    ),
                  ),
                SizedBox(height: vibe.gutter),
                Text(
                  'The word was',
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 14,
                    fontFamily: vibe.pack.type.body,
                  ),
                ),
                Text(
                  round.word,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    fontFamily: vibe.pack.type.display,
                  ),
                ),
                Text(
                  '${TopicCatalogue.nameFor(round.topicId)} · the imposter had '
                  '"${round.imposterClue}"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 13,
                    fontFamily: vibe.pack.type.body,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: vibe.gutter * 2),
          for (var i = 0; i < session.seats.length; i++)
            _DeltaRow(
              name: session.seats[i].player.name,
              // Roles are shown now and only now — during play the grid must
              // not leak them.
              isImposter: round.isImposter(session.seats[i].id),
              delta: resolution.deltaFor(session.seats[i].id),
              wasCapped: resolution.cappedPlayerIds.contains(
                session.seats[i].id,
              ),
              index: i,
            ),
        ],
      ),
    );
  }
}

/// The target arriving with weight (Phase 5, item 5).
///
/// Overshoots slightly on a bouncy pack and settles flat on a precise one, so
/// the moment the round turns on carries the pack's own character rather than
/// a house style.
class _Weighted extends StatelessWidget {
  const _Weighted({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    if (vibe.reduceMotion) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: vibe.beats.weight,
        builder: (context, t, child) =>
            Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        child: child,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: vibe.beats.weight,
      curve: vibe.beats.arrive,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(
          // Comes in oversized and settles, which reads as landing rather
          // than as growing.
          scale: 1 + (1 - t) * (vibe.motion.overshoots ? 0.35 : 0.18),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class _DeltaRow extends StatelessWidget {
  const _DeltaRow({
    required this.name,
    required this.isImposter,
    required this.delta,
    required this.wasCapped,
    required this.index,
  });

  final String name;
  final bool isImposter;
  final int delta;
  final bool wasCapped;

  /// Position in the list, which sets the stagger. The table reads the
  /// consequences one at a time rather than all at once.
  final int index;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;

    return _Staggered(
      index: index,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: vibe.gutter * 0.4),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: ShapeDecoration(
                // Shape as well as colour, so the role reads without
                // relying on an accent pair that may be poor for
                // colour-blind players (§6).
                shape: vibe.roleShape(
                  isImposter: isImposter,
                  color: vibe.accentFor(isImposter: isImposter),
                ),
                color: vibe.accentFor(isImposter: isImposter),
              ),
            ),
            SizedBox(width: vibe.gutter),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 16,
                  fontFamily: vibe.pack.type.body,
                ),
              ),
            ),
            if (wasCapped)
              Padding(
                padding: EdgeInsets.only(right: vibe.gutter),
                child: Text(
                  'capped',
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 12,
                    fontFamily: vibe.pack.type.body,
                  ),
                ),
              ),
            Text(
              delta == 0 ? '—' : (delta > 0 ? '+$delta' : '$delta'),
              style: TextStyle(
                color: delta < 0 ? palette.danger : palette.textMuted,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: vibe.pack.type.display,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Arrives on its own beat, offset by position.
class _Staggered extends StatelessWidget {
  const _Staggered({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    if (vibe.reduceMotion) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: vibe.beats.tally + vibe.beats.stagger * index,
      curve: vibe.beats.arrive,
      // Clamped: an overshooting curve — easeOutBack on a bouncy pack —
      // returns values past 1, and Opacity asserts on those. The overshoot is
      // wanted on the transform and never on the alpha.
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset((1 - t) * 16, 0),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// The life check, and the consequence prompt for anyone who hit zero (§8).
///
/// The forfeit is **free text the player writes themselves**. §8 is explicit
/// that it is not a fixed menu: a table knows what is funny at that table, and
/// a generated list is either bland or lands badly.
class LifeCheckScreen extends ConsumerStatefulWidget {
  const LifeCheckScreen({super.key});

  @override
  ConsumerState<LifeCheckScreen> createState() => _LifeCheckScreenState();
}

class _LifeCheckScreenState extends ConsumerState<LifeCheckScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;
    final session = ref.watch(gameSessionProvider);
    final notifier = ref.read(gameSessionProvider.notifier);
    final owed = session.pendingForfeits;

    if (owed.isEmpty) {
      final last =
          session.currentRoundIndex + 1 >= session.settings.totalRounds;
      return VibeScaffold(
        title: 'Round ${session.currentRoundIndex + 1} done',
        subtitle: 'Everyone still standing. Straight on.',
        footer: Column(
          children: [
            VibeButton(
              label: last ? 'See how it went' : 'Next round',
              onPressed: notifier.endRound,
            ),
            if (!last) ...[
              SizedBox(height: vibe.gutter * 0.5),
              VibeButton(
                // §8 — the host may call it at any point. Offered here, at the
                // round boundary, because ending mid-round would cut people off
                // mid-vote.
                label: 'End the game here',
                emphasis: VibeEmphasis.quiet,
                onPressed: () => notifier
                  ..endGameEarly()
                  ..endRound(),
              ),
            ],
          ],
        ),
        child: const _LifeBoard(),
      );
    }

    final forfeit = owed.first;
    final seat = session.seatFor(forfeit.playerId)!;
    final text = _controller.text.trim();

    return VibeScaffold(
      title: '${seat.player.name} is out of lives',
      subtitle: forfeit.count > 1
          ? 'High Stakes — two forfeits this round.'
          : 'Write the consequence. You choose it, not the app.',
      footer: VibeButton(
        label: forfeit.count > 1 ? 'Served — one more' : 'Served',
        onPressed: text.isEmpty
            ? null
            : () {
                notifier.serveForfeit(
                  playerId: forfeit.playerId,
                  description: text,
                  remainingAfterThis: forfeit.count - 1,
                );
                _controller.clear();
                setState(() {});
              },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The framing §8 asks for: the portrait lands on the heavy beat and
          // the pack's danger colour breathes behind it. Nobody is being
          // punished by the app — the table is being handed a moment.
          Center(
            child: _Weighted(
              child: _DangerHalo(
                child: PlayerAvatar(seat: seat, size: 140, tilt: -0.04),
              ),
            ),
          ),
          SizedBox(height: vibe.gutter * 2),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 18,
              fontFamily: vibe.pack.type.body,
            ),
            decoration: InputDecoration(
              hintText: 'Kumanta ng…',
              hintStyle: TextStyle(color: palette.textMuted),
              filled: true,
              fillColor: palette.surface,
              border: OutlineInputBorder(
                borderRadius: vibe.cardRadius,
                borderSide: BorderSide.none,
              ),
            ),
          ),
          Text(
            'Serving it puts them back to one life. Nobody sits out — a player '
            'parked at zero has nothing left to lose.',
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

/// Lives after the round — the recap the table reads before moving on.
class _LifeBoard extends ConsumerWidget {
  const _LifeBoard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibe = context.vibe;
    final session = ref.watch(gameSessionProvider);

    return ListView(
      children: [
        for (final seat in session.seats)
          Padding(
            padding: EdgeInsets.symmetric(vertical: vibe.gutter * 0.4),
            child: Row(
              children: [
                PlayerAvatar(seat: seat, size: 36, framed: false),
                SizedBox(width: vibe.gutter),
                Expanded(
                  child: Text(
                    seat.player.name,
                    style: TextStyle(
                      color: vibe.palette.textPrimary,
                      fontSize: 16,
                      fontFamily: vibe.pack.type.body,
                    ),
                  ),
                ),
                LifePips(
                  remaining: seat.player.currentLives,
                  total: session.settings.livesPerPlayer,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A slow pulse in the pack's danger colour behind the player who owes a
/// forfeit (§8).
///
/// Loops, because this screen waits on someone typing and a one-shot would
/// leave the framing over before the moment is. Reduced motion drops the
/// pulse and keeps the colour: the signal survives, the movement does not.
class _DangerHalo extends StatefulWidget {
  const _DangerHalo({required this.child});

  final Widget child;

  @override
  State<_DangerHalo> createState() => _DangerHaloState();
}

class _DangerHaloState extends State<_DangerHalo>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller?.dispose();
    _controller = AnimationController(
      vsync: this,
      duration: context.beats.weight,
    );
    if (!context.vibe.reduceMotion) _controller!.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) {
        final t = vibe.reduceMotion ? 0.5 : _controller!.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: vibe.palette.danger.withValues(alpha: 0.18 + t * 0.22),
                blurRadius: 24 + t * 18,
                spreadRadius: 2 + t * 6,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
