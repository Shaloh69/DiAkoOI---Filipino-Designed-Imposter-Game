# Proposal 0002 — The other §2 parameters with a bound the UI does not know about

**Status:** Proposed, awaiting a decision · **Date:** 2026-08-23 · **Raised by:** Phase 5 step 0c

## Why this exists

Proposal 0001 found that a §2 range can be stated honestly and still be undeliverable,
because a *second* parameter constrains it. The topic slider says 0–100; the no-repeat
window caps it near 66. ADR 0011 then found the same range had a **floor** as well, because
weights must total 100 and the other topics are capped too.

The instruction for this audit: the same single-bound assumption may appear elsewhere in
§2. It does. This is what a sweep of every parameter found, worst first. **Nothing here is
patched** — §2 belongs to `01-DESIGN.md`.

One finding was not a bound problem at all but a shipped crash, and was fixed rather than
proposed; it is recorded at the end because it is the same *shape* of mistake.

---

## Finding 1 — Rounds has a hard ceiling set by the word bank, and exceeding it crashes

**Severity: high. This is the only finding that produces a crash rather than a wrong feel.**

§2 lists Rounds as "Host-defined" with no upper bound. §13b forbids a word repeating inside
a session, and `WordSelector.draw` enforces that by throwing:

```
StateError: no unused words left for topic "pagkain" (§13b no-repeat window)
```

Throwing is correct — a repeated word inside one session is a §13b violation and a table
notices immediately. But it fires at `ROUND_START`, mid-game, with people around a table.
The host setup screen currently offers 3–15 rounds and knows nothing about how many words
exist.

The ceiling is not simply "total words ≥ rounds", because the draw is weighted. A topic
weighted 60% is drawn about 60% of the time, so a topic with few words exhausts first. The
nominal bound is:

```
maxRounds ≈ min over enabled topics of ( wordsInTopic / weightFraction )
```

With the placeholder bank — five topics, four words each — an even mix supports about 20
rounds, but Gutom (Pagkain 60%) supports about 6. The host can currently set 15 and hit the
throw around round 7.

**And that bound is an expectation, not a guarantee.** The draw is random, so a run of bad
luck exhausts a topic earlier than the arithmetic says. A safe ceiling needs headroom, or
the draw needs to stop being able to fail.

### Options

**A. Clamp the Rounds control to the derived ceiling.** Consistent with proposal 0001, and
the same wordless communication. But the ceiling moves as the host edits the topic mix,
which is a slider on the same screen — a Rounds control that silently drops from 15 to 6
while you drag a topic weight is confusing in a way the topic slider is not.

**B. Degrade the draw instead of throwing.** When the chosen topic is exhausted, redraw
among the eligible topics that still have words, and only throw when *every* topic is
exhausted. The game keeps going, the mix drifts from what the host set in exactly the
situation where it cannot be honoured, and the failure mode moves from a crash to a
soft loss of fidelity. **Recommended.**

**C. Both.** B as the safety net, A's number shown as advice rather than a clamp — "about 6
rounds of this mix" next to the Rounds control. The host keeps control, the app cannot
crash, and the constraint is legible before the game rather than during it.

**Recommendation: C.** B alone hides a real limit from the host; A alone is a control that
jumps around while an adjacent control is being dragged. Together, the clamp becomes advice
and the crash becomes impossible.

This one is worth deciding before Phase 6, because Interference adds no words and the
authored bank will make the numbers larger without changing the shape of the failure.

---

## Finding 2 — Roundabouts 1–3 is capped to 1 above 13 players, and §2a says it should be overridable

§2 states Roundabouts as 1–3. §2a says that at 13+ the app "automatically caps roundabouts
at 1 **(overridable with a time warning)**".

`RoomSettings.effectiveRoundabouts` implements the cap and **not** the override:

```dart
int get effectiveRoundabouts => largeGroupMode ? 1 : roundaboutsPerRound.clamp(...);
```

So a host at 14 players who sets 3 gets 1, silently, forever. The setup screen shows a note
saying so — which is the "explain past it" behaviour proposal 0001 rejected for topics.

This is a **spec/implementation divergence**, not just a bound question: the design grants an
override that the code does not implement. Two coherent resolutions, and they point opposite
ways:

