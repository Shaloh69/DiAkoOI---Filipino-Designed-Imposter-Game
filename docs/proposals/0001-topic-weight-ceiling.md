# Proposal 0001 — the topic-weight ceiling needs to be visible to the host

**Status:** **ACCEPTED — Option A (clamp), 2026-08-23.** **Raised:** 2026-08-23, from Phase 1.

> **Decision.** The slider clamps at the ceiling. Option B was rejected on the grounds that a
> UI accepting a setting it cannot honour is worse than one that stops, and a host mid-lobby
> with people waiting is not reading explanatory text — a slider that stops communicates the
> constraint wordlessly.
>
> Two conditions attached, both implemented in Phase 4:
> 1. the ceiling is **derived** from the enabled topic count and the no-repeat window, never
>    hardcoded — it changes when a host disables topics;
> 2. **Sports Night** is corrected to Basketball 60 / Buhay Pinoy 25 / Brands 15, and all
>    five presets are verified against the derived ceiling rather than assumed.
>
> Applied to `01-DESIGN.md` §13b; see its revision history.
**Touches:** `01-DESIGN.md` §13b (host-facing rule) and Phase 4's host setup UI.

> `01-DESIGN.md` is propose-don't-patch. Nothing here has been applied.

---

## The problem

`01-DESIGN.md` §13b puts two rules on the topic draw:

1. the host sets a weighted mix, and the app rolls against it; and
2. **no-repeat window** — the same topic cannot be drawn more than twice in a row,
   *regardless of weight*.

The second rule imposes an arithmetic ceiling the first cannot exceed. After two
consecutive draws a topic **must** yield, so **no topic can exceed two draws in every
three — about 66.7%.**

This is not an implementation limit and no engine change can lift it. Rule 2 is explicit
that it applies regardless of weight, so where the two rules conflict, rule 2 wins.

The engine already behaves correctly (ADR 0007: the draw compensates by deficit, so
suppressed mass is repaid and any weight *at or below* the ceiling converges within 2%).

**The gap is host-facing.** Nothing stops a host setting K-Pop to 80%. They will then
observe roughly 67% and reasonably conclude the app is broken or is ignoring them. The
failure is silent, it looks like a bug, and it happens at setup — before anyone has played
a round and built any trust in the app.

### How close the shipped presets sit

| Preset | Highest weight | Headroom to ~66.7% |
|---|---|---|
| **Stan Mode** — K-Pop 60 / OPM 20 / Internet 20 | **60%** | **6.7 points** |
| Sports Night — Basketball 70 / Buhay Pinoy 30 | **70%** | **already over** |
| Gutom — Pagkain 60 / Brands 20 / Buhay Pinoy 20 | 60% | 6.7 points |
| Tita Mode — Teleserye 40 / Aktor 30 / OPM 30 | 40% | comfortable |
| Barkada Classic — even spread | low | comfortable |

**Sports Night is already above the ceiling** at Basketball 70%, and would deliver ~67%.
Stan Mode and Gutom sit 6.7 points under it — close enough that a host nudging a slider
"just a bit higher" crosses it immediately.

That makes this not a hypothetical edge case: one shipped preset is already affected.

---

## Option A — clamp the slider at the ceiling

Cap any single topic at 66% in the host setup UI. The slider simply will not go higher.

**For**
- The host can never configure something the app cannot honour. No surprise, nothing to
  explain after the fact.
- Simplest possible UI: no warning state, no extra copy, no error styling.
- Guarantees the observed mix always matches the configured mix, which keeps the setup
  screen honest.

**Against**
- A cap with no explanation is its own confusion — a slider that stops moving reads as a
  bug unless it says why, so this needs a line of copy regardless.
- Requires editing the **Sports Night** preset down from 70%, changing a shipped default.
- Removes a legitimate expression of intent. A host who wants "almost entirely K-Pop"
  cannot say so, even though the app would in fact give them the most K-Pop possible.

---

## Option B — allow higher, show the effective rate

Let the slider go to 100%, and when a topic exceeds the ceiling show inline copy stating
what will actually happen.

> K-Pop is set to 80%, but no topic can come up more than twice in a row —
> **you'll see it about 67% of the time.**

**For**
- Honest and specific. It names the mechanic, gives the real number, and does not treat
  the host as unable to handle it.
- Preserves intent: 80% still means "as much K-Pop as the rules allow", and the difference
  between 80% and 100% remains meaningful as a signal even when both land at ~67%.
- No shipped preset changes. **Sports Night stays at 70%** and simply displays its
  effective rate.
- The explanation lands *at setup*, before the first round, rather than being discovered
  as an apparent bug three rounds in.

**Against**
- More UI: a conditional warning state, and copy that has to be written and translated.
- Adds a concept — "configured versus effective" — to a screen that is already the
  fiddliest in the app (§12 open item 5 already flags topic-weight UX as needing rework).
- A host who ignores the copy still ends up surprised; it mitigates rather than prevents.

---

## Recommendation

**Option B**, with one borrowing from A: **show the effective rate for any topic above the
ceiling, and do not change the presets.**

The reasoning is that the ceiling is a *rule of the game*, not a technical limitation, and
§13b already treats the no-repeat window as a deliberate feel decision rather than a
constraint to hide — the window exists precisely because a table reads streaks as broken.
Explaining a rule is consistent with that; silently clamping it away is not.

It also avoids editing Sports Night, which would otherwise mean changing a shipped default
because of an implementation detail the host never sees.

The cost is real but bounded: one conditional line of copy on a screen that is being
reworked anyway (§12 open item 5).

**If the setup screen is already too dense when Phase 4 builds it, Option A is a
defensible fallback** — but then Sports Night must be retuned to 66/34 in the same change,
and the cap needs a line of copy explaining itself, so the saving is smaller than it looks.

---

## Either way

Whichever is chosen, two things should follow:

1. **`01-DESIGN.md` §13b should state the ceiling explicitly.** It is currently derivable
   from the two rules but stated nowhere, which is how it reached Phase 1 undiscovered.
   Suggested wording:

   > **Ceiling.** Because a topic cannot be drawn more than twice in a row, no topic can
   > exceed roughly 66% of draws however it is weighted. Weights above that are honoured
   > up to the ceiling.

2. **A note in §12 open item 5**, which already covers topic-weight UX, so whoever reworks
   that screen sees this as part of the same problem rather than as a separate bug report.

Engine behaviour and the measurements behind the ceiling are in
`docs/adr/0007-topic-draw-deficit-weighting.md`.
