import 'package:diakooi/engine/models/enums.dart';
import 'package:diakooi/engine/models/interference.dart';
import 'package:diakooi/engine/models/round.dart';

/// Everything bending this round's resolution (§9).
///
/// Grouped into one value so `resolveRound` keeps the signature the design
/// calls for — `(votes, roles, modifiers, itemUsages) -> lifeDeltas` — rather
/// than growing a parameter per event.
class RoundModifiers {
  const RoundModifiers({
    this.roundModifier,
    this.playerPickEvents = const [],
    this.bodyguardPlayerId,
    this.tabooSlips = const [],
    this.stealTargets = const {},
  });

  /// The single §9c event for this round, or null.
  final String? roundModifier;

  /// §9b events that landed on individual players.
  final List<PlayerPickEvent> playerPickEvents;

  /// The crew member secretly immune this round (§9c Bodyguard). They are not
  /// told, so this never reaches the UI.
  final String? bodyguardPlayerId;

  /// Players the table judged to have slipped during Taboo reconciliation
  /// (§9b). Adjudicated by the host, so it arrives as input.
  final List<String> tabooSlips;

  /// Steal a Life: thief id -> victim id (§9b). Resolved before this call so
  /// the pure function stays free of randomness.
  final Map<String, String> stealTargets;

  bool has(String eventId) => roundModifier == eventId;

  bool playerHas(String playerId, String eventId) => playerPickEvents.any(
    (e) => e.playerId == playerId && e.eventId == eventId,
  );
}

/// Resolves one round's voting into life changes.
///
/// **Pure**: same inputs, same output, no clock, no randomness, no I/O. Every
/// roll that would need randomness — who Steal a Life hits, who the Bodyguard
/// is — is resolved by the caller and passed in, so a transcript replays
/// exactly (A1).
///
/// Order of operations follows the §9f stacking precedence:
///   1. player-pick effects (individual, immediate)
///   2. round-start modifiers (global)
///   3. items (holder chose the timing, so they get the last word)
///   4. the §7b damage clamp, applied last
///
/// Where two effects contradict, **the effect that protects a player wins**.
RoundResolution resolveRound({
  required List<Vote> votes,
  required Map<String, PlayerRole> roles,
  required RoundModifiers modifiers,
  required List<ItemUsage> itemUsages,
  required Map<String, int> currentLives,
  String? mayorPlayerId,
}) {
  final tally = _tally(votes, modifiers);
  final target = _resolveTarget(
    votes: votes,
    tally: tally,
    modifiers: modifiers,
    mayorPlayerId: mayorPlayerId,
    voterCount: roles.length,
  );

  // Veto cancels the round's vote result entirely (§9d). It is played after
  // the tally shows, so it lands here rather than at the top.
  final vetoed = itemUsages.any(
    (u) => u.itemId == InterferenceCatalogue.itemVeto,
  );

  final ledger = _Ledger();

  // ── 1. Player-pick effects, independent of the vote ──────────────────
  _applyPlayerPickEffects(ledger, modifiers);

  // ── 2. The vote itself ───────────────────────────────────────────────
  final washed = vetoed || target == null;
  if (!washed) {
    _applyVoteOutcome(
      ledger: ledger,
      target: target,
      votes: votes,
      roles: roles,
      modifiers: modifiers,
      currentLives: currentLives,
    );
  }

  // ── 3. Items ─────────────────────────────────────────────────────────
  _applyItems(ledger, itemUsages);

  // ── 4. Protection, then the §7b clamp ────────────────────────────────
  _applyProtection(ledger, modifiers);

  // Mercy Round is explicitly total: no life is lost this round from any
  // source — vote resolution, Life Drain, Taboo, all of it (§9c). Gains are
  // left alone, because "the effect that protects a player wins".
  if (modifiers.has(InterferenceCatalogue.mercyRound)) {
    ledger.dropAllLosses();
  }

  final bypassesCap = modifiers.has(InterferenceCatalogue.suddenDeath);
  final capped = bypassesCap ? <String>[] : ledger.clampLosses(maxLoss: 2);

  return RoundResolution(
    targetPlayerId: target,
    targetWasImposter: target != null && roles[target] == PlayerRole.imposter,
    wasWash: washed,
    lifeDeltas: ledger.toDeltas(),
    cappedPlayerIds: capped,
  );
}

/// Vote tally. Weights count here and **only** here (§7).
///
/// Self-votes and votes against a Vote Lock player are dropped: the grid
/// rejects both, and the engine refuses them too so a malformed transcript
/// cannot produce a result the UI could never have created.
Map<String, int> _tally(List<Vote> votes, RoundModifiers modifiers) {
  final tally = <String, int>{};
  for (final vote in _legalVotes(votes, modifiers)) {
    tally[vote.accusedId] = (tally[vote.accusedId] ?? 0) + vote.tallyWeight;
  }
  return tally;
}

