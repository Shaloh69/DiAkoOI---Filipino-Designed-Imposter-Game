# ADR 0012 — The reveal state machine is Dart, not Rive, for now

**Status:** Accepted, revisit after the device measurement · **Date:** 2026-08-23

## Context

`05-IMPLEMENTATION-PLAN.md` Phase 5 and `08-PROMPTS.md` §6 both name **Rive** for the reveal
card specifically, and the reasoning is sound: the card genuinely is a state machine
(idle → holding → revealed → closing) with a crew/imposter axis on top of a motion-profile
axis, and that is what Rive state machines are for.

Two things were true when this phase started.

**ADR 0008 put Rive third in a fallback ladder, not first.** The Phase 3 blur spike chose
`prerenderedCrossFade` as the default and said in as many words that reaching for Rive to
de-risk a cost nobody has measured inverts the order. The decisive measurement — whether the
cross-fade holds 8.3ms on a Mali-G615 MC2 — still needs the handset. The Phase 5 brief also
says to *apply whatever the spike concluded*, and those two instructions point the same way
once the ladder is read.

**A Rive state machine needs a `.riv` artefact, and none exists.** There is no artist, no
art pipeline, and no file. Committing a hand-stubbed one would be the same mistake as a fake
silent `.ogg` in a licence-audited folder: something pretending to be a real asset, which
then hides the absence of the real one and makes the gap invisible to the next person.

## Decision

**Build the state machine in Dart, driving the technique ADR 0008 selected, and shape it so
a Rive artefact can replace the renderer without touching a caller.**

`RevealMachine` is a real four-state machine, not an `AnimationController` run forwards and
backwards. That distinction earns its keep immediately: **closing is instant**, on every pack
and in every motion setting, while opening springs on the pack's own profile. A symmetric
controller cannot express that, and a card that eases shut is one the next player reads on
the way down.

What makes it Rive-shaped rather than merely a widget:

- the states are named and exhaustive
- progress is a single `0..1` value, which is what a Rive input takes
- role and reduced-motion are **inputs**, not branches in the widget tree
- nothing above it knows how the blur is produced

Swapping in Rive later means replacing what renders `progress`, not rewiring the flow.

## Consequences

**Good.**

- Phase 5 ships without a blocking dependency on art that does not exist.
- The measurement ADR 0008 asks for is still the thing that decides. If
  `prerenderedCrossFade` holds 8.3ms, Rive was never needed here and adding it would have
  been a dependency bought on a guess.
- `hasBeenRead` is a legibility **threshold**, not animation completion. A spring settles
  asymptotically and a slow pack takes visibly longer to finish, so gating on the end would
  make Tahimik demand a longer press than Sayaw for the same amount of reading. That bug is
  only visible once timings come from the pack, which is why it appeared in this phase.

**Costs.**

- The crew/imposter treatment stays subtle and geometric — shape tokens and accent, per §6b
  — rather than being the richer thing a designed artefact could carry. §6b wants it subtle
  anyway, so this costs less than it would elsewhere.
- If the device measurement says the blur must go, the Rive work lands in Phase 6 or later
  and this ADR is superseded rather than amended.

## What would change this

Exactly one thing: **the on-device measurement in ADR 0008**. If neither
`prerenderedCrossFade` nor `downscaledBlur` holds the frame budget, option 3 in
`06-TESTING-STRATEGY.md` §8b is a Rive-driven mask or dissolve, and the interface built here
is where it plugs in. Commission the artefact then, against a measured need.
