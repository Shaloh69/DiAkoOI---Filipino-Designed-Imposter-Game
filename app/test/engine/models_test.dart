import 'dart:typed_data';

import 'package:diakooi/engine/engine.dart';
import 'package:test/test.dart';

import 'support.dart';

/// Model behaviour and serialisation.
///
/// These are the §11 shapes the whole app passes around, and the ones a word
/// bank and a saved room are decoded into — so a JSON round-trip failing here
/// is a shipped bundle failing to load.
void main() {
  group('content models (§11, §13, §14)', () {
    test('ClueSet serves each authored tier (§14)', () {
      const clues = ClueSet(
        tight: 'a fast food place kids love, may mascot',
        standard: 'somewhere you eat when nagmamadali',
        loose: 'a place you go with family',
      );
      expect(clues.forTier(ClueTier.tight), clues.tight);
      expect(clues.forTier(ClueTier.standard), clues.standard);
      expect(clues.forTier(ClueTier.loose), clues.loose);
    });

    test('WordBankEntry round-trips through JSON', () {
      const entry = WordBankEntry(
        topicId: 'pagkain',
        word: 'Jollibee',
        clues: ClueSet(tight: 't', standard: 's', loose: 'l'),
        difficultyRating: 2,
      );
      final decoded = WordBankEntry.fromJson(entry.toJson());
      expect(decoded, entry);
      expect(
        decoded.region,
        ContentRegion.national,
        reason: 'v1 ships national-only content (§13c)',
      );
    });

    test('Topic round-trips through JSON', () {
      const topic = Topic(
        id: 'pagkain',
        nameEn: 'Food',
        nameFil: 'Pagkain',
        description: 'Filipino dishes, street food, kakanin, merienda',
        defaultWeightPercent: 10,
      );
      expect(Topic.fromJson(topic.toJson()), topic);
    });

    test('VibePack carries the licence fields a pack cannot ship without', () {
      const pack = VibePack(
        id: 'placeholder',
        displayName: 'Placeholder',
        trackFile: 'track.ogg',
        artistName: 'Nobody',
        licenceType: 'CC0',
        licenceUrl: 'https://example.invalid',
        attributionText: 'none required',
      );
      final decoded = VibePack.fromJson(pack.toJson());
      expect(decoded, pack);
      expect(decoded.licenceType, isNotEmpty);
      expect(decoded.licenceUrl, isNotEmpty);
    });
  });

  group('Player (§11)', () {
    test('reports elimination and item state', () {
      const alive = Player(id: 'p', name: 'P', seatOrder: 0, currentLives: 2);
      expect(alive.isOut, isFalse);
      expect(alive.hasItem, isFalse);

      final out = alive.copyWith(currentLives: 0, heldItem: 'item_shield');
      expect(out.isOut, isTrue);
      expect(out.hasItem, isTrue);
    });

    test('counts only served forfeits (§8)', () {
      const player = Player(
        id: 'p',
        name: 'P',
        seatOrder: 0,
        currentLives: 1,
        consequenceLog: [
          ConsequenceEntry(roundIndex: 0, description: 'sang'),
          ConsequenceEntry(roundIndex: 1, description: 'danced'),
        ],
      );
      expect(player.consequenceLog, hasLength(2));
      expect(
        player.forfeitsServed,
        0,
        reason: 'logged but not yet served',
      );

      final served = player.copyWith(
        consequenceLog: [
          player.consequenceLog.first.copyWith(servedAt: DateTime.utc(2026)),
          player.consequenceLog.last,
        ],
      );
      expect(served.forfeitsServed, 1);
      expect(served.consequenceLog.first.isServed, isTrue);
      expect(served.consequenceLog.last.isServed, isFalse);
    });

    test('round-trips through JSON without the selfie (§4b, ADR 0005)', () {
      final player = Player(
        id: 'p0',
        name: 'Ana',
        seatOrder: 1,
        currentLives: 3,
        selfieBytes: Uint8List.fromList([1, 2, 3, 4]),
        monogramColor: '#ff0000',
        stats: const PlayerStats(accusationsMade: 2, accusationsCorrect: 1),
      );

      final json = player.toJson();
      expect(json.containsKey('selfieBytes'), isFalse);

      final decoded = Player.fromJson(json);
      expect(decoded.name, 'Ana');
      expect(decoded.stats.accusationsMade, 2);
      expect(
        decoded.selfieBytes,
        isNull,
        reason:
            'a selfie must not survive serialisation in any form — the app '
            'never writes one to storage (§4b)',
      );
    });

    test('PlayerStats round-trips and defaults to zero', () {
      const stats = PlayerStats();
      expect(PlayerStats.fromJson(stats.toJson()), stats);
      expect(stats.accusationsMade, 0);
      expect(stats.roundsAsImposterUncaught, 0);
      expect(stats.interferenceEventsReceived, 0);
    });

    test('ConsequenceEntry round-trips', () {
      final entry = ConsequenceEntry(
        roundIndex: 3,
        description: 'accent challenge',
        servedAt: DateTime.utc(2026, 8, 23),
      );
      expect(ConsequenceEntry.fromJson(entry.toJson()), entry);
    });
  });

  group('Round (§11)', () {
    Round buildRound() => const Round(
      id: 'r0',
      roundIndex: 0,
      startingPlayerIndex: 0,
      topicId: 'pagkain',
      word: 'Jollibee',
      imposterClue: 'a place you go with family',
      clueTierUsed: ClueTier.loose,
      imposterPlayerIds: ['p2'],
      roundaboutsRequired: 2,
    );

    test('identifies roles and reveals (§5, §9b consistency rule)', () {
      final round = buildRound();
      expect(round.isImposter('p2'), isTrue);
      expect(round.isImposter('p0'), isFalse);
      expect(round.roleOf('p2'), PlayerRole.imposter);
      expect(round.roleOf('p0'), PlayerRole.crew);
      expect(round.revealFor('p0'), round.word);
      expect(round.revealFor('p2'), round.imposterClue);
    });

    test('round-trips through JSON with votes and a resolution', () {
      final round = buildRound().copyWith(
        votes: const [Vote(voterId: 'p0', accusedId: 'p2')],
        itemUsages: const [
          ItemUsage(
            playerId: 'p1',
            itemId: 'item_shield',
            roleAtUse: PlayerRole.crew,
            phase: ItemUsePhase.voting,
          ),
        ],
        playerPickEvents: const [
          PlayerPickEvent(
            playerId: 'p1',
            eventId: 'taboo',
            payload: ['masarap', 'kain'],
          ),
        ],
        resolution: const RoundResolution(
          targetPlayerId: 'p2',
          targetWasImposter: true,
          lifeDeltas: [
            LifeDelta(
              playerId: 'p2',
              delta: -2,
              sources: [LifeChangeSource.caughtImposter],
            ),
          ],
        ),
      );

      final decoded = Round.fromJson(round.toJson());
      expect(decoded.votes.single.accusedId, 'p2');
      expect(decoded.itemUsages.single.itemId, 'item_shield');
      expect(decoded.playerPickEvents.single.payload, ['masarap', 'kain']);
      expect(decoded.resolution?.targetWasImposter, isTrue);
      expect(
        decoded.resolution?.lifeDeltas.single.sources,
        [LifeChangeSource.caughtImposter],
      );
    });

    test('RoundResolution reports 0 for a player it never touched', () {
      const resolution = RoundResolution(
        lifeDeltas: [LifeDelta(playerId: 'p1', delta: -1)],
      );
      expect(resolution.deltaFor('p1'), -1);
      expect(resolution.deltaFor('p9'), 0);
    });

    test('Vote defaults to weight 1 and round-trips', () {
      const vote = Vote(voterId: 'p0', accusedId: 'p1');
      expect(vote.tallyWeight, 1);
      expect(Vote.fromJson(vote.toJson()), vote);
    });
  });

  group('settings (§2, §9a)', () {
    test('RoomSettings round-trips through JSON', () {
      final settings = settingsFor(8, lives: 4, imposters: 2, earlyEnd: 2);
      final decoded = RoomSettings.fromJson(settings.toJson());
      expect(decoded, settings);
    });

    test('TopicWeight round-trips', () {
      const weight = TopicWeight(topicId: 'kpop', weightPercent: 60);
      expect(TopicWeight.fromJson(weight.toJson()), weight);
    });

    test('an empty event list falls back to each event default (§9a)', () {
      const settings = InterferenceSettings(enabled: true);
      expect(
        settings.isEventEnabled('anything', defaultEnabled: true),
        isTrue,
      );
      expect(
        settings.isEventEnabled(
          InterferenceCatalogue.suddenDeath,
          defaultEnabled: false,
        ),
        isFalse,
        reason: 'Sudden Death is off by default (§9c)',
      );
    });

    test('an explicit list overrides the defaults in both directions', () {
      const settings = InterferenceSettings(
        enabled: true,
        enabledEventIds: [InterferenceCatalogue.suddenDeath],
      );
      expect(
        settings.isEventEnabled(
          InterferenceCatalogue.suddenDeath,
          defaultEnabled: false,
        ),
        isTrue,
        reason: 'a host may allow it explicitly',
      );
      expect(
        settings.isEventEnabled(
          InterferenceCatalogue.bonusLife,
          defaultEnabled: true,
        ),
        isFalse,
        reason: 'not on the list, so disabled even though it defaults on',
      );
    });

    test('InterferenceSettings round-trips', () {
      const settings = InterferenceSettings(
        enabled: true,
        playerPickEnabled: true,
        playerPickProbability: 0.4,
        enabledEventIds: ['bonus_life'],
      );
      expect(InterferenceSettings.fromJson(settings.toJson()), settings);
    });
  });

  group('interference catalogue (§9b, §9c)', () {
    test('definitions round-trip through JSON', () {
      final event = InterferenceCatalogue.byId(
        InterferenceCatalogue.taboo,
      )!;
      final decoded = InterferenceEventDefinition.fromJson(event.toJson());
      expect(decoded, event);
      expect(decoded.enforcement, EventEnforcement.retroactive);
      expect(decoded.requiresRoundabout, isTrue);
    });

    test('byId returns null for an unknown id', () {
      expect(InterferenceCatalogue.byId('not_an_event'), isNull);
    });

    test('item-system events are flagged so the toggle can gate them', () {
      final itemDrop = InterferenceCatalogue.byId(
        InterferenceCatalogue.itemDrop,
      )!;
      expect(itemDrop.requiresItemSystem, isTrue);

      final mystery = InterferenceCatalogue.byId(
        InterferenceCatalogue.mysteryItem,
      )!;
      expect(mystery.requiresItemSystem, isTrue);
    });
  });

  group('Room (§11)', () {
    test('round-trips through JSON', () {
      final room = Room(
        id: 'room-1',
        settings: settingsFor(5),
        players: makePlayers(5),
        mayorPlayerId: 'p2',
        vibePackId: 'placeholder',
        status: RoomStatus.inRound,
        usedWords: const ['Jollibee'],
        topicHistory: const ['pagkain'],
      );
      final decoded = Room.fromJson(room.toJson());
      expect(decoded.id, 'room-1');
      expect(decoded.players, hasLength(5));
      expect(decoded.mayorPlayerId, 'p2');
      expect(decoded.status, RoomStatus.inRound);
      expect(decoded.usedWords, ['Jollibee']);
    });

    test('finds the current round by index', () {
      const round = Round(
        id: 'r1',
        roundIndex: 1,
        startingPlayerIndex: 1,
        topicId: 'pagkain',
        word: 'w',
        imposterClue: 'c',
        clueTierUsed: ClueTier.standard,
        imposterPlayerIds: ['p0'],
      );
      final room = Room(
        id: 'room',
        settings: settingsFor(4),
        players: makePlayers(4),
        currentRoundIndex: 1,
        rounds: const [round],
      );
      expect(room.currentRound?.id, 'r1');
      expect(room.playersWhoServedForfeit, 0);
    });
  });
}
