import 'package:diakooi/engine/models/enums.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'interference.freezed.dart';
part 'interference.g.dart';

/// Definition of one interference event (§11).
///
/// [InterferenceCatalogue] is the single source of truth for what exists;
/// nothing else in the engine hardcodes an event id.
@freezed
abstract class InterferenceEventDefinition with _$InterferenceEventDefinition {
  const factory InterferenceEventDefinition({
    required String id,
    required EventCategory category,
    required String name,
    required String description,
    required EventEnforcement enforcement,

    /// Lap-dependent, so suppressed when No Roundabouts is the modifier (§9f).
    @Default(false) bool requiresRoundabout,

    /// v2 audit flag (§17). Unused in v1.
    @Default(false) bool requiresColocation,

    /// Only eligible when the Item System toggle is on (§9a).
    @Default(false) bool requiresItemSystem,

    /// Sudden Death only (§7b).
    @Default(false) bool bypassesDamageCap,
    @Default(true) bool defaultEnabled,
  }) = _InterferenceEventDefinition;

  factory InterferenceEventDefinition.fromJson(Map<String, dynamic> json) =>
      _$InterferenceEventDefinitionFromJson(json);
}

/// Every event in §9b and §9c, plus the item ids of §9d.
///
/// Ids are stable strings: they are persisted in `enabledEventIds` and appear
/// in saved rounds.
abstract final class InterferenceCatalogue {
  // -- §9b Player-Pick Events -------------------------------------------
  static const bonusLife = 'bonus_life';
  static const lifeDrain = 'life_drain';
  static const stealLife = 'steal_life';
  static const mysteryItem = 'mystery_item';
  static const theFool = 'the_fool';
  static const doubleVote = 'double_vote';
  static const voteLock = 'vote_lock';
  static const marked = 'marked';
  static const silentRound = 'silent_round';
  static const whisperOnly = 'whisper_only';
  static const oneWordOnly = 'one_word_only';
  static const copycat = 'copycat';
  static const liarsTax = 'liars_tax';
  static const interrogation = 'interrogation';
  static const taboo = 'taboo';
  static const nothing = 'nothing';

  // -- §9c Round-Start Events -------------------------------------------
  static const doubleDamage = 'double_damage';
  static const mercyRound = 'mercy_round';
  static const blindVote = 'blind_vote';
  static const reverseRound = 'reverse_round';
  static const doubleImposter = 'double_imposter';
  static const noRoundabouts = 'no_roundabouts';
  static const extraRoundabout = 'extra_roundabout';
  static const itemDrop = 'item_drop';
  static const foolsRound = 'fools_round';
  static const oneWordRound = 'one_word_round';
  static const reverseOrder = 'reverse_order';
  static const nearUnanimous = 'near_unanimous';
  static const spreadTheBlame = 'spread_the_blame';
  static const suddenDeath = 'sudden_death';
  static const theChain = 'the_chain';
  static const silentRoundAll = 'silent_round_all';
  static const categoryReveal = 'category_reveal';
  static const doubleClue = 'double_clue';
  static const blackout = 'blackout';
  static const highStakes = 'high_stakes';
  static const bodyguard = 'bodyguard';

  // -- §9d Items ---------------------------------------------------------
  static const itemShield = 'item_shield';
  static const itemMirror = 'item_mirror';
  static const itemVeto = 'item_veto';
  static const itemPeek = 'item_peek';
  static const itemReword = 'item_reword';
  static const itemCrosscheck = 'item_crosscheck';
  static const itemMegaphone = 'item_megaphone';
  static const itemSilencer = 'item_silencer';
  static const itemDecoy = 'item_decoy';
  static const itemWildCard = 'item_wild_card';

