import 'package:diakooi/content/topics.dart';
import 'package:diakooi/engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// The host's topic mixer, under the clamp accepted in proposal 0001.
///
/// Everything here checks against [TopicSelector.ceilingFor] rather than
/// against a remembered 66: the ceiling moves when the no-repeat window moves,
/// and moves again when a host disables topics. A test that hardcoded it would
/// pass while the app was wrong.
void main() {
  final allIds = [for (final t in TopicCatalogue.topics) t.id];

  TopicMix mixOf(Map<String, int> weights) => TopicMix([
    for (final id in allIds)
      TopicWeight(topicId: id, weightPercent: weights[id] ?? 0),
  ]);

  group('the ceiling is derived, not remembered', () {
    test('it tracks TopicSelector for every enabled count', () {
      for (var count = 2; count <= allIds.length; count++) {
        final mix = mixOf({
          for (var i = 0; i < count; i++)
            allIds[i]: i == 0 ? 100 - count + 1 : 1,
        });
        expect(mix.enabledCount, count);
        expect(mix.ceilingPercent, TopicSelector.ceilingPercentFor(count));
      }
    });

    test('one topic left has no ceiling — there is nothing else to draw', () {
      final mix = mixOf({allIds.first: 100});
      expect(mix.enabledCount, 1);
      expect(mix.ceilingPercent, 100);
      expect(
        mix.withWeight(allIds.first, 40).weightOf(allIds.first),
        100,
        reason: 'the only topic in the draw is 100% by definition',
      );
    });

    test('a raised window would raise the ceiling with it', () {
      // Not a hypothetical: this is the assertion that stops a constant being
      // reintroduced. C/(C+1) is the whole rule.
      const c = TopicSelector.maxConsecutive;
      expect(TopicSelector.ceilingFor(5), closeTo(c / (c + 1), 1e-12));
    });
  });

  group('the slider clamps rather than warning', () {
    test('a request above the ceiling lands exactly on it', () {
      final mix = mixOf({'pagkain': 40, 'kpop': 30, 'basketball': 30});
      final pushed = mix.withWeight('pagkain', 95);

      expect(pushed.weightOf('pagkain'), mix.ceilingPercent);
      expect(
        pushed.weightOf('pagkain'),
        lessThan(95),
        reason:
            'a UI that accepts a setting it cannot honour is worse than one '
            'that stops (proposal 0001)',
      );
    });

    test('the rest rebalance so the total stays exactly 100', () {
      var mix = mixOf({'pagkain': 40, 'kpop': 30, 'basketball': 30});
      for (final requested in [0, 7, 33, 50, 66, 67, 99, 100]) {
        mix = mix.withWeight('pagkain', requested);
        expect(
          mix.total,
          100,
          reason: '§13b requires exactly 100; a host can see 99 and will',
        );
        expect(mix.isValid, isTrue);
      }
    });

    test('no rebalance ever pushes another topic over the ceiling', () {
      // The failure a naive proportional split produces: shrinking a small
      // topic hands its mass to the biggest one, which is already near the top.
      var mix = mixOf({'pagkain': 10, 'kpop': 66, 'basketball': 24});
      mix = mix.withWeight('pagkain', 5);

      for (final w in mix.weights) {
        expect(
          w.weightPercent,
          lessThanOrEqualTo(mix.ceilingPercent),
          reason: '${w.topicId} was pushed past what the draw can deliver',
        );
      }
      expect(mix.total, 100);
    });

    test('the floor stops a topic starving the others', () {
      final mix = mixOf({'pagkain': 50, 'kpop': 50});
      expect(mix.floorPercent, 100 - mix.ceilingPercent);

      final starved = mix.withWeight('pagkain', 5);
      expect(
        starved.weightOf('pagkain'),
        mix.floorPercent,
        reason:
            'with two topics in the draw, dropping one to 5 would need the '
            'other at 95, which the window cannot deliver',
      );
      expect(starved.weightOf('kpop'), mix.ceilingPercent);
    });

    test('there is no floor once there is room to absorb the mass', () {
      final mix = mixOf({'pagkain': 34, 'kpop': 33, 'basketball': 33});
      expect(mix.floorPercent, 0);
    });
  });

  group('turning topics in and out', () {
    test('switching one off spreads its mass and keeps the total at 100', () {
      final mix = mixOf({
        'pagkain': 40,
        'kpop': 30,
        'basketball': 30,
      }).toggle('pagkain', enabled: false);

      expect(mix.isEnabled('pagkain'), isFalse);
      expect(mix.enabledCount, 2);
      expect(mix.total, 100);
      expect(mix.isValid, isTrue);
    });

    test('switching one on takes an even share from the rest', () {
      final mix = mixOf({
        'pagkain': 50,
        'kpop': 50,
      }).toggle('basketball', enabled: true);

      expect(mix.enabledCount, 3);
      expect(mix.total, 100);
      expect(mix.weightOf('basketball'), greaterThan(0));
      expect(mix.isValid, isTrue);
    });

    test('the last topic cannot be switched off', () {
      final mix = mixOf({'pagkain': 100});
      expect(
        mix.toggle('pagkain', enabled: false).enabledCount,
        1,
        reason: 'an empty draw has no answer, so the host is stopped instead',
      );
    });

    test('dropping to a single topic raises it to 100, not to the ceiling', () {
      final mix = mixOf({
        'pagkain': 50,
        'kpop': 50,
      }).toggle('kpop', enabled: false);

      expect(mix.weightOf('pagkain'), 100);
      expect(mix.isValid, isTrue);
    });

    test('only enabled topics reach the room settings', () {
      final mix = mixOf({'pagkain': 40, 'kpop': 30, 'basketball': 30});
      final weights = mix.toWeights();

      expect(weights, hasLength(3));
      expect(
        weights.every((w) => w.weightPercent > 0),
        isTrue,
        reason: 'a topic at 0 is excluded from the draw entirely (§13b)',
      );
      expect(
        () => RoomSettings.validated(playerCount: 6, topicWeights: weights),
        returnsNormally,
      );
    });
  });

  group('the five presets (§13b)', () {
    test('every preset is inside the derived ceiling and totals 100', () {
      for (final preset in TopicPresets.all) {
        expect(
          preset.total,
          100,
          reason: '${preset.name} does not total 100',
        );
        expect(
          preset.maxWeight,
          lessThanOrEqualTo(
            TopicSelector.ceilingPercentFor(preset.eligibleCount),
          ),
          reason:
              '${preset.name} asks for ${preset.maxWeight}%, above what the '
              'no-repeat window delivers for ${preset.eligibleCount} topics',
        );
        expect(preset.isWithinCeiling, isTrue);
      }
    });

    test('Sports Night is the corrected mix, not the one over the line', () {
      const preset = TopicPresets.sportsNight;
      expect(preset.weights, hasLength(3));
      expect(
        preset.maxWeight,
        60,
        reason:
            'Basketball 70 / Buhay Pinoy 30 was above the ceiling; the engine '
            'would have delivered about 67 whatever the host set',
      );
      expect(
        preset.weights.map((w) => w.topicId),
        containsAll(<String>['basketball', 'buhaypinoy', 'brands']),
      );
    });

    test('Stan Mode sits just under the ceiling rather than just over', () {
      const preset = TopicPresets.stanMode;
      expect(preset.maxWeight, 60);
      expect(
        preset.maxWeight,
        lessThan(TopicSelector.ceilingPercentFor(preset.eligibleCount)),
      );
    });

    test('every preset loads into a mix and back out unchanged', () {
      for (final preset in TopicPresets.all) {
        final mix = TopicMix.fromPreset(preset.weights, allTopicIds: allIds);
        expect(mix.total, 100, reason: preset.name);
        expect(mix.isValid, isTrue, reason: preset.name);
        expect(
          mix.toWeights().map((w) => '${w.topicId}:${w.weightPercent}').toSet(),
          preset.weights.map((w) => '${w.topicId}:${w.weightPercent}').toSet(),
          reason: '${preset.name} did not survive the round trip',
        );
      }
    });

    test('every preset names a topic the catalogue actually has', () {
      for (final preset in TopicPresets.all) {
        for (final weight in preset.weights) {
          expect(
            TopicCatalogue.byId(weight.topicId),
            isNotNull,
            reason:
                '${preset.name} references "${weight.topicId}", which would '
                'silently draw from an empty topic',
          );
        }
      }
    });
  });

  group('what the engine actually delivers at the ceiling', () {
    test('a mix set to the ceiling measures at the ceiling, not below', () {
      // The point of the clamp: what the host sets is what they get. Measured
      // rather than assumed, because the deficit weighting in ADR 0007 is what
      // makes it true and a regression there would be invisible otherwise.
      final mix = mixOf({'pagkain': 40, 'kpop': 30, 'basketball': 30});
      final atCeiling = mix.withWeight('pagkain', 100);
      final settings = RoomSettings.validated(
        playerCount: 6,
        topicWeights: atCeiling.toWeights(),
      );

      final rng = SeededRng(4242);
      final history = <String>[];
      const draws = 6000;
      for (var i = 0; i < draws; i++) {
        history.add(
          TopicSelector.draw(
            settings: settings,
            topicHistory: history,
            rng: rng,
          ),
        );
      }

      final share = history.where((t) => t == 'pagkain').length / draws;
      expect(
        share,
        closeTo(atCeiling.weightOf('pagkain') / 100, 0.02),
        reason:
            'the clamp is only honest if the ceiling is deliverable — a host '
            'who sets the maximum must actually get it',
      );
    });
  });
}