List<Vote> _legalVotes(List<Vote> votes, RoundModifiers modifiers) {
  final counts = <String, int>{};
  final legal = <Vote>[];
  for (final vote in votes) {
    if (vote.voterId == vote.accusedId) continue;
    if (modifiers.playerHas(vote.accusedId, InterferenceCatalogue.voteLock)) {
      continue;
    }
    // Spread the Blame caps duplicates at 2 (§9c). A hard no-duplicates ban
    // was mathematically unresolvable: N voters across N tiles gives every
    // tile one vote and a permanent N-way tie.
    if (modifiers.has(InterferenceCatalogue.spreadTheBlame)) {
      final used = counts[vote.accusedId] ?? 0;
      if (used >= InterferenceCatalogue.spreadTheBlameCap) continue;
      counts[vote.accusedId] = used + 1;
    }
    legal.add(vote);
  }
  return legal;
}

/// The tile with the most votes, or null for a wash (§7, §7a, §9c).
String? _resolveTarget({
  required List<Vote> votes,
  required Map<String, int> tally,
  required RoundModifiers modifiers,
  required String? mayorPlayerId,
  required int voterCount,
}) {
  if (tally.isEmpty) return null;

  final highest = tally.values.reduce((a, b) => a > b ? a : b);
  final tied = [
    for (final entry in tally.entries)
      if (entry.value == highest) entry.key,
  ]..sort(); // Deterministic order so transcripts replay byte-identically.

  // Near-Unanimous: the vote only lands if 75% or more named the same target
  // (§9c). A threshold rather than true unanimity — under true unanimity a
  // single imposter names someone nobody else did and buys a free round.
  if (modifiers.has(InterferenceCatalogue.nearUnanimous)) {
    if (tied.length != 1) return null;
    final headcount = _legalVotes(
      votes,
      modifiers,
    ).where((v) => v.accusedId == tied.first).length;
    if (voterCount == 0) return null;
    if (headcount / voterCount < InterferenceCatalogue.nearUnanimousThreshold) {
      return null;
    }
  }

  if (tied.length == 1) return tied.first;

  // ── §7a Mayor tie rule ────────────────────────────────────────────────
  // The Mayor's weight applies ONLY when a tie exists. Weighting their vote
  // at 1.5 always was the v3 bug: their tile could then never tie with an
  // integer tile, so the Mayor could not break any tie that actually occurred.
  if (mayorPlayerId == null) return null;

  // A tie in which the Mayor is one of the accused is a wash.
  if (tied.contains(mayorPlayerId)) return null;

  for (final vote in _legalVotes(votes, modifiers)) {
    if (vote.voterId == mayorPlayerId && tied.contains(vote.accusedId)) {
      return vote.accusedId;
    }
  }

  // The Mayor named none of the tied tiles.
  return null;
}

void _applyPlayerPickEffects(_Ledger ledger, RoundModifiers modifiers) {
  for (final event in modifiers.playerPickEvents) {
    switch (event.eventId) {
      case InterferenceCatalogue.bonusLife:
        ledger.add(event.playerId, 1, LifeChangeSource.bonusLife);
      case InterferenceCatalogue.lifeDrain:
        ledger.add(event.playerId, -1, LifeChangeSource.lifeDrain);
      case InterferenceCatalogue.stealLife:
        final victim = modifiers.stealTargets[event.playerId];
        // No victim resolved (a table of one other player who is untargetable,
        // say) means the steal fizzles rather than throwing.
        if (victim == null) continue;
        ledger
          ..add(event.playerId, 1, LifeChangeSource.stealLifeGain)
          ..add(victim, -1, LifeChangeSource.stealLifeLoss);
      default:
        // Every other §9b event is behavioural, informational or social. They
        // are listed in the catalogue and carried on the round for the UI and
        // the recap, but they move no lives here.
        continue;
    }
  }

  for (final playerId in modifiers.tabooSlips) {
    ledger.add(playerId, -1, LifeChangeSource.tabooSlip);
  }
}

