import 'package:diakooi/engine/engine.dart';
import 'package:diakooi/theme/motion.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:flutter/material.dart';

/// The §9e interference visual language.
///
/// **Deliberately unlike the reveal card.** The word card is calm, centred and
/// low-contrast because it is read under a thumb; this is skewed, high-contrast
/// and loud because §9e says nobody should be able to confuse the two. If they
/// ever start to look alike, this is the file that has drifted.
///
/// Every colour comes from the pack's `interference` accent (§9e, §15), so the
/// same event looks different on Sayaw and on Lamig — interference is different
/// every session rather than having one house look.
class InterferenceCard extends StatefulWidget {
  const InterferenceCard({
    required this.title,
    required this.body,
    this.footnote,
    super.key,
  });

  final String title;
  final String body;

  /// The enforcement note — who polices this one.
  final String? footnote;

  @override
  State<InterferenceCard> createState() => _InterferenceCardState();
}

class _InterferenceCardState extends State<InterferenceCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller?.dispose();
    _controller = AnimationController(
      vsync: this,
      duration: context.beats.weight,
    )..forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) {
        final t = _controller!.value;
        final settle = vibe.beats.arrive.transform(t.clamp(0.0, 1.0));

        if (vibe.reduceMotion) {
          // No shake, no skew, no flash. The accent still carries the
          // "something bent" signal, which is the part that matters (§6).
          return Opacity(opacity: t.clamp(0.0, 1.0), child: child);
        }

        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.rotate(
            // Lands askew and stays slightly off true — the card never settles
            // square, which is what separates it from the word card at a
            // glance across a table.
            angle: (1 - settle) * 0.12 - 0.03,
            child: Transform.scale(scale: 0.9 + settle * 0.1, child: child),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(vibe.gutter * 2),
        decoration: ShapeDecoration(
          color: palette.interference,
          shape: BeveledRectangleBorder(
            // Chamfered, never the rounded card shape. Shape carries the
            // distinction as well as colour, so it survives a pack whose
            // accent sits close to its surface (§6).
            borderRadius: BorderRadius.circular(vibe.texture.cardRadius),
            side: BorderSide(color: palette.textPrimary, width: 3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title.toUpperCase(),
              style: TextStyle(
                color: palette.bg,
                fontSize: 13,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
                fontFamily: vibe.pack.type.body,
              ),
            ),
            SizedBox(height: vibe.gutter),
            Text(
              widget.body,
              style: TextStyle(
                color: palette.bg,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFamily: vibe.pack.type.display,
              ),
            ),
            if (widget.footnote != null) ...[
              SizedBox(height: vibe.gutter),
              Text(
                widget.footnote!,
                style: TextStyle(
                  color: palette.bg.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontFamily: vibe.pack.type.body,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Builds the private card one player sees for their §9b event.
///
/// **Private, so secret events appear here too** — a Taboo player is shown
/// their banned words, and The Fool is told they are The Fool. What §9f keeps
/// from the table is the *banner* — see
/// [InterferenceCatalogue.showsConstraintBanner], which is what decides that.
/// This card sits behind the same hold-to-reveal pass as the word, so only its
/// owner reads it.
InterferenceCard? interferenceCardFor(String eventId) {
  final event = InterferenceCatalogue.byId(eventId);
  if (event == null || event.id == InterferenceCatalogue.nothing) return null;

  return InterferenceCard(
    title: 'Interference',
    body: event.name,
    footnote: switch (event.enforcement) {
      EventEnforcement.app => event.description,
      EventEnforcement.social =>
        '${event.description} The table polices this one.',
      EventEnforcement.retroactive =>
        '${event.description} Settled at the end of the lap.',
    },
  );
}

/// The round-level flash §9e asks for: the whole table registers that the
/// round is bent before anyone picks up the phone.
class InterferenceRoundFlash extends StatelessWidget {
  const InterferenceRoundFlash({required this.modifierId, super.key});

  final String modifierId;

  @override
  Widget build(BuildContext context) {
    final event = InterferenceCatalogue.byId(modifierId);
    if (event == null) return const SizedBox.shrink();

    return InterferenceCard(
      title: 'This round',
      body: event.name,
      footnote: event.description,
    );
  }
}