  /// Player-pick events, §9b in table order.
  static const List<InterferenceEventDefinition> playerPickEvents = [
    InterferenceEventDefinition(
      id: bonusLife,
      category: EventCategory.playerPick,
      name: 'Bonus Life',
      description: 'Plus 1 life, capped at the game max.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: lifeDrain,
      category: EventCategory.playerPick,
      name: 'Life Drain',
      description: 'Minus 1 life immediately.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: stealLife,
      category: EventCategory.playerPick,
      name: 'Steal a Life',
      description: 'Steal 1 life from a random other player.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: mysteryItem,
      category: EventCategory.playerPick,
      name: 'Mystery Item',
      description: 'Receive a random item.',
      enforcement: EventEnforcement.app,
      requiresItemSystem: true,
    ),
    InterferenceEventDefinition(
      id: theFool,
      category: EventCategory.playerPick,
      name: 'The Fool',
      description:
          'If this player becomes the vote target they gain a life instead of '
          'losing one. Secret.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: doubleVote,
      category: EventCategory.playerPick,
      name: 'Double Vote',
      description: 'Their accusation carries tally weight 2. Damage still 1.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: voteLock,
      category: EventCategory.playerPick,
      name: 'Vote Lock',
      description: 'Immune from being named this round.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: marked,
      category: EventCategory.playerPick,
      name: 'Marked',
      description:
          'Visible marker on their tile. The table knows interference touched '
          'them, not what.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: silentRound,
      category: EventCategory.playerPick,
      name: 'Silent Round',
      description: 'Gestures only, no speaking, next lap.',
      enforcement: EventEnforcement.social,
      requiresRoundabout: true,
    ),
    InterferenceEventDefinition(
      id: whisperOnly,
      category: EventCategory.playerPick,
      name: 'Whisper Only',
      description: 'Must whisper their clue.',
      enforcement: EventEnforcement.social,
      requiresRoundabout: true,
    ),
    InterferenceEventDefinition(
      id: oneWordOnly,
      category: EventCategory.playerPick,
      name: 'One Word Only',
      description: 'Clue must be exactly one word.',
      enforcement: EventEnforcement.social,
      requiresRoundabout: true,
    ),
    InterferenceEventDefinition(
      id: copycat,
      category: EventCategory.playerPick,
      name: 'Copycat',
      description: 'Must work a previously spoken clue word into theirs.',
      enforcement: EventEnforcement.social,
      requiresRoundabout: true,
    ),
    InterferenceEventDefinition(
      id: liarsTax,
      category: EventCategory.playerPick,
      name: "Liar's Tax",
      description:
          'Must give a deliberately misleading clue, even as crew. Secret.',
      enforcement: EventEnforcement.social,
      requiresRoundabout: true,
    ),
    InterferenceEventDefinition(
      id: interrogation,
      category: EventCategory.playerPick,
      name: 'Interrogation',
      description:
          'Must answer one yes/no question truthfully before the vote.',
      enforcement: EventEnforcement.social,
    ),
    InterferenceEventDefinition(
      id: taboo,
      category: EventCategory.playerPick,
      name: 'Taboo',
      description:
          'Two or three banned words, reconciled at the end of the lap.',
      enforcement: EventEnforcement.retroactive,
      requiresRoundabout: true,
    ),
    InterferenceEventDefinition(
      id: nothing,
      category: EventCategory.playerPick,
      name: 'Nothing',
      description: 'No event. Keeps rolls genuinely uncertain.',
      enforcement: EventEnforcement.app,
    ),
  ];

