import 'package:diakooi/engine/engine.dart';
import 'package:test/test.dart';

/// The topic-weight ceiling (01-DESIGN.md §13b, proposal 0001).
///
/// The ceiling is **derived**, so these tests assert the derivation rather than
/// a remembered 66. If `maxConsecutive` ever changes, they follow it.
void main() {
  group('ceiling derivation', () {
    test('follows maxConsecutive rather than a hardcoded number', () {
      const c = TopicSelector.maxConsecutive;
      expect(
        TopicSelector.ceilingFor(3),
        closeTo(c / (c + 1), 1e-9),
        reason: 'the ceiling is C/(C+1) — after C draws the topic must yield',
      );
    });

    test('is 100% when only one topic is eligible', () {
      expect(
        TopicSelector.ceilingFor(1),
        1.0,
        reason:
            'with nothing else to draw the window cannot apply, so a single '
            'enabled topic can legitimately take every round',
      );
      expect(TopicSelector.ceilingFor(0), 1.0);
    });

    test('is the same for every count above one', () {
      final ceilings = [
        for (var n = 2; n <= 12; n++) TopicSelector.ceilingFor(n),
      ];
      expect(ceilings.toSet(), hasLength(1));
      expect(ceilings.first, lessThan(1.0));
    });

    test('the percentage form floors rather than rounds', () {
      // 66.67 must present as 66. A slider stopping one point short of the
      // true limit is preferable to one stopping a point past it.
      expect(TopicSelector.ceilingPercentFor(3), 66);
      expect(TopicSelector.ceilingPercentFor(1), 100);
    });
  });

  group('the ceiling is real — the engine cannot beat it', () {
    test('a topic weighted at 90% still lands at about the ceiling', () {
      final settings = RoomSettings.validated(
        playerCount: 6,
        topicWeights: const [
          TopicWeight(topicId: 'kpop', weightPercent: 90),
          TopicWeight(topicId: 'opm', weightPercent: 10),
        ],
      );

      final rng = SeededRng(4242);
      final history = <String>[];
      var kpop = 0;
      const draws = 6000;

      for (var i = 0; i < draws; i++) {
        final topic = TopicSelector.draw(
          settings: settings,
          topicHistory: history,
          rng: rng,
        );
        history.add(topic);
        if (topic == 'kpop') kpop++;
      }

      final share = kpop / draws;
      final ceiling = TopicSelector.ceilingFor(2);
      expect(
        share,
        lessThanOrEqualTo(ceiling + 0.01),
        reason:
            'a 90% weight measured ${(share * 100).toStringAsFixed(1)}% — the '
            'window caps it, which is exactly why the slider clamps',
      );
      expect(
        share,
        greaterThan(ceiling - 0.05),
        reason: 'and it should reach the ceiling, not fall well short of it',
      );
    });

    test('a single enabled topic takes every round', () {
      final settings = RoomSettings.validated(
        playerCount: 6,
        topicWeights: const [
          TopicWeight(topicId: 'pagkain', weightPercent: 100),
          TopicWeight(topicId: 'kpop', weightPercent: 0),
        ],
      );
      final rng = SeededRng(1);
      final history = <String>[];
      for (var i = 0; i < 50; i++) {
        final topic = TopicSelector.draw(
          settings: settings,
          topicHistory: history,
          rng: rng,
        );
        expect(topic, 'pagkain');
        history.add(topic);
      }
    });
  });

  group('presets (§13b)', () {
    test('all five exist', () {
      expect(TopicPresets.all, hasLength(5));
      expect(TopicPresets.all.map((p) => p.id).toSet(), hasLength(5));
    });

    // Checked against the DERIVED ceiling, not a remembered number. Sports
    // Night shipped over the line; this is the test that would have caught it.
    for (final preset in TopicPresets.all) {
      test('${preset.name}: weights total 100', () {
        expect(preset.total, 100);
      });

      test('${preset.name}: sits inside the derived ceiling', () {
        final ceiling = TopicSelector.ceilingPercentFor(preset.eligibleCount);
        expect(
          preset.maxWeight,
          lessThanOrEqualTo(ceiling),
          reason:
              '${preset.name} peaks at ${preset.maxWeight}% against a ceiling '
              'of $ceiling% — the engine would silently deliver less',
        );
        expect(preset.isWithinCeiling, isTrue);
      });

      test('${preset.name}: builds valid settings', () {
        final settings = RoomSettings.validated(
          playerCount: 6,
          topicWeights: preset.weights,
        );
        expect(settings.eligibleTopics, isNotEmpty);
      });
    }

    test('Sports Night is the corrected mix, not the original', () {
      final basketball = TopicPresets.sportsNight.weights.firstWhere(
        (w) => w.topicId == 'basketball',
      );
      expect(
        basketball.weightPercent,
        60,
        reason:
            'the original 70 was above the ceiling and would have delivered '
            'about 67 (proposal 0001)',
      );
      expect(
        TopicPresets.sportsNight.weights,
        hasLength(3),
        reason: 'a third topic absorbs the difference',
      );
    });

    test('Barkada Classic spreads its remainder rather than piling it', () {
      final weights = TopicPresets.barkadaClassic.weights
          .map((w) => w.weightPercent)
          .toList();
      expect(TopicPresets.barkadaClassic.total, 100);
      // 12 topics into 100 leaves 4 over; no topic should be far above another.
      expect(
        weights.reduce((a, b) => a > b ? a : b) -
            weights.reduce((a, b) => a < b ? a : b),
        lessThanOrEqualTo(1),
        reason: 'an uneven "even spread" is a topic nobody chose to favour',
      );
    });
  });
}
