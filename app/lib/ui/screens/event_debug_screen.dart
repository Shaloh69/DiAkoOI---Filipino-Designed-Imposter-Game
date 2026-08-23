import 'package:diakooi/engine/engine.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/widgets/interference_card.dart';
import 'package:diakooi/ui/widgets/vibe_scaffold.dart';
import 'package:flutter/material.dart';

/// A6: **every event triggerable, verified end to end.**
///
/// Debug and profile builds only — the same gate as the profiling harness. A
/// release build has no route here.
///
/// Each event renders exactly as a player would meet it: the private card for
/// a §9b event, the round flash for a §9c modifier, and the banner where §9f
/// says the table gets one. That is the point — an event verified by reading
/// the catalogue is not verified, because the catalogue is the thing that
/// might be wrong.
class EventDebugScreen extends StatefulWidget {
  const EventDebugScreen({super.key});

  @override
  State<EventDebugScreen> createState() => _EventDebugScreenState();
}

class _EventDebugScreenState extends State<EventDebugScreen> {
  InterferenceEventDefinition? _selected;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;
    final selected = _selected;

    return VibeScaffold(
      title: 'Every event (A6)',
      subtitle:
          '${InterferenceCatalogue.all.length} events · '
          '${InterferenceCatalogue.itemIds.length} items',
      onBack: () => Navigator.of(context).maybePop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (selected != null) ...[
            if (selected.category == EventCategory.roundStart)
              InterferenceRoundFlash(modifierId: selected.id)
            else
              interferenceCardFor(selected.id) ?? const SizedBox.shrink(),
            SizedBox(height: vibe.gutter),
            if (InterferenceCatalogue.showsConstraintBanner(selected))
              _BannerPreview(label: selected.name)
            else
              Text(
                InterferenceCatalogue.secretEventIds.contains(selected.id)
                    ? 'Secret — no banner. Revealed in the round recap (§9f).'
                    : 'No banner: the app enforces this one (§9f).',
                style: TextStyle(
                  color: palette.textMuted,
                  fontSize: 12,
                  fontFamily: vibe.pack.type.body,
                ),
              ),
            SizedBox(height: vibe.gutter),
          ],
          Expanded(
            child: ListView(
              children: [
                _Heading(
                  text: 'Player events',
                  count: InterferenceCatalogue.playerPickEvents.length,
                ),
                for (final event in InterferenceCatalogue.playerPickEvents)
                  _EventTile(
                    event: event,
                    selected: event.id == selected?.id,
                    onTap: () => setState(() => _selected = event),
                  ),
                _Heading(
                  text: 'Round events',
                  count: InterferenceCatalogue.roundStartEvents.length,
                ),
                for (final event in InterferenceCatalogue.roundStartEvents)
                  _EventTile(
                    event: event,
                    selected: event.id == selected?.id,
                    onTap: () => setState(() => _selected = event),
                  ),
                _Heading(
                  text: 'Items',
                  count: InterferenceCatalogue.itemIds.length,
                ),
                for (final id in InterferenceCatalogue.itemIds)
                  ListTile(
                    dense: true,
                    title: Text(
                      id.replaceAll('item_', '').replaceAll('_', ' '),
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 14,
                        fontFamily: vibe.pack.type.body,
                      ),
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

class _Heading extends StatelessWidget {
  const _Heading({required this.text, required this.count});

  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: vibe.gutter),
      child: Text(
        '${text.toUpperCase()} · $count',
        style: TextStyle(
          color: vibe.palette.textMuted,
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
          fontFamily: vibe.pack.type.body,
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.selected,
    required this.onTap,
  });

  final InterferenceEventDefinition event;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: vibe.palette.surface,
      onTap: onTap,
      title: Text(
        event.name,
        style: TextStyle(
          color: vibe.palette.textPrimary,
          fontSize: 14,
          fontFamily: vibe.pack.type.body,
        ),
      ),
      subtitle: Text(
        '${event.enforcement.name}'
        '${event.requiresRoundabout ? ' · needs a lap' : ''}'
        '${event.requiresItemSystem ? ' · needs items' : ''}'
        '${event.defaultEnabled ? '' : ' · off by default'}',
        style: TextStyle(
          color: vibe.palette.textMuted,
          fontSize: 11,
          fontFamily: vibe.pack.type.body,
        ),
      ),
    );
  }
}

class _BannerPreview extends StatelessWidget {
  const _BannerPreview({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Banner shown to the table:',
          style: TextStyle(
            color: vibe.palette.textMuted,
            fontSize: 12,
            fontFamily: vibe.pack.type.body,
          ),
        ),
        SizedBox(height: vibe.gutter * 0.5),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: vibe.gutter,
            vertical: vibe.gutter * 0.75,
          ),
          decoration: BoxDecoration(
            color: vibe.palette.interference,
            borderRadius: BorderRadius.circular(vibe.texture.cardRadius * 0.5),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: vibe.palette.bg,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: vibe.pack.type.body,
            ),
          ),
        ),
      ],
    );
  }
}
