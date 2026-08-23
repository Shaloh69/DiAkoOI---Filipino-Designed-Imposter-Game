import 'package:diakooi/engine/engine.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:flutter/material.dart';

/// The §13b topic mixer.
///
/// The host sets a mix and the app rolls against it — they do not pick a topic
/// per round. Presets exist because this is the fiddliest screen in setup and a
/// host with people waiting should be able to pick a mood and start.
///
/// **The slider stops at the ceiling.** Proposal 0001 chose that over letting a
/// host set a value the engine would quietly ignore: a slider that stops
/// communicates the constraint wordlessly, and the ceiling is derived from the
/// enabled topic count so it moves when the host turns topics on and off.
class TopicMixer extends StatelessWidget {
  const TopicMixer({
    required this.mix,
    required this.topics,
    required this.onChanged,
    super.key,
  });

  final TopicMix mix;

  /// Only topics the word bank can actually draw from.
  ///
  /// Offering a topic with no words would let a host build a mix that crashes
  /// at ROUND_START — [WordSelector.draw] throws rather than repeating a word,
  /// and it is right to throw. The fix belongs here, at the point the choice is
  /// offered.
  final List<Topic> topics;

  final ValueChanged<TopicMix> onChanged;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: TopicPresets.all.length,
            separatorBuilder: (_, _) => SizedBox(width: vibe.gutter),
            itemBuilder: (context, index) {
              final preset = TopicPresets.all[index];
              // At least one topic present, not all of them. A preset is a
              // shape and TopicMix.fromPreset renormalises it over whatever
              // the bank can fill; requiring every topic disabled all five
              // presets against the shipped placeholder bank.
              final usable = preset.weights.any(
                (w) => topics.any((t) => t.id == w.topicId),
              );
              return ActionChip(
                label: Text(preset.name),
                backgroundColor: palette.surface,
                labelStyle: TextStyle(
                  color: palette.textPrimary,
                  fontFamily: vibe.pack.type.body,
                ),
                side: BorderSide(color: palette.surfaceAlt),
                // A preset naming a topic the bank cannot fill would produce
                // the same crash by a shorter route, so it is not offered.
                onPressed: usable
                    ? () => onChanged(
                        TopicMix.fromPreset(
                          preset.weights,
                          allTopicIds: [for (final t in topics) t.id],
                        ),
                      )
                    : null,
              );
            },
          ),
        ),
        SizedBox(height: vibe.gutter),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${mix.enabledCount} topics in the mix',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 13,
                fontFamily: vibe.pack.type.body,
              ),
            ),
            Text(
              'max ${mix.ceilingPercent}%',
              style: TextStyle(
                color: palette.textMuted,
                fontSize: 13,
                fontFamily: vibe.pack.type.body,
              ),
            ),
          ],
        ),
        SizedBox(height: vibe.gutter * 0.5),
        for (final topic in topics)
          _TopicRow(
            topic: topic,
            mix: mix,
            onChanged: onChanged,
          ),
      ],
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.topic,
    required this.mix,
    required this.onChanged,
  });

  final Topic topic;
  final TopicMix mix;
  final ValueChanged<TopicMix> onChanged;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;
    final weight = mix.weightOf(topic.id);
    final enabled = weight > 0;

    // With one topic left the slider has nothing to trade against, so it is
    // pinned rather than shown as a control that refuses to move.
    final adjustable = enabled && mix.enabledCount > 1;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: vibe.gutter * 0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Switch(
                value: enabled,
                onChanged: (value) =>
                    onChanged(mix.toggle(topic.id, enabled: value)),
                activeThumbColor: palette.crew,
              ),
              Expanded(
                child: Text(
                  topic.nameFil,
                  style: TextStyle(
                    color: enabled ? palette.textPrimary : palette.textMuted,
                    fontSize: 15,
                    fontFamily: vibe.pack.type.body,
                  ),
                ),
              ),
              Text(
                enabled ? '$weight%' : 'off',
                style: TextStyle(
                  color: enabled ? palette.textPrimary : palette.textMuted,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontFamily: vibe.pack.type.display,
                ),
              ),
            ],
          ),
          if (adjustable)
            Semantics(
              slider: true,
              label: '${topic.nameFil} share',
              value: '$weight percent of ${mix.ceilingPercent} maximum',
              child: Slider(
                value: weight.toDouble().clamp(
                  mix.floorPercent.toDouble(),
                  mix.ceilingPercent.toDouble(),
                ),
                // Derived bounds, never constants. A host who turns topics off
                // changes both ends of this slider.
                min: mix.floorPercent.toDouble(),
                max: mix.ceilingPercent.toDouble(),
                activeColor: palette.crew,
                inactiveColor: palette.surfaceAlt,
                onChanged: (value) =>
                    onChanged(mix.withWeight(topic.id, value.round())),
              ),
            ),
        ],
      ),
    );
  }
}
