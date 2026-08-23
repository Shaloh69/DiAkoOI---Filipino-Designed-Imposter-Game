# ADR 0011 — Topic mix rebalancing: a floor as well as a ceiling

**Status:** Accepted · **Date:** 2026-08-23

## Context

Proposal 0001 was accepted with the clamp option: the host's topic slider stops at the
arithmetic ceiling rather than accepting a value the engine would quietly ignore, and the
ceiling is **derived** from the enabled topic count and the no-repeat window
(`TopicSelector.ceilingFor`), never hardcoded.

Building the mixer surfaced a second constraint the proposal did not name. §13b also requires
the weights to total exactly 100. So moving one slider *down* is not free: whatever it gives
up lands on the other topics, and each of those is capped by the same ceiling.

With two topics in the mix and a ceiling of 66, dragging one to 5% would need the other at
95%. The engine cannot deliver that. The clamp on the way up is honest and the same UI is
dishonest on the way down.

## Decision

**Derive a floor as well as a ceiling, and rebalance point by point with per-topic caps.**

`TopicMix` exposes both bounds, and both move with the enabled count:

```
ceilingPercent = TopicSelector.ceilingPercentFor(enabledCount)
floorPercent   = max(0, 100 - (enabledCount - 1) * ceilingPercent)
```

At two topics that is a band of 34–66. At three or more the floor is 0, because there is
enough room to absorb the mass. At one topic there is nothing to trade against and the weight
is pinned at 100.

**Turning a topic off is still allowed at any weight.** Removing a topic from the draw and
starving it are different things: §13b says a topic at 0% is excluded entirely, so the mixer
gives that its own switch rather than expecting a host to drag a slider to the floor and
infer what happened. The last topic cannot be switched off — a draw with nothing in it has
no answer, and stopping the host beats handing them an empty game.

Redistribution allocates the remaining points **one at a time**, each to whichever topic is
furthest behind its proportional share and not already at the cap. Proportion-then-round is
the obvious implementation and it is wrong twice over: it can leave the total at 99, which a
host can see; and capping after rounding can push the largest topic over the ceiling. The
concrete case that motivated this: with `pagkain 10 / kpop 66 / basketball 24`, nudging
`pagkain` down to 5 hands its mass out proportionally and lands `kpop` on 70. Total ≤ 100 so
the loop is at most a hundred iterations, which is not worth optimising.

The mixer also only offers topics the bundled word bank can actually fill. `WordSelector.draw`
throws rather than repeat a word inside a session, and it is right to throw — but a host
should never be able to build a mix that throws at `ROUND_START`. The fix belongs at the
point the choice is offered, so a preset naming a topic with no words is not selectable
either.

## Consequences

**Good.**

- Every state the mixer can reach is one the engine can deliver, and
  `test/engine/topic_mix_test.dart` checks that against `TopicSelector.ceilingFor` rather
  than against a remembered 66. Raising `maxConsecutive` moves the tests with the code.
- The total is exactly 100 by construction, so `RoomSettings.validated` never rejects a mix
  the UI produced.
- One test draws 6000 topics against a mix set to the ceiling and measures the result. The
  clamp is only honest if the ceiling is genuinely deliverable, and that is what ADR 0007's
  deficit weighting buys — asserting it here means a regression there fails visibly instead
  of turning the clamp into a lie.

**Costs.**

- The two-topic band is a real restriction a host can hit, and the slider simply stops rather
  than explaining. That is the same trade proposal 0001 already accepted: a host mid-lobby
  with people waiting does not read explanatory text, and a control that stops says what it
  means without words. The switch is right there if they want the topic out entirely.
- `floorPercent` is a second derived quantity to keep in step with the window. It is defined
  next to `ceilingPercent`, in terms of it, so they cannot drift apart.