  /// Round-start events, §9c in table order.
  static const List<InterferenceEventDefinition> roundStartEvents = [
    InterferenceEventDefinition(
      id: doubleDamage,
      category: EventCategory.roundStart,
      name: 'Double Damage',
      description: 'Accuser damage doubles.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: mercyRound,
      category: EventCategory.roundStart,
      name: 'Mercy Round',
      description: 'No life is lost this round from any source.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: blindVote,
      category: EventCategory.roundStart,
      name: 'Blind Vote',
      description: 'Grid hides names and selfies until the tally locks.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: reverseRound,
      category: EventCategory.roundStart,
      name: 'Reverse Round',
      description:
          'Naming an imposter costs each accuser 1. Naming crew costs the '
          'accused 2.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: doubleImposter,
      category: EventCategory.roundStart,
      name: 'Double Imposter',
      description: 'Imposter count plus 1, capped at 4, before assignment.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: noRoundabouts,
      category: EventCategory.roundStart,
      name: 'No Roundabouts',
      description: 'Straight to voting. Suppresses lap-dependent events.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: extraRoundabout,
      category: EventCategory.roundStart,
      name: 'Extra Roundabout',
      description: 'Plus 1 lap this round.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: itemDrop,
      category: EventCategory.roundStart,
      name: 'Item Drop',
      description: 'Every player gets a Mystery Item.',
      enforcement: EventEnforcement.app,
      requiresItemSystem: true,
    ),
    InterferenceEventDefinition(
      id: foolsRound,
      category: EventCategory.roundStart,
      name: "Fool's Round",
      description: 'The vote target gains a life. Announced in advance.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: oneWordRound,
      category: EventCategory.roundStart,
      name: 'One Word Round',
      description: 'Every clue must be a single word.',
      enforcement: EventEnforcement.social,
      requiresRoundabout: true,
    ),
    InterferenceEventDefinition(
      id: reverseOrder,
      category: EventCategory.roundStart,
      name: 'Reverse Order',
      description: 'Pass order runs backwards, inverting the §6a rotation.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: nearUnanimous,
      category: EventCategory.roundStart,
      name: 'Near-Unanimous',
      description:
          'The vote only lands if 75 percent or more name the same target, '
          'otherwise a wash.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: spreadTheBlame,
      category: EventCategory.roundStart,
      name: 'Spread the Blame',
      description: 'No more than 2 players may name the same suspect.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: suddenDeath,
      category: EventCategory.roundStart,
      name: 'Sudden Death',
      description:
          'Vote target loses all remaining lives. Bypasses the damage cap.',
      enforcement: EventEnforcement.app,
      bypassesDamageCap: true,
      defaultEnabled: false,
    ),
    InterferenceEventDefinition(
      id: theChain,
      category: EventCategory.roundStart,
      name: 'The Chain',
      description:
          'Each clue must start with the last letter of the previous clue.',
      enforcement: EventEnforcement.social,
      requiresRoundabout: true,
    ),
    InterferenceEventDefinition(
      id: silentRoundAll,
      category: EventCategory.roundStart,
      name: 'Silent Round (all)',
      description: 'Nobody speaks; the whole lap is gestures.',
      enforcement: EventEnforcement.social,
      requiresRoundabout: true,
    ),
    InterferenceEventDefinition(
      id: categoryReveal,
      category: EventCategory.roundStart,
      name: 'Category Reveal',
      description: 'Imposters are told the topic. Crew knows this happened.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: doubleClue,
      category: EventCategory.roundStart,
      name: 'Double Clue',
      description: 'Every crew player gives two clues per lap.',
      enforcement: EventEnforcement.social,
      requiresRoundabout: true,
    ),
    InterferenceEventDefinition(
      id: blackout,
      category: EventCategory.roundStart,
      name: 'Blackout',
      description: 'Reveal card auto-hides after a few seconds.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: highStakes,
      category: EventCategory.roundStart,
      name: 'High Stakes',
      description: 'Forfeits triggered this round come in pairs.',
      enforcement: EventEnforcement.app,
    ),
    InterferenceEventDefinition(
      id: bodyguard,
      category: EventCategory.roundStart,
      name: 'Bodyguard',
      description:
          'One random crew player is secretly immune this round. They are not '
          'told.',
      enforcement: EventEnforcement.app,
    ),
  ];

  /// Every defined event, both categories.
  static List<InterferenceEventDefinition> get all => [
    ...playerPickEvents,
    ...roundStartEvents,
  ];

  static InterferenceEventDefinition? byId(String id) {
    for (final event in all) {
      if (event.id == id) return event;
    }
    return null;
  }

  /// Lap-dependent player-pick events, removed from the pool when No
  /// Roundabouts is the modifier (§9f suppression).
  static List<String> get lapDependentPlayerPickIds => [
    for (final e in playerPickEvents)
      if (e.requiresRoundabout) e.id,
  ];

  /// Every item id (§9d), in table order.
  static const List<String> itemIds = [
    itemShield,
    itemMirror,
    itemVeto,
    itemPeek,
    itemReword,
    itemCrosscheck,
    itemMegaphone,
    itemSilencer,
    itemDecoy,
    itemWildCard,
  ];
}
