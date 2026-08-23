import 'package:diakooi/game/game_providers.dart';
import 'package:diakooi/selfie/selfie_bytes.dart';
import 'package:diakooi/selfie/selfie_capture.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/primitives/primitives.dart';
import 'package:diakooi/ui/widgets/player_avatar.dart';
import 'package:diakooi/ui/widgets/selfie_capture_view.dart';
import 'package:diakooi/ui/widgets/vibe_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Onboarding: name, then a selfie or a monogram (§4).
///
/// One player at a time, the phone passed along. The round-1 reveal follows
/// immediately from the same pass rather than starting a second lap of the
/// table — §3 folds it into onboarding for exactly that reason.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { name, selfie, confirm }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  _Step _step = _Step.name;
  SelfieBytes? _pending;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _name => _nameController.text.trim();

  void _onSelfieDone(SelfieOutcome outcome) => setState(() {
    _pending = outcome is SelfieCaptured ? outcome.bytes : null;
    _step = _Step.confirm;
  });

  void _seat() {
    ref
        .read(gameSessionProvider.notifier)
        .addPlayer(
          name: _name,
          selfie: _pending,
        );
    setState(() {
      _nameController.clear();
      _pending = null;
      _step = _Step.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;
    final session = ref.watch(gameSessionProvider);
    final notifier = ref.read(gameSessionProvider.notifier);
    final seatNumber = session.seats.length + 1;
    final total = session.settings.playerCount;

    if (notifier.rosterComplete) {
      // Every seat filled. Round 1 draws immediately; §3 hands the word out on
      // the same pass rather than sending the phone round twice.
      return VibeScaffold(
        title: 'Everyone is in',
        subtitle: '$total players. Round 1 starts with the next pass.',
        footer: VibeButton(
          // Draws the round but stays in ROUND_START: §3 gives round 1 no
          // WORD_DISTRIBUTION phase because the cards go round on this same
          // pass, not on a second lap of the table.
          label: 'Deal the first round',
          onPressed: notifier.startRound,
        ),
        child: const _Roster(),
      );
    }

    return VibeScaffold(
      title: 'Player $seatNumber of $total',
      subtitle: switch (_step) {
        _Step.name => 'Pass the phone. Type your name.',
        _Step.selfie => 'Look at the camera, or skip it.',
        _Step.confirm => 'That is you for the rest of the game.',
      },
      child: switch (_step) {
        _Step.name => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 18,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_name.isNotEmpty) setState(() => _step = _Step.selfie);
              },
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 22,
                fontFamily: vibe.pack.type.display,
              ),
              decoration: InputDecoration(
                hintText: 'Palayaw',
                hintStyle: TextStyle(color: palette.textMuted),
                filled: true,
                fillColor: palette.surface,
                border: OutlineInputBorder(
                  borderRadius: vibe.cardRadius,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const Spacer(),
            VibeButton(
              label: 'Next',
              onPressed: _name.isEmpty
                  ? null
                  : () => setState(() => _step = _Step.selfie),
            ),
          ],
        ),
        _Step.selfie => SelfieCaptureView(
          playerName: _name,
          onDone: _onSelfieDone,
        ),
        _Step.confirm => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: PolaroidFrame(
                  caption: _name,
                  size: 200,
                  tilt: -0.03,
                  child: _pending == null
                      ? MonogramBadge(name: _name, size: 200)
                      : Image.memory(_pending!.polaroid, fit: BoxFit.cover),
                ),
              ),
            ),
            VibeButton(label: 'Looks good', onPressed: _seat),
            SizedBox(height: vibe.gutter * 0.5),
            VibeButton(
              label: 'Take it again',
              emphasis: VibeEmphasis.quiet,
              onPressed: () => setState(() {
                _pending?.shred();
                _pending = null;
                _step = _Step.selfie;
              }),
            ),
          ],
        ),
      },
    );
  }
}

/// Who is already seated, so the table can see it is being counted correctly.
class _Roster extends ConsumerWidget {
  const _Roster();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibe = context.vibe;
    final session = ref.watch(gameSessionProvider);

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisSpacing: vibe.gutter,
        crossAxisSpacing: vibe.gutter,
        childAspectRatio: 0.78,
      ),
      itemCount: session.seats.length,
      itemBuilder: (context, index) => PlayerAvatar(
        seat: session.seats[index],
        size: 72,
        showCaption: true,
      ),
    );
  }
}
