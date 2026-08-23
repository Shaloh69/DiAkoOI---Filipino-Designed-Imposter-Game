# ADR 0007 — Topic draw uses deficit weighting, not plain renormalisation

**Status:** Accepted · **Date:** 2026-08-23

## Context

`01-DESIGN.md` §13b puts two rules on the per-round topic draw:

1. The host sets a weighted mix, and the app rolls against it.
2. **No-repeat window** — the same topic cannot be drawn more than twice in a row,
   *regardless of weight*, because "a 60% weight produces visible streaks that feel broken
   even though the maths is right".

`05-IMPLEMENTATION-PLAN.md` A1 then requires both at once: the draw converges to the host's
weights **within ±2% over 10,000 rounds**, *and* the window is never violated.

The obvious implementation — exclude the streaking topic, renormalise over the rest — was
written first and **fails the audit**. Measured over 10,000 draws at a 60/20/20 mix:

```
kpop drew 49.32%, host set 60%   (10.68 points low)
```

The reason is structural, not statistical noise: every time a topic is blocked, the share it
would have taken is handed to the others permanently. It is never repaid, so a
heavily-weighted topic is systematically suppressed. Raising the tolerance would have hidden
a real defect rather than fixing one.

## Decision

Draw against each topic's running **deficit** rather than its raw weight.

```
deficit(t) = weight(t)/100 × (draws so far + 1)  −  times t has been drawn
```

Topics with a positive deficit are behind their share; the draw is weighted in proportion to
those deficits. A topic with a deficit at or below zero is already at or ahead of its share
and drops out of contention until the others catch up. When every eligible topic is
over-served — which happens on early draws — the draw falls back to the raw weights.

A blocked topic keeps accruing deficit while it waits, so it is strongly favoured the moment
it becomes eligible again. The mass suppressed by the window is repaid instead of lost.

This keeps both properties the design needs:

- **Still random.** It is a weighted draw, not a schedule; consecutive games differ.
- **Still reproducible.** `deficit` is a pure function of the host weights and the draw
  history, so a seeded game replays byte-identically (A1).

Measured after the change: every topic within 2% of its configured weight over 10,000 draws,
and 20,000 draws at a deliberately streak-prone 90/10 mix with zero window violations.

## The ceiling, stated so it is not rediscovered as a bug

The window caps any single topic at **two draws in every three — about 66.7%**. That is
arithmetic, not an implementation limit: after two consecutive draws the topic *must* yield.

So a topic weighted above ~66% **cannot** be honoured and will settle at the ceiling. The
two rules genuinely conflict there and §13b is explicit about which wins — the window applies
"regardless of weight".

Consequences:

- The A1 convergence check is meaningful only for mixes where no single topic exceeds ~66%.
  The audit's own example (60/20/20) sits just under it, which is presumably not an accident.
- `Stan Mode` (K-Pop 60 / OPM 20 / Internet 20) and every other §13b preset are inside the
  ceiling. Nothing shipped is affected.
- A host who sets 90% on one topic will see roughly 67%. **The topic-weight UI should say so**
  rather than silently under-delivering — noted for Phase 4, and related to §12 open item 5,
  which already flags that weight UX needs rethinking.

## Alternatives rejected

**Loosen the A1 tolerance to fit the naive draw.** This is the tempting one and it is wrong:
a 10-point gap is a real defect in weight handling, and widening the tolerance to accommodate
it would also blind the test to genuine regressions.

**Drop the no-repeat window when weights are high.** §13b is explicit that the window applies
regardless of weight, and the streaks it exists to prevent are exactly what a high weight
produces. This would remove the rule precisely where it earns its place.

**Deterministic round-robin scheduling.** Converges perfectly and removes all variance, but
the draw becomes predictable — the table could infer the next topic — and §13b wants a roll.
