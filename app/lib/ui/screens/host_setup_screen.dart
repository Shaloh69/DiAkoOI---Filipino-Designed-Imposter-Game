import 'package:diakooi/content/topics.dart';
import 'package:diakooi/engine/engine.dart';
import 'package:diakooi/theme/vibe_theme.dart';
import 'package:diakooi/ui/widgets/topic_mixer.dart';
import 'package:diakooi/ui/widgets/vibe_scaffold.dart';
import 'package:flutter/material.dart';

/// Host setup — every §2 parameter.
///
/// Interference (§9) is Phase 5 and is deliberately absent rather than shown
/// disabled: a toggle that does nothing invites a host to turn it on and
/// conclude the app is broken.
class HostSetupScreen extends StatefulWidget {
  const HostSetupScreen({
    required this.onStart,
    required this.availableTopicIds,
    this.initial,
    this.onOpenProfiling,
    super.key,
  });

  final ValueChanged<RoomSettings> onStart;

  /// Topics the bundled word bank can actually draw from. Anything else is not
  /// offered — see [TopicMixer.topics].
  final Set<String> availableTopicIds;

  final RoomSettings? initial;

  /// Opens the A5 profiling harness. Null in release builds, where the screen
  /// does not exist.
  final VoidCallback? onOpenProfiling;

  @override
  State<HostSetupScreen> createState() => _HostSetupScreenState();
}

