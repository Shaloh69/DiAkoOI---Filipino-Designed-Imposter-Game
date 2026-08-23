import 'package:diakooi/engine/engine.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:flutter/material.dart';

/// The §9a toggle tree: master switch, three sub-toggles, per-event checklists.
///
/// **Nothing fires unless its specific toggle is on**, and the three levels are
/// independent by design — §9a wants a host able to allow "+1 life" while
/// disabling "steal a life", which a single on/off cannot express.
///
/// Off by default, all the way down. Interference is the mode you opt into.
class InterferenceSetup extends StatelessWidget {
  const InterferenceSetup({
    required this.settings,
    required this.onChanged,
    super.key,
  });

  final InterferenceSettings settings;
  final ValueChanged<InterferenceSettings> onChanged;

  /// Ids a host has explicitly allowed.
  ///
  /// The stored list is "empty means every default-enabled event", which keeps
  /// a fresh room small to serialise. Expanding it the moment a host touches a
  /// checkbox is what makes the checklist behave the way it looks.
  Set<String> get _explicit {
    if (settings.enabledEventIds.isNotEmpty) {
      return settings.enabledEventIds.toSet();
    }
    return {
      for (final event in [
        ...InterferenceCatalogue.playerPickEvents,
        ...InterferenceCatalogue.roundStartEvents,
      ])
        if (event.defaultEnabled) event.id,
    };
  }

  void _toggleEvent(String id, {required bool on}) {
    final next = _explicit;
    if (on) {
      next.add(id);
    } else {
      next.remove(id);
    }
    onChanged(settings.copyWith(enabledEventIds: next.toList()..sort()));
  }

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;
    final enabled = _explicit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          value: settings.enabled,
          onChanged: (on) => onChanged(settings.copyWith(enabled: on)),
          activeThumbColor: palette.interference,
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Interference Mode',
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: vibe.pack.type.display,
            ),
          ),
          subtitle: Text(
            settings.enabled
                // §3, §9f: round 1 is always clean. Said here rather than
                // discovered, so a host who turns this on and sees nothing
                // happen in round 1 knows why.
                ? 'Never fires in round 1 — the table learns the game first.'
                : 'Off. The base game, no surprises.',
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 13,
              fontFamily: vibe.pack.type.body,
            ),
          ),
        ),
        if (settings.enabled) ...[
          _Group(
            label: 'Player events',
            hint: 'Rolled on each player as they take their word.',
            value: settings.playerPickEnabled,
            onChanged: (on) =>
                onChanged(settings.copyWith(playerPickEnabled: on)),
            events: InterferenceCatalogue.playerPickEvents,
            isEventOn: enabled.contains,
            onEventChanged: _toggleEvent,
            extra: settings.playerPickEnabled
                ? _Probability(
                    value: settings.playerPickProbability,
                    onChanged: (v) => onChanged(
                      settings.copyWith(playerPickProbability: v),
                    ),
                  )
                : null,
          ),
          _Group(
            label: 'Round events',
            hint: 'One modifier bends the whole round.',
            value: settings.roundStartEnabled,
            onChanged: (on) =>
                onChanged(settings.copyWith(roundStartEnabled: on)),
            events: InterferenceCatalogue.roundStartEvents,
            isEventOn: enabled.contains,
            onEventChanged: _toggleEvent,
          ),
          _ItemsGroup(
            value: settings.itemsEnabled,
            onChanged: (on) => onChanged(settings.copyWith(itemsEnabled: on)),
          ),
        ],
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    required this.events,
    required this.isEventOn,
    required this.onEventChanged,
    this.extra,
  });

  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;
  final List<InterferenceEventDefinition> events;
  final bool Function(String id) isEventOn;
  final void Function(String id, {required bool on}) onEventChanged;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;
    final onCount = events.where((e) => isEventOn(e.id)).length;

    return Padding(
      padding: EdgeInsets.only(left: vibe.gutter * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            value: value,
            onChanged: onChanged,
            activeThumbColor: palette.interference,
            contentPadding: EdgeInsets.zero,
            title: Text(
              label,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 15,
                fontFamily: vibe.pack.type.body,
              ),
            ),
            subtitle: Text(
              value ? '$onCount of ${events.length} on · $hint' : hint,
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 12,
                fontFamily: vibe.pack.type.body,
              ),
            ),
          ),
          if (value) ...[
            ?extra,
            for (final event in events)
              _EventRow(
                event: event,
                on: isEventOn(event.id),
                onChanged: (on) => onEventChanged(event.id, on: on),
              ),
            SizedBox(height: vibe.gutter),
          ],
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.on,
    required this.onChanged,
  });

  final InterferenceEventDefinition event;
  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;

    return CheckboxListTile(
      value: on,
      onChanged: (v) => onChanged(v ?? false),
      activeColor: palette.interference,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.only(left: vibe.gutter),
      dense: true,
      title: Row(
        children: [
          Flexible(
            child: Text(
              event.name,
              style: TextStyle(
                color: on ? palette.textPrimary : palette.textMuted,
                fontSize: 14,
                fontFamily: vibe.pack.type.body,
              ),
            ),
          ),
          SizedBox(width: vibe.gutter * 0.5),
          _EnforcementTag(enforcement: event.enforcement),
          if (event.requiresItemSystem) ...[
            SizedBox(width: vibe.gutter * 0.25),
            const _Tag(text: 'needs items'),
          ],
        ],
      ),
      subtitle: Text(
        event.description,
        style: TextStyle(
          color: palette.textMuted,
          fontSize: 12,
          fontFamily: vibe.pack.type.body,
        ),
      ),
    );
  }
}

