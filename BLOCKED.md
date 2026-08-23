# BLOCKED — human gates and handoff

Audit items that cannot be satisfied by code, and the state of the run.

**A phase with an outstanding human gate is never "done".** Where later work does not
depend on the gate, building continues past it and the dependency is noted; where it does,
the run stops.

---

## Handoff — start a fresh session here

**Last completed:** Phase 4 (core loop UI — A4 AUDIT-INCOMPLETE by design).
**Next:** Phase 5 (animation pass), branched from `main` once the Phase 4 PR merges.

Phase 3 stays A3 AUDIT-INCOMPLETE: licensed audio is a human gate and Phase 4 did not
depend on it.

**Stack depth is zero.** PRs #1–#4 are all merged into `main` with merge commits, their
branches deleted, and no PR is open. Every phase branch from here branches **from `main`**
and merges back before the next starts. Keep it that way.

> **Merging a stack: do not pass `--delete-branch`.** Doing so on #1 deleted
> `phase/00-foundation` before GitHub retargeted #2, which auto-**closed** #2 — and GitHub
> then refuses to reopen it (base branch gone) *and* refuses to retarget it (PR is closed).
> Recovering meant recreating the deleted branch at its old SHA to break the deadlock.
> Merge, retarget the child to `main`, wait for its CI, merge, and delete branches at the
> very end.

### What a fresh session needs to know

`CLAUDE.md` reloads automatically. The numbered docs are there to be re-read on demand
rather than held in context — read `05-IMPLEMENTATION-PLAN.md` for the phase and
`08-PROMPTS.md` for its brief, then the specific doc that phase names.

Decisions made during the run that are not obvious from the code:

- **ADR 0004** — goldens are byte-locked to Linux. A local green on Windows means
  *skipped*, and the run prints a `GOLDENS NOT VERIFIED` banner saying so. CI is the
  authority. Regenerate with
  `docker compose -f docker-compose.goldens.yml run --rm goldens`.
- **ADR 0005** — the selfie guarantee is scoped to the *application* layer. "The app never
  writes your photo to storage" is provable; "your photo never touches disk" is not, and
  must not appear anywhere.
- **ADR 0006** — the API hostname rotates on every `cloudflared` restart, so **no hardcoded
  API base URL, anywhere, ever**. Phases 1–6 must not assume a fixed endpoint.
- **ADR 0007** — the topic draw weights by deficit, not raw weight, to satisfy both §13b
  rules at once. Any topic weighted above ~66% is arithmetically unreachable under the
  no-repeat window.
- **ADR 0008** — the reveal technique is a config value defaulting to a pre-rendered
  cross-fade. The spike could **not** rank the techniques by cost off-device and produced
  no frame-time figure; six measurements still need the handset, listed in the ADR.
- **ADR 0009** — there is **no router**. The game is one widget switching on `GamePhase`,
  and the back gesture is swallowed. A back stack over §3 is a way to re-open a screen
  showing a word the table has already moved past.
- **ADR 0010** — the selfie comes off `startImageStream`, converted and downscaled in Dart.
  `image_picker` and `takePicture()` both write a temp file **silently**, so a static check
  in `test/privacy/` fails the build if either name reappears in `lib/`.
- **ADR 0011** — the topic mixer derives a **floor** as well as a ceiling. Weights must total
  100, so dropping one topic pushes mass onto the others and each of those is capped too.
  Rebalancing allocates points one at a time with per-topic caps; proportion-then-round can
  both miss 100 and push a topic over the ceiling.
- **The controller records the §3 edges it walks** (`GameController.transitionTrail`). One
  call can cross two edges — the round-end check enters and leaves in one step — so sampling
  the phase after each method silently misses transitions. Two tests hold that trail against
  `GameMachine.transitions`. Keep them honest rather than relaxing them.