class _HostSetupScreenState extends State<HostSetupScreen> {
  late int _playerCount;
  late int _livesPerPlayer;
  late int _totalRounds;
  late int _roundabouts;
  late ClueTier _clueTier;
  late int? _earlyEnd;
  late int? _clueTimerSeconds;
  late bool _hostIsPlayer;
  late bool _imposterCountIsAuto;
  late int _imposterCount;
  late TopicMix _mix;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _playerCount = initial?.playerCount ?? 6;
    _livesPerPlayer = initial?.livesPerPlayer ?? 3;
    _totalRounds = initial?.totalRounds ?? 8;
    _roundabouts = initial?.roundaboutsPerRound ?? 2;
    _clueTier = initial?.clueDifficulty ?? ClueTier.standard;
    _earlyEnd = initial?.earlyEndConsequenceThreshold;
    _clueTimerSeconds = initial?.clueTimerSeconds;
    _hostIsPlayer = initial?.hostIsPlayer ?? false;
    _imposterCount =
        initial?.imposterCount ??
        RoomSettings.defaultImposterCount(_playerCount);
    _imposterCountIsAuto =
        _imposterCount == RoomSettings.defaultImposterCount(_playerCount);
    _mix = TopicMix.fromPreset(
      initial?.topicWeights ?? TopicPresets.barkadaClassic.weights,
      allTopicIds: [for (final t in _topics) t.id],
    );
  }

  /// The catalogue, narrowed to what the bank can fill, in catalogue order.
  List<Topic> get _topics => [
    for (final topic in TopicCatalogue.topics)
      if (widget.availableTopicIds.contains(topic.id)) topic,
  ];

  bool get _largeGroup => _playerCount >= RoomSettings.largeGroupThreshold;

  /// Clamped as well as chosen: dropping the table to three people after
  /// setting four imposters would leave no crew, and [RoomSettings.validated]
  /// would throw at the moment the host pressed Start.
  int get _effectiveImposters => _imposterCountIsAuto
      ? RoomSettings.defaultImposterCount(_playerCount)
      : _imposterCount.clamp(RoomSettings.minImposters, _playerCount - 1);

  RoomSettings _build() => RoomSettings.validated(
    playerCount: _playerCount,
    topicWeights: _mix.toWeights(),
    clueDifficulty: _clueTier,
    imposterCount: _effectiveImposters,
    livesPerPlayer: _livesPerPlayer,
    totalRounds: _totalRounds,
    roundaboutsPerRound: _roundabouts,
    earlyEndConsequenceThreshold: _earlyEnd,
    clueTimerSeconds: _clueTimerSeconds,
    hostIsPlayer: _hostIsPlayer,
  );

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;

    return VibeScaffold(
      title: 'Set up the game',
      subtitle: 'Pass the phone around. One device, one table.',
      footer: VibeButton(
        label: 'Start — $_playerCount players',
        onPressed: _mix.isValid ? () => widget.onStart(_build()) : null,
      ),
      child: ListView(
        children: [
          _Stepper(
            label: 'Players',
            value: _playerCount,
            min: RoomSettings.minPlayers,
            max: RoomSettings.maxPlayers,
            onChanged: (value) => setState(() => _playerCount = value),
          ),
          if (_largeGroup)
            _Note(
              // §2a — automatic, not a toggle. A host who has just counted
              // thirteen people is not also deciding about pacing.
              'Large Group Mode is on: one roundabout, tighter clues, and a '
              'pace hint on the pass screen.',
              tone: palette.interference,
            ),
          _Stepper(
            label: 'Lives each',
            value: _livesPerPlayer,
            min: RoomSettings.minLives,
            max: RoomSettings.maxLives,
            onChanged: (value) => setState(() => _livesPerPlayer = value),
          ),
          _Stepper(
            label: 'Rounds',
            value: _totalRounds,
            min: 3,
            max: 15,
            onChanged: (value) => setState(() => _totalRounds = value),
          ),
          _Stepper(
            label: 'Roundabouts per round',
            value: _roundabouts,
            min: RoomSettings.minRoundabouts,
            max: RoomSettings.maxRoundabouts,
            onChanged: (value) => setState(() => _roundabouts = value),
          ),
          if (_largeGroup && _roundabouts > 1)
            _Note(
              'Capped to 1 while Large Group Mode is on.',
              tone: palette.textMuted,
            ),
          _Row(
            label: 'Imposters',
            trailing: Text(
              _imposterCountIsAuto
                  ? 'Auto — $_effectiveImposters'
                  : '$_imposterCount',
              style: TextStyle(
                color: palette.textPrimary,
                fontFamily: vibe.pack.type.display,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            children: [
              Switch(
                value: _imposterCountIsAuto,
                activeThumbColor: palette.crew,
                onChanged: (value) => setState(() {
                  _imposterCountIsAuto = value;
                  if (value) {
                    _imposterCount = RoomSettings.defaultImposterCount(
                      _playerCount,
                    );
                  }
                }),
              ),
              Expanded(
                child: Text(
                  'Scale with the table size',
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 13,
                    fontFamily: vibe.pack.type.body,
                  ),
                ),
              ),
            ],
          ),
          if (!_imposterCountIsAuto)
            _Stepper(
              label: 'How many',
              value: _imposterCount,
              min: RoomSettings.minImposters,
              max: _playerCount - 1 < RoomSettings.maxImposters
                  ? _playerCount - 1
                  : RoomSettings.maxImposters,
              onChanged: (value) => setState(() => _imposterCount = value),
            ),
          SizedBox(height: vibe.gutter),
          const _SectionLabel('Clue difficulty'),
          SegmentedButton<ClueTier>(
            segments: const [
              ButtonSegment(value: ClueTier.loose, label: Text('Loose')),
              ButtonSegment(value: ClueTier.standard, label: Text('Standard')),
              ButtonSegment(value: ClueTier.tight, label: Text('Tight')),
            ],
            selected: {_clueTier},
            onSelectionChanged: (value) =>
                setState(() => _clueTier = value.first),
          ),
          if (_largeGroup)
            _Note(
              'One step tighter in Large Group Mode — at 13+ there is far more '
              'on the table (§14).',
              tone: palette.textMuted,
            ),
          SizedBox(height: vibe.gutter),
          const _SectionLabel('End early'),
          _Row(
            label: _earlyEnd == null
                ? 'Off — play all $_totalRounds rounds'
                : 'After $_earlyEnd have taken a consequence',
            trailing: Switch(
              value: _earlyEnd != null,
              activeThumbColor: palette.crew,
              onChanged: (value) =>
                  setState(() => _earlyEnd = value ? 2 : null),
            ),
          ),
          if (_earlyEnd != null)
            _Stepper(
              label: 'How many',
              value: _earlyEnd!,
              min: 1,
              max: 3,
              onChanged: (value) => setState(() => _earlyEnd = value),
            ),
          SizedBox(height: vibe.gutter),
          const _SectionLabel('Clue timer'),
          _Row(
            // §6 — off by default. A timer turns a conversation into a drill,
            // and the pressure it adds is not the pressure the game wants.
            label: _clueTimerSeconds == null
                ? 'Off — talk as long as you like'
                : '$_clueTimerSeconds seconds, as a nudge',
            trailing: Switch(
              value: _clueTimerSeconds != null,
              activeThumbColor: palette.crew,
              onChanged: (value) =>
                  setState(() => _clueTimerSeconds = value ? 20 : null),
            ),
          ),
          if (_clueTimerSeconds != null)
            _Stepper(
              label: 'Seconds',
              value: _clueTimerSeconds!,
              min: 10,
              max: 60,
              step: 5,
              onChanged: (value) => setState(() => _clueTimerSeconds = value),
            ),
          SizedBox(height: vibe.gutter),
          const _SectionLabel('Host plays too'),
          _Row(
            label: _hostIsPlayer ? 'Yes' : 'No — the host runs the phone',
            trailing: Switch(
              value: _hostIsPlayer,
              activeThumbColor: palette.crew,
              onChanged: (value) => setState(() => _hostIsPlayer = value),
            ),
          ),
          if (_hostIsPlayer)
            _Note(
              // §2b — not cosmetic, and the reason is worth the sentence.
              'The host sees the screen between every pass. Playing as well '
              'means they know who has already looked and for how long, which '
              'is information nobody else has.',
              tone: palette.danger,
            ),
          if (widget.onOpenProfiling != null) ...[
            SizedBox(height: vibe.gutter),
            VibeButton(
              label: 'Profiling harness (A5)',
              emphasis: VibeEmphasis.quiet,
              onPressed: widget.onOpenProfiling,
            ),
          ],
          SizedBox(height: vibe.gutter * 2),
          const _SectionLabel('Topics'),
          TopicMixer(
            mix: _mix,
            topics: _topics,
            onChanged: (mix) => setState(() => _mix = mix),
          ),
          SizedBox(height: vibe.gutter * 2),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return Padding(
      padding: EdgeInsets.only(bottom: vibe.gutter * 0.5),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: vibe.palette.textMuted,
          fontSize: 12,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
          fontFamily: vibe.pack.type.body,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.trailing});
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: vibe.gutter * 0.25),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: vibe.palette.textPrimary,
                fontSize: 15,
                fontFamily: vibe.pack.type.body,
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {required this.tone});
  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    return Padding(
      padding: EdgeInsets.only(bottom: vibe.gutter),
      child: Text(
        text,
        style: TextStyle(
          color: tone,
          fontSize: 13,
          fontFamily: vibe.pack.type.body,
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final vibe = context.vibe;
    final palette = vibe.palette;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: vibe.gutter * 0.25),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 15,
                fontFamily: vibe.pack.type.body,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Fewer',
            onPressed: value > min ? () => onChanged(value - step) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: palette.textMuted,
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: vibe.pack.type.display,
              ),
            ),
          ),
          IconButton(
            tooltip: 'More',
            onPressed: value < max ? () => onChanged(value + step) : null,
            icon: const Icon(Icons.add_circle_outline),
            color: palette.textMuted,
          ),
        ],
      ),
    );
  }
}
