import 'package:diakooi/engine/models/enums.dart';
import 'package:diakooi/engine/models/interference.dart';
import 'package:diakooi/engine/models/player.dart';
import 'package:diakooi/engine/models/round.dart';
import 'package:diakooi/engine/models/settings.dart';
import 'package:diakooi/engine/rng/seeded_rng.dart';

/// Everything one round's interference roll produced (§9).
///
/// A value, not a mutation: the roller decides *what happened*, and applying it
/// is `resolveRound`'s job. Keeping the two apart is what lets a seeded game
/// replay byte-identically — every roll that would otherwise happen inside the
/// pure function is made here and passed in (§9f, A1).
class InterferenceRoll {
  const InterferenceRoll({
    this.roundModifier,
    this.playerPickEvents = const [],
    this.stealTargets = const {},
    this.bodyguardPlayerId,
    this.tabooWords = const {},
    this.itemGrants = const {},
    this.imposterCountOverride,
  });

  /// The single §9c modifier, or null when nothing rolled.
  final String? roundModifier;

  /// §9b events that landed on individual players, in seat order.
  final List<PlayerPickEvent> playerPickEvents;

  /// Steal a Life: thief id -> victim id. Resolved here so the pure function
  /// stays free of randomness.
  final Map<String, String> stealTargets;

  /// The crew member secretly immune this round. They are never told (§9c).
  final String? bodyguardPlayerId;

  /// Taboo: player id -> the 2–3 words they must avoid.
  final Map<String, List<String>> tabooWords;

  /// Items handed out this roll: player id -> item id. Covers both Mystery
  /// Item (§9b) and Item Drop (§9c), which differ only in who gets one.
  final Map<String, String> itemGrants;

  /// Set only by Double Imposter, which raises the count **before** assignment
  /// so the extra imposter receives the vague clue like any other (§9c).
  final int? imposterCountOverride;

  bool get isEmpty =>
      roundModifier == null && playerPickEvents.isEmpty && itemGrants.isEmpty;

  /// The §9b event on one player, or null.
  String? eventFor(String playerId) {
    for (final event in playerPickEvents) {
      if (event.playerId == playerId) return event.eventId;
    }
    return null;
  }
}

/// Decides what interference fires, and what it may not (§9a, §9c, §9f).
///
/// **Nothing fires unless its specific toggle is on.** The master switch gates
/// all three groups, each group gates itself, and the per-event checklist gates
/// individual events — three independent levels, because §9a says a host should
/// be able to allow "+1 life" while disabling "steal a life".
abstract final class InterferenceRoller {
  /// **Phase one — before imposters are assigned.**
  ///
  /// The §9c modifier has to be drawn first and on its own, because two of the
  /// events reach backwards into setup: Double Imposter raises the count
  /// *before* assignment so the extra imposter gets the vague clue like any
  /// other, and No Roundabouts suppresses part of the player-pick pool. A
  /// single roll that returned everything at once could not express either.
  static String? rollModifier({
    required RoomSettings settings,
    required int roundIndex,
    required GameRng rng,
  }) {
    if (!_allowed(settings: settings, roundIndex: roundIndex)) return null;
    return _rollModifier(settings: settings, rng: rng);
  }

  /// The imposter count this round, after Double Imposter (§9c).
  static int imposterCountFor({
    required RoomSettings settings,
    String? roundModifier,
  }) => roundModifier == InterferenceCatalogue.doubleImposter
      ? _raisedImposterCount(settings)
      : settings.imposterCount;

  /// **Phase two — after imposters are assigned.**
  ///
  /// Everything that needs to know who the imposters are. Bodyguard is the
  /// reason this exists: §9c makes it a random **crew** member, and roles do
  /// not exist yet when the modifier is drawn.
  static InterferenceRoll rollDetails({
    required RoomSettings settings,
    required List<Player> players,
    required List<String> imposterIds,
    required int roundIndex,
    required GameRng rng,
    String? roundModifier,
    List<String> tabooWordPool = const [],
  }) {
    if (!_allowed(settings: settings, roundIndex: roundIndex)) {
      return const InterferenceRoll();
    }

    final picks = _rollPlayerPicks(
      settings: settings,
      players: players,
      modifier: roundModifier,
      rng: rng,
    );

    return InterferenceRoll(
      roundModifier: roundModifier,
      playerPickEvents: picks,
      stealTargets: _stealTargets(picks: picks, players: players, rng: rng),
      bodyguardPlayerId: _bodyguard(
        modifier: roundModifier,
        players: players,
        imposterIds: imposterIds,
        rng: rng,
      ),
      tabooWords: _tabooWords(picks: picks, pool: tabooWordPool, rng: rng),
      itemGrants: _itemGrants(
        settings: settings,
        players: players,
        picks: picks,
        modifier: roundModifier,
        rng: rng,
      ),
      imposterCountOverride:
          roundModifier == InterferenceCatalogue.doubleImposter
          ? _raisedImposterCount(settings)
          : null,
    );
  }

  /// Interference is suppressed entirely during round 1 (§3, §9f).
  ///
  /// The table is still learning the game during onboarding, and a modifier
  /// landing before anyone knows the base rules reads as the app being broken.
  static bool _allowed({
    required RoomSettings settings,
    required int roundIndex,
  }) => settings.interference.enabled && roundIndex > 0;

  /// Events a host has left switched on, for one category.
  static List<InterferenceEventDefinition> eligible({
    required RoomSettings settings,
    required EventCategory category,
    String? roundModifier,
  }) {
    final source = switch (category) {
      EventCategory.playerPick => InterferenceCatalogue.playerPickEvents,
      EventCategory.roundStart => InterferenceCatalogue.roundStartEvents,
      EventCategory.item => const <InterferenceEventDefinition>[],
    };

    return [
      for (final event in source)
        if (_isEligible(
          event: event,
          settings: settings,
          roundModifier: roundModifier,
        ))
          event,
    ];
  }