- **Alchemist CI mode flattens opacity compositing.** Goldening the reveal at three
  progress values produced three byte-identical baselines. Blur alone *does* golden
  correctly — it is the opacity cross-fade that vanishes. Anything animated by opacity
  needs a widget-tree assertion, not a golden.
- Two version pins are cross-referenced and must change together: Flutter
  (`docker/goldens.Dockerfile` ↔ `ci.yml`) and Playwright (`e2e/package.json` ↔ the CI
  container image). Both drifted once and broke CI.

---

## Outstanding human gates

### Currently blocking nothing, but blocking later phases

| # | Needed | From | Blocks |
|---|---|---|---|
| 1 | **Trademark search on "DiAkoOi"** — protocol ready in `docs/10-TRADEMARK-SEARCH.md`, ~40 minutes | Human | **Phase 8** |
| 2 | **Telemetry at launch, yes or no.** Any collection needs a privacy policy URL and a Play Data Safety declaration; shipping with zero telemetry is defensible and simpler | Product owner | **Phase 7** |

**Closed 2026-08-23 — frame target decided.** 120Hz / 8.3ms.
`app/lib/theme/frame_budget.dart` carries it as a single config value and the provisional
flag is gone. The measurements ADR 0008 lists still need the handset; they now check work
against a fixed budget instead of deciding what the budget is.

**Closed 2026-08-23 — device confirmed.** Vivo V60 Lite **5G**, Dimensity 7360-Turbo
octa-core @2.5GHz, 8GB physical + 8GB Extended RAM. `docs/06-TESTING-STRATEGY.md` §8 already
carried this; only this file was stale. Profiling runs with Extended RAM **enabled**, which
is the shipping default (§8d).

### Awaiting a decision from you

Nothing open.

**Closed 2026-08-23 — proposal 0001 accepted, clamp option.**
[0001 — topic-weight ceiling](docs/proposals/0001-topic-weight-ceiling.md) is marked
ACCEPTED, `01-DESIGN.md` §13b carries the approved paragraph and §19 records the approval,
Sports Night is corrected to Basketball 60 / Buhay Pinoy 25 / Brands 15, and all five presets
are checked against the **derived** ceiling by test rather than a remembered number. ADR 0011
records the floor that came with it.

### Known gates for phases not yet started

| Phase | Gate |
|---|---|
| 2 | 2,160 clues authored by three people; `content/STYLE.md` ratified at v1; cross-review; cultural review by Filipinos who did not author the content |
| 4 | Playtest with 5+ real humans |
| 5 | Profiling on physical V60 Lite hardware, with Extended RAM **enabled** (the shipping default) |
| 6 | Playtest: is full Interference legible or noise |
| 7 | External port scan and restore drill from outside the network |
| 10 | Device testing, trademark, store submission |

---

## Per-phase audit status

### Phase 0 — Foundation · **A0 GREEN**

All five A0 items pass; CI green on all five jobs (run `32587846049`).

### Phase 1 — Engine · **A1 GREEN**

No human gate. Fully closeable by machine, and closed.

- `flutter analyze` clean; `lib/engine/` free of `package:flutter`, enforced by a test
- Engine line coverage **95.92%** (A1 requires ≥ 90%), now gated in CI
- All four §7a Mayor cases, the weight-is-tally-only rule, the §7b clamp with Sudden Death
  as sole bypass, and every §9b/§9c event alone and stacked
- Same seed → byte-identical transcripts
- 147 tests

### Phase 2 — Content · **AUDIT-INCOMPLETE**

The pipeline is built and CI-green (all five jobs). **The bank is empty**, and only humans
can fill it.

