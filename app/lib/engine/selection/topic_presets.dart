import 'package:diakooi/engine/models/settings.dart';
import 'package:diakooi/engine/selection/topic_selector.dart';

/// The host's topic-mix presets (01-DESIGN.md §13b).
///
/// "Presets so nobody has to fiddle" — the topic mixer is the fiddliest screen
/// in setup (§12 open item 5), and a host with people waiting should be able to
/// pick a mood and start.
///
/// **Every preset must sit inside the derived ceiling.** Sports Night shipped
/// as Basketball 70 / Buhay Pinoy 30, which is above it: the engine would have
/// delivered ~67% and the host would reasonably have concluded the app was
/// ignoring them. Corrected under proposal 0001. A test checks every preset
/// against [TopicSelector.ceilingFor] rather than against a remembered number.
class TopicPreset {
  const TopicPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.weights,
  });

  final String id;
  final String name;
  final String description;
  final List<TopicWeight> weights;

  /// The largest single weight, which is what the ceiling constrains.
  int get maxWeight =>
      weights.map((w) => w.weightPercent).reduce((a, b) => a > b ? a : b);

  int get total => weights.fold(0, (sum, w) => sum + w.weightPercent);

  /// Topics with a weight above 0 — the ones actually in the draw (§13b).
  int get eligibleCount => weights.where((w) => w.weightPercent > 0).length;

  /// Whether every weight is deliverable by the engine.
  bool get isWithinCeiling =>
      maxWeight <= TopicSelector.ceilingPercentFor(eligibleCount);
}

/// The five §13b presets.
abstract final class TopicPresets {
  /// An even spread across all twelve launch topics.
  ///
  /// Twelve does not divide 100, so four topics carry one extra point. Spread
  /// deliberately rather than piled onto one, which would make a topic
  /// measurably more likely for no reason a host could see.
  static List<TopicWeight> get _barkadaClassic {
    const ids = [
      'pagkain',
      'aktor',
      'kpop',
      'buhaypinoy',
      'teleserye',
      'opm',
      'lugar',
      'brands',
      'basketball',
      'internet',
      'anime',
      'kasaysayan',
    ];
    final base = 100 ~/ ids.length;
    final remainder = 100 % ids.length;
    return [
      for (var i = 0; i < ids.length; i++)
        TopicWeight(
          topicId: ids[i],
          weightPercent: base + (i < remainder ? 1 : 0),
        ),
    ];
  }

  static final barkadaClassic = TopicPreset(
    id: 'barkada_classic',
    name: 'Barkada Classic',
    description: 'An even spread across every topic.',
    weights: _barkadaClassic,
  );

  static const stanMode = TopicPreset(
    id: 'stan_mode',
    name: 'Stan Mode',
    description: 'For a table that will fight about K-Pop.',
    weights: [
      TopicWeight(topicId: 'kpop', weightPercent: 60),
      TopicWeight(topicId: 'opm', weightPercent: 20),
      TopicWeight(topicId: 'internet', weightPercent: 20),
    ],
  );

  static const titaMode = TopicPreset(
    id: 'tita_mode',
    name: 'Tita Mode',
    description: 'Teleserye, showbiz and the songs that go with them.',
    weights: [
      TopicWeight(topicId: 'teleserye', weightPercent: 40),
      TopicWeight(topicId: 'aktor', weightPercent: 30),
      TopicWeight(topicId: 'opm', weightPercent: 30),
    ],
  );

  static const gutom = TopicPreset(
    id: 'gutom',
    name: 'Gutom',
    description: 'Play this one after dinner, not before.',
    weights: [
      TopicWeight(topicId: 'pagkain', weightPercent: 60),
      TopicWeight(topicId: 'brands', weightPercent: 20),
      TopicWeight(topicId: 'buhaypinoy', weightPercent: 20),
    ],
  );

  /// Corrected under proposal 0001.
  ///
  /// Was Basketball 70 / Buhay Pinoy 30 — above the ceiling, so the engine
  /// would have delivered about 67% however the host set it. Basketball stays
  /// dominant at 60, and a third topic absorbs the difference rather than
  /// pushing it all onto one.
  static const sportsNight = TopicPreset(
    id: 'sports_night',
    name: 'Sports Night',
    description: 'Basketball, and the country around it.',
    weights: [
      TopicWeight(topicId: 'basketball', weightPercent: 60),
      TopicWeight(topicId: 'buhaypinoy', weightPercent: 25),
      TopicWeight(topicId: 'brands', weightPercent: 15),
    ],
  );

  static List<TopicPreset> get all => [
    barkadaClassic,
    stanMode,
    titaMode,
    gutom,
    sportsNight,
  ];

  static TopicPreset? byId(String id) {
    for (final preset in all) {
      if (preset.id == id) return preset;
    }
    return null;
  }
}