**A. Implement the override.** Add `overrideLargeGroupRoundabouts` to `RoomSettings`, default
false. Honours §2a as written. The time warning already has a natural home on the setup
screen.

**B. Drop the override from §2a and clamp the control.** The cap exists because 20 players ×
3 laps is 60 handoffs, and §2a's own arithmetic argues nobody should want it. Clamping the
stepper at 13+ matches proposal 0001's accepted reasoning exactly.

**Recommendation: A**, narrowly — because §2a already made this decision and an
implementation quietly overruling a design document is worse than either behaviour. If the
override is unwanted, §2a should lose it explicitly rather than by omission in code.

---

## Finding 3 — Imposter count 1–4 has a lower bound on crew that nothing enforces

§2 states Imposters as 1–4 for 3–20 players. `RoomSettings.validated` enforces only that at
least one crew member remains:

```dart
if (resolvedImposters >= playerCount) throw ...
```

So a 4-player table can be set to 3 imposters and 1 crew. That is arithmetically legal and
the engine resolves it, but every imposter holds the **same clue** and every crew member the
same word, so with one crew member the round has no information to hide: the lone crew
member is the only person who can say anything specific, and the imposters win by default.

This is weaker than findings 1 and 2 — it is a **balance** cliff, not an impossibility, and
the design may well consider a host who sets it to have chosen it. But it is the same shape:
a range stated as 1–4 that is only usable as 1–4 at some table sizes.

If a floor is wanted, the natural one is *crew must outnumber imposters*:

```
maxImposters(playerCount) = min(4, (playerCount - 1) ~/ 2)
```

which gives 1 at 3–4 players, 2 at 5–6, 3 at 7–8, 4 at 9+. The default scaling in §2 is
already well inside that.

**Recommendation:** decide whether it is a bound or a choice. If a bound, derive it as above
so the stepper stops rather than the game being unplayable. If a choice, say so in §2 so
nobody adds a clamp later thinking it was an oversight.

---

## Finding 4 — Clue difficulty saturates at Tight, so Large Group Mode does nothing there

§14 tightens the clue one step in Large Group Mode. `ClueTier.oneTighter` maps
`tight → tight`. So a host at 13+ who has already chosen Tight gets exactly Tight, and the
mode's clue adjustment is a no-op for them.

This is correct behaviour — there is no tier below Tight, and inventing one is not on the
table. It is listed only because it is the same *category* of thing: a modifier whose stated
effect does not apply at one end of a range. **No change proposed.** Recorded so a future
reader does not file it as a bug.

---

## Parameters checked and found clean

| Parameter | Coupled to | Verdict |
|---|---|---|
| Player count 3–20 | — | Independent. Large Group Mode is derived from it, not a constraint on it |
| Lives per player 1–5 | §7b damage cap | Clean. The cap clamps a round's loss; it never needs more lives than exist |
| Early-end threshold 1–3 | Player count | Clean, and only because max N (3) ≤ min players (3). If either moved this would become reachable-only-sometimes |
| Clue difficulty | Large Group Mode | Saturates — finding 4 |
| Vibe Pack random/pinned | §4 no-repeat | Clean. A single enabled pack repeats rather than failing, which the loader handles explicitly |
| Interference master toggle | — | Not yet implemented (Phase 6); no bounds to check |
| Host plays? | §2b | Clean. A social constraint, not a numeric one |

---

## The same mistake, found shipped and fixed rather than proposed

Not a §2 bound, but the identical failure of reasoning, so it belongs in the same record.

Phase 4 filtered the topic mixer to topics the word bank can actually fill — correct — but
`TopicMix.fromPreset` copied a preset's absolute percentages across verbatim. Against the
shipped placeholder bank (five topics), Barkada Classic totalled **44**, failed §13b's
must-total-100 rule, and **disabled the Start button. No game could be started at all.**

Phase 4's tests passed because they supplied a synthetic bank holding all twelve topics. A
fixture more complete than reality proves nothing about reality.

Fixed in `ff3079b`: a preset is a shape, not a set of absolute numbers, so it is renormalised
over the topics that exist. Tests now read the real asset off disk, including a widget test
that asserts Start is enabled on boot.

**The lesson generalises to findings 1–3.** Each is a case where one parameter's stated range
is really a function of another, and in each the app currently believes the stated range.