| A2 item | Status |
|---|---|
| Validator rejects every failure class in §5 (test each) | **PASS** — 23 tests, one per class |
| `/content/STYLE.md` at **v1**, revision log signed by all three authors | **BLOCKED** — still v0 DRAFT |
| All Wave 1 topics at ≥ 60 words, zero validation errors | **BLOCKED** — 0 authored words; 150 unreviewed candidates exist in `content/drafts/` |
| Tier separation: no word where tight and standard read near-identically | **BLOCKED** — checkable only against authored content |
| Cross-author consistency: sample 10 words per author | **BLOCKED** — needs three authors |
| Every topic cross-reviewed by an author who didn't write it (§6c) | **BLOCKED** |
| Playtest calibration: tight survives ≥3 crew clues, loose fails by lap 2 | **BLOCKED** — needs a table |
| Cultural review complete; flagged items resolved or cut (§7) | **BLOCKED** |

**What a human needs to do next, in order:**

1. **Run the calibration round** (`02-CONTENT-PH.md` §6a) — all three authors write the same
   10 words, compare, then ratify `content/STYLE.md` as **v1** with a signed revision log.
   Do this *before* authoring at scale and before touching the drafts.
2. **Assign topic ownership**, one owner per topic (§6b).
3. **Review `content/drafts/`** — 150 candidates across the five wave-1 topics. Treat every
   row as a proposal; deleting is a fine outcome. Approved rows move into
   `content/<topic>.csv`, which is the only directory that gets bundled.
4. **Author wave 1 to 60+ words per topic**, then cross-review (§6c) and cultural review (§7).

**Shipping gate:** `app/assets/wordbank/wordbank.json` currently carries
`"isPlaceholder": true`. It must be regenerated from authored content before release —
a test asserts that a placeholder bundle is labelled, but nothing yet stops one shipping.
Worth a release check in Phase 10.

### Phase 3 — Vibe Packs · **AUDIT-INCOMPLETE**

The theming system is complete and works without real tracks. What is blocked is licensed
audio and anything needing the handset.

| A3 item | Status |
|---|---|
| `flutter test --tags golden` green in CI on a clean checkout | **PASS** — 11 golden groups; CI run `32627034581` was 11 including the Phase 0 `my_button` harness, which Phase 4 replaced with `VibeButton`. Still 11 |
| Golden matrix: every primitive × every Vibe Pack, in CI | **PASS** — 10 primitives × 6 packs, built from `assets/vibes/` not a Dart list |
| Every pack passes 4.5:1 body / 3:1 large text contrast | **PASS** — all six, checked per pack |
| Crew vs imposter distinguishable without colour | **PASS** — shape tokens differ per pack |
| Watermark legible on every pack, never obstructing content | **PASS** — `textMuted` clears 3:1 on every pack's bg |
| Adding a 7th pack requires zero Dart changes (prove it) | **PASS** — loaded at runtime from a directory that did not exist at author time |
| Reduced motion collapses profiles; palette still applies | **PASS** |
| Layout holds at 320dp and 200% text scale | **PASS** — all six packs |
| **Every shipped track has a valid `licence.json`** | **BLOCKED** — all six are `isPlaceholder: true` with no track |

**What a human needs to do:**

1. **Source six licensed tracks** per `04-MUSIC-SOURCING.md`, streamer-safe and Content-ID
   free (`03-VIBE-SYSTEM.md` §1). Commission from a Filipino artist is worth pricing.
2. **Commit a real `licence.json` per pack** — source, type, URL, acquired date, attribution
   — and set `isPlaceholder` to false. A test then requires a track file to be present.
3. **Keep the licence screenshot on file** for A10.

> **The six packs currently ship no audio at all.** `trackFile` is null and a test enforces
> that a placeholder pack has no track. That is deliberate: no `ffmpeg` or `oggenc` was
> available, and a hand-made fake silent `.ogg` in a licence-audited folder would be
> something pretending to be a licensed asset — and would also hide a real pack whose
> filename was mistyped.

**Still needing the handset** (see ADR 0008): frame times for each reveal technique,
whether the cross-fade holds 8.3ms, whether the downscaled blur is visually acceptable, and
thermal behaviour across ten rounds. The **120Hz vs 60Hz decision is still open** and this
is the evidence it was waiting for — which means it is still waiting.

### Phase 4 — Core loop UI · **AUDIT-INCOMPLETE**

