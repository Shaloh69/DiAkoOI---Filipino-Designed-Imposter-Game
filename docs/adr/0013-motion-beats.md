# ADR 0013 — Animations are timed in beats, and a static check enforces it

**Status:** Accepted · **Date:** 2026-08-23

## Context

`03-VIBE-SYSTEM.md` §3 says motion profiles must be "real spring parameters, not
vibes-in-prose" — a bouncy pack and a precise pack have to produce visibly different
behaviour or the system is decoration. `CLAUDE.md` extends that to a hard rule: no hardcoded
design values, durations included.

Phase 3 satisfied this for the spring: `VibeTheme.spring` and `VibeTheme.baseDuration` come
from the pack. Phase 5 added roughly a dozen animations, and a single `baseDuration` is not
enough to time a shutter flash, a Polaroid developing, and a resolution landing. The obvious
next step — each animation picking a duration that "feels right" — would have quietly
reintroduced exactly what the rule forbids, one widget at a time, and nothing would have
caught it.

## Decision

**One named beat per kind of moment, every beat a multiple of the pack's `baseMs`, and a
static check that fails the build on a literal.**

`VibeBeats` defines nine: `shutter`, `develop`, `pin`, `snapIn`, `handoff`, `tally`,
`weight`, `micro`, `stagger`. Each is a *ratio* to the pack's tempo rather than a duration —
the shutter is always a fraction of a beat and the develop always several, whatever tempo the
pack sets. Sayaw at 160ms and Tahimik at 400ms therefore produce genuinely different-feeling
apps from identical widget code.

Two curves come with them. `arrive` overshoots only where the pack does; `depart` never
overshoots, because an element on its way out that bounces reads as an error rather than as
character.

**Reduced motion collapses every beat to one short fade** and zeroes the stagger. A stagger
is motion drawing the eye across the screen, which is precisely what the setting asks us not
to do. The palette is untouched — theme and motion are independent (§6).

**The rule is enforced statically.** `test/ui/motion_test.dart` scans `lib/` for numeric
literals inside a `Duration(...)` and fails on any outside a five-file exemption list, each
entry carrying a reason. A widget test only catches animations it happens to drive, and a
hardcoded 300ms in a screen nobody pumped would sail past it.

The exemptions are the theme itself, the §6 clue timer (a clock ticks in real seconds; a slow
pack must not make a timer slower), and the profiling harness's drive rate (a measurement
parameter that must *not* vary with the pack being measured, or the measurement moves with
it). The list is asserted against the filesystem, because an exemption for a deleted file is
a hole nobody is watching.

## Consequences

**Good.**

- Adding a pack changes the feel of every animation in the game with no code change, which
  is the claim `03-VIBE-SYSTEM.md` §2 makes for the whole pack system.
- The check found a real one immediately: the profiling harness's timer, which turned out to
  be a legitimate exemption but had to be argued for rather than assumed.
- Two latent bugs surfaced only because timings came from the pack and could therefore
  overshoot. A bordered `AnimatedContainer` insets its child, which shrank a vote tile enough
  to overflow its own column; and an overshooting curve returns values past 1, which
  `Opacity` asserts on. Both are invisible on a pack whose profile does not overshoot.

**Costs.**

- A new kind of moment needs a new beat rather than a number, which is friction by design. If
  the nine stop covering the space, the answer is a tenth beat, not a literal.
- Beat *ratios* are still design values chosen by hand. They live in one file, are ordered by
  a test (`shutter < micro < tally < snapIn < handoff < weight < develop` on every pack), and
  are the one place the choice is made — but they are a choice, not a derivation.

## Alternatives rejected

**`flutter_animate` for transitions**, as `08-PROMPTS.md` §6 suggests. Every duration would
still have to be passed in explicitly to satisfy the rule, so it buys syntax rather than
capability, and the brief separately requires the handoff to use framework primitives because
they are interruptible by construction. Not worth a dependency for the rest.

**A fixed duration scale with a per-pack multiplier applied at the call site.** The same
thing with more places to forget the multiplier, and nothing to catch it.