/// Who enforces an event — the app, the table, or the table after the fact.
///
/// Surfaced on every row because §9f makes it consequential: roughly a third
/// of the pool cannot be detected by the app at all, and a host choosing a
/// chaos level should be able to see how much of it they will have to police.
class _EnforcementTag extends StatelessWidget {
  const _EnforcementTag({required this.enforcement});

  final EventEnforcement enforcement;

  @override
  Widget build(BuildContext context) => _Tag(
    text: switch (enforcement) {
      EventEnforcement.app => 'app',
      EventEnforcement.social => 'table',
      EventEnforcement.retroactive => 'after the lap',
    },
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: vibe.gutter * 0.5,
        vertical: vibe.gutter * 0.15,
      ),
      decoration: BoxDecoration(
        color: vibe.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(vibe.texture.cardRadius * 0.35),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: vibe.palette.textMuted,
          fontSize: 10,
          fontFamily: vibe.pack.type.body,
        ),
      ),
    );
  }
}

/// How often a player event fires (§9b, §12 open item 2).
class _Probability extends StatelessWidget {
  const _Probability({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return Padding(
      padding: EdgeInsets.only(left: vibe.gutter),
      child: Row(
        children: [
          Text(
            'How often',
            style: TextStyle(
              color: vibe.palette.textMuted,
              fontSize: 12,
              fontFamily: vibe.pack.type.body,
            ),
          ),
          Expanded(
            child: Slider(
              value: value,
              min: 0.05,
              max: 0.75,
              divisions: 14,
              activeColor: vibe.palette.interference,
              inactiveColor: vibe.palette.surfaceAlt,
              label: '${(value * 100).round()}%',
              onChanged: onChanged,
            ),
          ),
          Text(
            '${(value * 100).round()}%',
            style: TextStyle(
              color: vibe.palette.textPrimary,
              fontSize: 12,
              fontFamily: vibe.pack.type.display,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemsGroup extends StatelessWidget {
  const _ItemsGroup({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;

    return Padding(
      padding: EdgeInsets.only(left: vibe.gutter * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            value: value,
            onChanged: onChanged,
            activeThumbColor: palette.interference,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Items',
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 15,
                fontFamily: vibe.pack.type.body,
              ),
            ),
            subtitle: Text(
              // Turning items off also removes Mystery Item and Item Drop from
              // their pools — the roller does that, rather than letting either
              // roll and quietly do nothing (§9a).
              value
                  ? '${InterferenceCatalogue.itemIds.length} items · one held '
                        'at a time'
                  : 'Off. Mystery Item and Item Drop are removed too.',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 12,
                fontFamily: vibe.pack.type.body,
              ),
            ),
          ),
          SizedBox(height: vibe.gutter),
        ],
      ),
    );
  }
}
