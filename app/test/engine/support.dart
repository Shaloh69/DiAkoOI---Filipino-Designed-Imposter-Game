import 'package:diakooi/engine/engine.dart';

/// Shared fixtures for the engine tests.
///
/// Deliberately small and explicit: a test that has to be read alongside a
/// builder DSL is harder to trust than one that spells out its inputs.

/// `p0`, `p1`, ... for [count] players, all on [lives].
List<Player> makePlayers(int count, {int lives = 3}) => [
  for (var i = 0; i < count; i++)
    Player(id: 'p$i', name: 'Player $i', seatOrder: i, currentLives: lives),
];

/// Roles map with [imposterIds] as imposters and everyone else crew.
Map<String, PlayerRole> makeRoles(
  List<Player> players,
  List<String> imposterIds,
) => {
  for (final p in players)
    p.id: imposterIds.contains(p.id) ? PlayerRole.imposter : PlayerRole.crew,
};

Map<String, int> makeLives(List<Player> players) => {
  for (final p in players) p.id: p.currentLives,
};

/// `voterId -> accusedId` as a vote list.
List<Vote> votesFrom(
  Map<String, String> pairs, {
  Map<String, int>? weights,
}) => [
  for (final entry in pairs.entries)
    Vote(
      voterId: entry.key,
      accusedId: entry.value,
      tallyWeight: weights?[entry.key] ?? 1,
    ),
];

/// A settings object valid enough for tests that do not care about setup.
RoomSettings settingsFor(
  int playerCount, {
  int lives = 3,
  int? imposters,
  int totalRounds = 8,
  int? earlyEnd,
  InterferenceSettings interference = const InterferenceSettings(),
}) => RoomSettings.validated(
  playerCount: playerCount,
  topicWeights: const [
    TopicWeight(topicId: 'pagkain', weightPercent: 50),
    TopicWeight(topicId: 'aktor', weightPercent: 50),
  ],
  livesPerPlayer: lives,
  imposterCount: imposters,
  totalRounds: totalRounds,
  earlyEndConsequenceThreshold: earlyEnd,
  interference: interference,
);

/// A word bank with [perTopic] entries for each of [topicIds].
List<WordBankEntry> makeBank(List<String> topicIds, {int perTopic = 5}) => [
  for (final topicId in topicIds)
    for (var i = 0; i < perTopic; i++)
      WordBankEntry(
        topicId: topicId,
        word: '$topicId-word-$i',
        clues: ClueSet(
          tight: '$topicId tight $i',
          standard: '$topicId standard $i',
          loose: '$topicId loose $i',
        ),
      ),
];
