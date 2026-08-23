# ADR 0014 — The interference roller has two phases, because §9c's ordering demands it

**Status:** Accepted · **Date:** 2026-08-24

## Context

Phase 1 built the whole of §9's *resolution* — Spread the Blame capped at 2, Near-Unanimous
at 75%, Mercy Round blocking every source, the §9f precedence order, and contradictions
resolving toward whichever effect protects a player. What did not exist in production code
was the thing that decides **what fires**. A copy of that logic lived in
`test/engine/game_simulator.dart`, which meant the A1 property tests were asserting against
the simulator's idea of §9 rather than the app's.

Two §9c events also reach backwards into round setup rather than merely modifying a round:

- **Double Imposter** sets the count `min(n + 1, 4)` **before assignment**, so the extra
  imposter receives the vague clue like any other.
- **No Roundabouts** suppresses every lap-dependent player-pick event, so it has to be known
  before the player-pick pool is built.

And one event reaches *forwards* into information the modifier roll does not have:

- **Bodyguard** makes a random **crew** member secretly immune — and roles do not exist yet
  when the modifier is drawn.

A single `roll()` returning everything at once cannot express any of the three.

## Decision

**Two ordered phases, named for what they can and cannot know.**

```
rollModifier(settings, roundIndex, rng)      -> String?   // before assignment
imposterCountFor(settings, roundModifier)    -> int       // Double Imposter applies here
ImposterAssigner.assign(...)                             // roles now exist
rollDetails(settings, players, imposterIds, roundModifier, rng) -> InterferenceRoll
```

`InterferenceRoll` is a value, not a mutation. Every roll that would otherwise happen inside
`resolveRound` — Steal a Life's victim, the Bodyguard, Taboo's banned words, item grants — is
made here and passed in, which is what keeps the pure function pure and a seeded game
byte-identical (A1).

**The simulator now drives the production roller.** A simulation that reimplements what it
tests proves only that the copy agrees with itself.

### Eligibility is three independent gates

§9a wants a host able to allow "+1 life" while disabling "steal a life", which one on/off
switch cannot express. So: the master toggle, then the group toggle, then the per-event
checklist. On top of those sit two removals, both for the same reason:

- **Double Imposter is removed from the pool when it can do nothing** — already at 4, or the
  extra imposter would leave no crew.
- **Item events are removed when the item system is off.**

Both could have been left to roll and quietly achieve nothing. §9d names that outcome
directly: a roll that appears to do nothing is the worst result a surprise system can
produce.

## Consequences

**Good.**

- The 10,000-game A6 simulation now runs against the code the app ships.
- Ordering is expressed in the API rather than in a comment, so calling it wrongly is a type
  error rather than a subtly wrong game.
- `eligible()` is a query, which is what A6 asks for: the co-location and item-system audits
  are a filter, not a re-read of the catalogue.

**Costs.**

- Two calls where callers might expect one, and the second needs output from the first plus
  the assignment between them. The controller and the simulator are the only callers, and
  both do it in the same order.
- `requiresColocation` is checked and always satisfied in v1, because one device at one table
  always is. It stays checked rather than ignored so v2's audit is a query (§17).

## What this found

**The existing 10k run was not "all events on".** Its `enabledEventIds` lists only the
round-start events, and a non-empty list means everything absent is *disabled* — so no §9b
event had ever fired in it. The test was right about what it claimed and wrong about what it
appeared to cover.

**Double Imposter fires at 3 players with 1 imposter**, producing two imposters against a
single crew member. Legal, playable only in the thinnest sense, and exactly proposal 0002
finding 3 — imposter count has no floor on crew. Pinned by a test that says to update the
proposal rather than delete the test.
