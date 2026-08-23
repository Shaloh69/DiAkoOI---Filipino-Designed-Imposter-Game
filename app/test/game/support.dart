import 'package:diakooi/engine/engine.dart';
import 'package:diakooi/game/game_controller.dart';

/// A word bank big enough that no test ever exhausts a topic.
///
/// [WordSelector.draw] throws rather than repeating a word inside a session
/// (§13b), so a thin bank would surface as a confusing StateError halfway
/// through an unrelated test.
List<WordBankEntry> fakeBank({
  List<String> topicIds = const ['pagkain', 'kpop', 'basketball'],
  int wordsPerTopic = 40,
}) => [
  for (final topicId in topicIds)
    for (var i = 0; i < wordsPerTopic; i++)
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

RoomSettings settingsFor({
  required int playerCount,
  int totalRounds = 3,
  int livesPerPlayer = 3,
  int roundaboutsPerRound = 2,
  int? imposterCount = 1,
  int? earlyEndConsequenceThreshold,
  List<TopicWeight>? topicWeights,
}) => RoomSettings.validated(
  playerCount: playerCount,
  totalRounds: totalRounds,
  livesPerPlayer: livesPerPlayer,
  roundaboutsPerRound: roundaboutsPerRound,
  imposterCount: imposterCount,
  earlyEndConsequenceThreshold: earlyEndConsequenceThreshold,
  topicWeights:
      topicWeights ??
      const [
        TopicWeight(topicId: 'pagkain', weightPercent: 40),
        TopicWeight(topicId: 'kpop', weightPercent: 30),
        TopicWeight(topicId: 'basketball', weightPercent: 30),
      ],
);

/// A controller with a roster already seated and a game ready to start.
GameController seatedController({
  required int playerCount,
  int totalRounds = 3,
  int seed = 7,
  RoomSettings? settings,
}) {
  final resolved =
      settings ??
      settingsFor(playerCount: playerCount, totalRounds: totalRounds);
  final controller = GameController(wordBank: fakeBank(), rng: SeededRng(seed))
    ..configure(resolved)
    ..rollVibe('tugtog')
    ..beginOnboarding();
  for (var i = 0; i < resolved.playerCount; i++) {
    controller.addPlayer(name: 'Player ${i + 1}');
  }
  return controller;
}

/// Runs one whole round: distribute, discuss, vote, resolve, life check.
///
/// [accuse] maps a voter's id to the id they accuse; anyone missing votes for
/// the next seat along, so a round always has a full ballot.
void playRound(
  GameController controller, {
  Map<String, String> accuse = const {},
}) {
  controller
    ..startRound()
    ..beginDistribution();
  for (final seat in controller.session.seats) {
    controller
      ..revealFor(seat.id)
      ..markRevealSeen();
  }

  controller.beginDiscussion();
  while (controller.lapsRemaining) {
    controller.completeLap();
  }

  controller.beginVoting();
  final seats = controller.session.seats;
  for (var i = 0; i < seats.length; i++) {
    final voter = seats[i].id;
    final accused = accuse[voter] ?? seats[(i + 1) % seats.length].id;
    controller
      ..selectVoter(voter)
      ..recordAccusation(accused);
  }

  controller
    ..resolve()
    ..applyLifeCheck();
}