  static bool _isEligible({
    required InterferenceEventDefinition event,
    required RoomSettings settings,
    String? roundModifier,
  }) {
    if (!settings.interference.isEventEnabled(
      event.id,
      defaultEnabled: event.defaultEnabled,
    )) {
      return false;
    }
    // Item Drop and Mystery Item hand out items; without the item system they
    // would be a visible no-op, which §9d calls the worst outcome for a
    // surprise system (§9a, §9c).
    if (event.requiresItemSystem && !settings.interference.itemsEnabled) {
      return false;
    }
    // §9f suppression: No Roundabouts removes every lap-dependent event from
    // the pool, rather than letting one roll and quietly do nothing.
    if (event.requiresRoundabout &&
        roundModifier == InterferenceCatalogue.noRoundabouts) {
      return false;
    }
    // v1 is one device at one table, so co-location is always satisfied. The
    // flag is checked rather than ignored so v2's audit is a query (§17, A6).
    return true;
  }

  static String? _rollModifier({
    required RoomSettings settings,
    required GameRng rng,
  }) {
    if (!settings.interference.roundStartEnabled) return null;

    var pool = eligible(
      settings: settings,
      category: EventCategory.roundStart,
    );

    // §9c: Double Imposter rerolls into a different event when it can do
    // nothing — already at the cap of 4, or the extra imposter would leave no
    // crew. Rolling a visible no-op is the failure it exists to avoid.
    if (!_doubleImposterCanFire(settings)) {
      pool = [
        for (final event in pool)
          if (event.id != InterferenceCatalogue.doubleImposter) event,
      ];
    }
    if (pool.isEmpty) return null;
    return rng.pick(pool).id;
  }

  static bool _doubleImposterCanFire(RoomSettings settings) =>
      settings.imposterCount < RoomSettings.maxImposters &&
      settings.imposterCount + 1 < settings.playerCount;

  static int _raisedImposterCount(RoomSettings settings) {
    final raised = settings.imposterCount + 1;
    return raised > RoomSettings.maxImposters
        ? RoomSettings.maxImposters
        : raised;
  }

  static List<PlayerPickEvent> _rollPlayerPicks({
    required RoomSettings settings,
    required List<Player> players,
    required String? modifier,
    required GameRng rng,
  }) {
    if (!settings.interference.playerPickEnabled) return const [];

    final pool = eligible(
      settings: settings,
      category: EventCategory.playerPick,
      roundModifier: modifier,
    );
    if (pool.isEmpty) return const [];

    return [
      for (final player in players)
        if (rng.nextDouble() < settings.interference.playerPickProbability)
          PlayerPickEvent(playerId: player.id, eventId: rng.pick(pool).id),
    ];
  }

  static Map<String, String> _stealTargets({
    required List<PlayerPickEvent> picks,
    required List<Player> players,
    required GameRng rng,
  }) {
    final targets = <String, String>{};
    for (final pick in picks) {
      if (pick.eventId != InterferenceCatalogue.stealLife) continue;
      final candidates = [
        for (final player in players)
          if (player.id != pick.playerId) player,
      ];
      // A table of one has nobody to steal from. Leaving the entry out makes
      // it a no-op rather than a crash.
      if (candidates.isNotEmpty) {
        targets[pick.playerId] = rng.pick(candidates).id;
      }
    }
    return targets;
  }

  static String? _bodyguard({
    required String? modifier,
    required List<Player> players,
    required List<String> imposterIds,
    required GameRng rng,
  }) {
    if (modifier != InterferenceCatalogue.bodyguard) return null;
    // **Crew only** (§9c). Drawn here rather than inside `resolveRound` so the
    // pure function keeps no randomness, and never surfaced to the UI, because
    // the player is not told.
    final crew = [
      for (final player in players)
        if (!imposterIds.contains(player.id)) player,
    ];
    return crew.isEmpty ? null : rng.pick(crew).id;
  }

  /// How many words Taboo bans (§9b).
  static const tabooWordCount = 3;

  static Map<String, List<String>> _tabooWords({
    required List<PlayerPickEvent> picks,
    required List<String> pool,
    required GameRng rng,
  }) {
    final words = <String, List<String>>{};
    for (final pick in picks) {
      if (pick.eventId != InterferenceCatalogue.taboo) continue;
      if (pool.length < 2) continue;
      final take = pool.length < tabooWordCount ? pool.length : tabooWordCount;
      words[pick.playerId] = rng.sample(pool, take);
    }
    return words;
  }

  static Map<String, String> _itemGrants({
    required RoomSettings settings,
    required List<Player> players,
    required List<PlayerPickEvent> picks,
    required String? modifier,
    required GameRng rng,
  }) {
    if (!settings.interference.itemsEnabled) return const {};
    final grants = <String, String>{};

    // Item Drop gives one to everyone (§9c); Mystery Item gives one to the
    // player it landed on (§9b). Item Drop first, so a player who also rolled
    // Mystery Item ends up with the one they were individually given.
    if (modifier == InterferenceCatalogue.itemDrop) {
      for (final player in players) {
        grants[player.id] = rng.pick(InterferenceCatalogue.itemIds);
      }
    }
    for (final pick in picks) {
      if (pick.eventId != InterferenceCatalogue.mysteryItem) continue;
      grants[pick.playerId] = rng.pick(InterferenceCatalogue.itemIds);
    }
    return grants;
  }
}