void _applyVoteOutcome({
  required _Ledger ledger,
  required String target,
  required List<Vote> votes,
  required Map<String, PlayerRole> roles,
  required RoundModifiers modifiers,
  required Map<String, int> currentLives,
}) {
  final targetIsImposter = roles[target] == PlayerRole.imposter;
  final accusers = [
    for (final vote in _legalVotes(votes, modifiers))
      if (vote.accusedId == target) vote.voterId,
  ];

  // The Fool (§9b) and Fool's Round (§9c): the target gains instead of losing.
  // Checked before anything else because it protects, and protection wins.
  final foolApplies =
      modifiers.playerHas(target, InterferenceCatalogue.theFool) ||
      modifiers.has(InterferenceCatalogue.foolsRound);
  if (foolApplies) {
    ledger.add(target, 1, LifeChangeSource.foolBonus);
    return;
  }

  // Sudden Death drains the target outright and bypasses the §7b cap (§9c).
  if (modifiers.has(InterferenceCatalogue.suddenDeath)) {
    final lives = currentLives[target] ?? 0;
    if (lives > 0) {
      ledger.add(target, -lives, LifeChangeSource.suddenDeath);
    }
    return;
  }

  // Reverse Round inverts the core rule (§9c): naming an imposter costs each
  // accuser 1, naming crew costs the accused 2.
  if (modifiers.has(InterferenceCatalogue.reverseRound)) {
    if (targetIsImposter) {
      for (final accuser in accusers) {
        ledger.add(accuser, -1, LifeChangeSource.reverseRoundAccuser);
      }
    } else {
      ledger.add(target, -2, LifeChangeSource.reverseRoundAccused);
    }
    return;
  }

  if (targetIsImposter) {
    // A caught imposter takes 2 — already the §7b cap, which is why Double
    // Damage never doubles imposter damage. Nobody else loses anything.
    ledger.add(target, -2, LifeChangeSource.caughtImposter);
    return;
  }

  // Accuser-pays: only the players who named this crew member lose a life.
  // Players who named an actual imposter lose nothing, even in the minority.
  // Vote weight does not appear here — it is tally-only (§7).
  final perAccuser = modifiers.has(InterferenceCatalogue.doubleDamage)
      ? -2
      : -1;
  for (final accuser in accusers) {
    ledger.add(accuser, perAccuser, LifeChangeSource.wrongAccusation);
  }
}

void _applyItems(_Ledger ledger, List<ItemUsage> itemUsages) {
  for (final usage in itemUsages) {
    switch (usage.itemId) {
      case InterferenceCatalogue.itemShield:
        // Cancels the next life loss (§9d).
        ledger.cancelLoss(usage.playerId);
      case InterferenceCatalogue.itemMirror:
        // Reflects the next life loss onto whoever caused it (§9d). Without a
        // named target there is nobody to reflect onto, so it behaves as a
        // plain cancel — protective either way.
        final reflected = ledger.cancelLoss(usage.playerId);
        final target = usage.targetPlayerId;
        if (reflected != 0 && target != null) {
          ledger.add(target, reflected, LifeChangeSource.mirrorReflection);
        }
      default:
        // Veto is handled before the vote is applied. Peek, Reword,
        // Crosscheck, Megaphone, Silencer, Decoy and Wild Card change
        // information, tally weight or pass order, never life totals.
        continue;
    }
  }
}

void _applyProtection(_Ledger ledger, RoundModifiers modifiers) {
  final bodyguarded = modifiers.bodyguardPlayerId;
  if (bodyguarded != null) {
    ledger.cancelLoss(bodyguarded);
  }
}

/// Accumulates life changes with their causes, then flattens to deltas.
class _Ledger {
  final Map<String, int> _deltas = {};
  final Map<String, List<LifeChangeSource>> _sources = {};

  void add(String playerId, int amount, LifeChangeSource source) {
    if (amount == 0) return;
    _deltas[playerId] = (_deltas[playerId] ?? 0) + amount;
    (_sources[playerId] ??= []).add(source);
  }

  /// Removes any net loss for [playerId], returning the amount cancelled as a
  /// negative number (0 if there was nothing to cancel).
  int cancelLoss(String playerId) {
    final current = _deltas[playerId] ?? 0;
    if (current >= 0) return 0;
    _deltas[playerId] = 0;
    return current;
  }

  /// Mercy Round: drop every loss, keep every gain (§9c).
  void dropAllLosses() {
    for (final id in _deltas.keys.toList()) {
      final value = _deltas[id]!;
      if (value < 0) _deltas[id] = 0;
    }
  }

  /// §7b: no player loses more than [maxLoss] in a round from all sources
  /// combined. Applied as a final clamp rather than per effect, so events can
  /// stay written as powerful.
  List<String> clampLosses({required int maxLoss}) {
    final capped = <String>[];
    for (final id in _deltas.keys.toList()) {
      final value = _deltas[id]!;
      if (value < -maxLoss) {
        _deltas[id] = -maxLoss;
        capped.add(id);
      }
    }
    return capped..sort();
  }

  List<LifeDelta> toDeltas() {
    final ids = _deltas.keys.toList()..sort();
    return [
      for (final id in ids)
        if (_deltas[id] != 0)
          LifeDelta(
            playerId: id,
            delta: _deltas[id]!,
            sources: List.unmodifiable(_sources[id] ?? const []),
          ),
    ];
  }
}
