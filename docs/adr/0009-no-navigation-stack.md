# ADR 0009 — The game is one screen following the state machine, not a navigation stack

**Status:** Accepted · **Date:** 2026-08-23

## Context

Phase 0 adopted the Flutter Casual Games Toolkit basic template, which ships `go_router` and
a route tree: main menu → level selection → play session → win screen. That shape assumes a
single-player game where every screen is a place you can return to.

DiAkoOi is not that. `01-DESIGN.md` §3 specifies a twelve-phase state machine on **one
device passed between people**, and several of those phases are one-way by design:

- `WORD_DISTRIBUTION` shows one player their word and then must not show it again
- `RESOLUTION` reveals roles the grid deliberately concealed a moment earlier
- `LIFE_CHECK` applies life changes that have already been recorded

A back stack over those phases is not a navigation convenience. It is a way to re-open a
screen the table has moved past — the exact leak `01-DESIGN.md` §5 designs hold-to-reveal to
prevent. A player who backs out of the pass interstitial sees the previous player's card.

## Decision

**Delete the router. Render the current `GamePhase` and nothing else.**

`lib/ui/screens/game_shell.dart` is a single widget that switches on `session.phase`. The
system back gesture is swallowed by a `PopScope` with `canPop: false`. Ending a game is a
deliberate choice offered on the screens that own it — the round-end recap (§8 host call)
and the replay prompt (§10) — never an implicit consequence of a gesture.

Two phases render nothing of their own and that is correct:

- `ROUND_END_CHECK` is entered and left inside one `endRound()` call, so it never reaches a
  frame. A screen there would be a beat with nothing on it.
- `ROUND_START` in round 1 shows the distribution pass rather than a deal beat, because §3
  folds round 1's word distribution into onboarding — the phone is already going round.

The template's demo screens, its `Palette`, and `PlayerProgress` went with the router. The
palette in particular had to go: a second colour source outside the Vibe Pack theme is
precisely the hardcoded-design-value failure `CLAUDE.md` bans, and leaving it as dead code
invites its reuse.

## Consequences

**Good.**

- The §3 diagram is the navigation model, so "every transition reachable, no dead ends" (A4)
  is a property of one `switch` rather than of a route graph. `GameController` records the
  edges it walks and two tests hold that trail against `GameMachine.transitions` — one
  driving the controller, one driving the widgets.
- There is no route that can be reached with stale state, because there are no routes.
- Deep links are impossible, which is the correct behaviour for a game whose entire content
  is secret from at least one person in the room.

**Costs.**

- No transition animations between phases for free; Phase 5 adds them explicitly.
- A future settings screen needs a deliberate home. Mute is the only setting that matters
  mid-game, so it lives in the scaffold header on every screen instead — a party game gets
  played in a room that already has music on, and nobody hunts for a settings screen
  mid-pass.
- Anything genuinely modal (a licence sheet behind the watermark, say) has to be a dialog or
  an overlay rather than a route.

## Alternatives rejected

**Keep `go_router` and guard each route with a redirect.** Every guard would have to encode
the same phase rules the machine already holds, in a second place, and a missed guard fails
open — the screen renders with the wrong state rather than refusing.

**Keep the stack but clear it on every phase change.** That is a state machine with extra
steps, and it still leaves `Navigator.pop` reachable from any framework widget that decides
to call it.