The base game is playable end to end. What is blocked is everything needing real people and
a real handset, which is most of what A4 actually asks.

| A4 item | Status |
|---|---|
| **Manual playtest, 5+ real humans** | **BLOCKED** — not simulatable, and both §12 verdicts below depend on it |
| Airplane mode: full game start to finish | **PASS by construction, unverified on device** — no network call exists in the app; the word bank and every pack load from the asset bundle. Nothing proves it on hardware yet |
| `no_disk_write_test` passes | **PASS** — 8 tests. Its static half fails the build if `image_picker` or `takePicture(` appears in `lib/`, because a runtime test only catches what it happens to exercise |
| Manually verify the OS photo library is untouched | **BLOCKED** — needs the handset |
| Kill and relaunch mid-game → no selfie recoverable from disk | **BLOCKED** — needs the handset |
| Every FSM transition reachable from the UI; no dead ends | **PASS, with two named exceptions** — the controller records every edge it walks and two tests hold that trail against §3, one driving the controller and one driving the widgets. The two unreached edges both need a round with **zero roundabouts**, which only the §9c No Roundabouts modifier produces. Interference is Phase 5; wiring it will fail these tests and require a deliberate update |
| Back-button and interruption handled everywhere | **PARTIAL** — the back gesture is swallowed app-wide by `PopScope` (ADR 0009), which is the correct behaviour for §3. Call and notification interruption needs the handset |
| 20-player setup completes; Large Group Mode engages at 13 | **PASS** — a 20-player game is seated, dealt, discussed and voted through the widgets; Large Group Mode is asserted to engage at 13 and not at 12 |
| Topic weights visibly produce the intended mix over 10 rounds | **PASS at the engine, unverified at a table** — 6000 draws against a mix set to the ceiling land within 2% of it. Whether a table *notices* is a playtest question |
| **§12.3 verdict on accuser-pays** — did personal cost flatten discussion into safe consensus picks? | **BLOCKED** — playtest |
| **§12.4 verdict on two-tap voting** — fast enough at 10+? | **BLOCKED** — playtest |

**The exit condition is now two gates** (`05-IMPLEMENTATION-PLAN.md`, corrected 2026-08-23).
It previously read "six people play a full game on one device, airplane mode, on real
content" as a single clause, which mixed *the loop works* with *the words are good* — and
content authoring is a parallel human track that has barely begun. A finished phase was
being held open for a reason no code change could close.

- **A4 machine gate — MET.** Six seats play a full game on one device, offline, on the
  labelled placeholder bank.
- **A4 human gate — OPEN.** The same game played by real people on authored wave-1 content.
  Unblocks when Phase 2 authoring lands.

**Phases 5 and 6 do not depend on the bank and proceed against the placeholder.**

**What a human needs to do next, in order:**

1. **Build and install on the V60 Lite.** Confirm the camera path produces a usable selfie —
   rotation and mirroring are computed from `sensorOrientation` and have never run against
   real hardware (ADR 0010).
2. **Airplane mode, full game.** Then kill the app mid-round, relaunch, and check the photo
   library and app storage for anything recoverable.
3. **Playtest with 5+ people.** Record total time, per-round time, points of confusion, and
   any rule asked about twice. The two §12 verdicts come out of this and nothing else.

**Carried into Phase 5.** The §9f constraint banner slot is built and wired through the pass
interstitial, but nothing fills it. `RoundModifiers` is passed empty at every resolution,
which is what the defaults already describe: `InterferenceSettings.enabled` is false until a
host turns it on, and the host setup screen deliberately does not offer that yet. A toggle
that does nothing invites a host to turn it on and conclude the app is broken.

**One count to watch.** Golden baselines went 11 → 10 → 11 this phase: `my_button.png` was
removed with the Phase 0 harness it belonged to, and `matrix_vibe_button.png` was added.
A Linux run reporting fewer than **11** golden groups means they stopped executing.
