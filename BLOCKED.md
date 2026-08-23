# BLOCKED — human gates and handoff

Audit items that cannot be satisfied by code, and the state of the run.

**A phase with an outstanding human gate is never "done".** Where later work does not
depend on the gate, building continues past it and the dependency is noted; where it does,
the run stops.

---

## Handoff — start a fresh session here

**Last completed:** Phase 6 (Interference Mode — A6 AUDIT-INCOMPLETE by design).
**Next:** Phase 7 (API & self-hosting), branched from `main` once the Phase 6 PR merges.
**Phase 7 has a hard prerequisite that is not met** — see the hosting note below.

A3 and A4 both stay AUDIT-INCOMPLETE and neither blocks Phase 6: licensed audio is a human
gate, and A4's remaining items need a handset, a table, and authored content.

**The one thing a fresh session should read first:** the profiling procedure below. It is
the largest outstanding gate in the project and it is entirely executable by a human with
the handset — everything it needs is built and committed.

**Stack depth is zero.** PRs #1–#6 are all merged into `main` with merge commits, their
branches deleted. Every phase branch from here branches **from `main`** and merges back
before the next starts. Keep it that way.

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
- **ADR 0012** — the reveal state machine is Dart, not Rive, and the file says why. ADR 0008
  put Rive third in a ladder behind a measurement that still needs the handset, and no `.riv`
  artefact exists. The interface is shaped so one drops in without touching a caller.
- **ADR 0014** — the interference roller is **two ordered phases**, because §9c reaches both
  backwards into setup (Double Imposter, No Roundabouts) and forwards into roles (Bodyguard).
  The simulator drives the production roller; it used to carry its own copy, which meant the
  A1 properties tested the copy.
- **Five widgets used the wrong ticker mixin.** Any widget that rebuilds an
  `AnimationController` in `didChangeDependencies` needs `TickerProviderStateMixin`, not the
  Single variant — the Single one asserts on a second ticker even after the first is disposed,
  and a Vibe Pack reroll on Play Again is exactly a second ticker.
- **ADR 0013** — every animation is timed in **beats**, each a multiple of the pack's
  `baseMs`. A static check in `test/ui/motion_test.dart` fails the build on a literal
  `Duration(...)` outside a five-file exemption list. Adding an exemption means editing that
  test and stating a reason.
- **Two bugs that only appear on an overshooting pack.** A bordered `AnimatedContainer`
  insets its child — use `foregroundDecoration`. And a curve like `easeOutBack` returns
  values past 1, which `Opacity` asserts on — the overshoot belongs on the transform, never
  on the alpha. Both are invisible on Lamig and fatal on Sayaw.
- **Test fixtures must not be richer than reality.** Phase 4's mixer tests supplied a
  synthetic bank holding all twelve topics; against the bank the app actually ships, every
  preset produced a mix totalling 44 and **the Start button was disabled**. Tests that touch
  bundled content now read the real asset off disk.
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

| Proposal | Question | Blocks |
|---|---|---|
| [0002 — coupled parameter bounds](docs/proposals/0002-coupled-parameter-bounds.md) | Three §2 parameters have a bound the UI does not know about. **Rounds is the urgent one**: its real ceiling is set by the word bank and the topic mix, and exceeding it *throws mid-game*. Roundabouts is capped at 13+ players but §2a says that cap should be overridable and the code does not implement it — a spec divergence. Imposter count 1–4 has no floor on crew, so a 4-player table can be set to 3 imposters and 1 crew. | Worth deciding before **Phase 6**; Interference adds no words and will not change the shape of the Rounds failure |

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

**One count to watch (superseded — now 12, see Phase 6).** Golden baselines went 11 → 10 → 11 this phase: `my_button.png` was
removed with the Phase 0 harness it belonged to, and `matrix_vibe_button.png` was added.
A Linux run reporting fewer than **11** golden groups means they stopped executing.

### Phase 5 — Animation pass · **AUDIT-INCOMPLETE**

Every animation is built, timed off the active pack, and has a reduced-motion path. **Almost
all of A5 is a measurement, and the measurement needs the handset.** The harness that takes
it is built and committed; the procedure is below.

| A5 item | Status |
|---|---|
| Frame target decided and recorded in an ADR | **PASS** — 120Hz / 8.3ms, single config value in `app/lib/theme/frame_budget.dart`, recorded in ADR 0008 and closed as a gate on 2026-08-23 |
| No animation blocks input; all interruptible | **PASS** — taps land mid-animation with no `pumpAndSettle` anywhere, which is the only way to catch a blocking beat; an interrupted hold is re-pressable |
| `MediaQuery.disableAnimations` honoured throughout | **PASS** — the flag reaches the pack theme, every beat collapses, the stagger zeroes, both curves linearise, and a full game still plays with motion off |
| Reduced-motion alternative for every animation | **PASS** — asserted per pack across all nine beats, plus the palette surviving and no pack overshooting |
| No hardcoded timings | **PASS** — static scan of `lib/`, five exemptions each with a reason, the exemption list checked against the filesystem, and the regex proved against a planted offender |
| Same trace under at least two Vibe Packs | **HARNESS READY** — the report records `packId`; the procedure runs it twice |
| Profile trace in default power mode | **BLOCKED** — handset |
| Hold-to-reveal blur holds budget | **BLOCKED** — handset. This is the measurement ADR 0008 has been waiting on since Phase 3 |
| Jank check on the 20-player grid | **BLOCKED** — handset. The harness builds the real 20-player roster with selfie-sized buffers |
| Thermal check, 10 consecutive rounds | **BLOCKED** — handset |
| Funtouch backgrounding: call, notification, background | **BLOCKED** — handset |
| Profiled on the 8GB variant | **BLOCKED** — handset (the confirmed device *is* the 8GB variant) |
| Cold start under 2s with audio preload | **BLOCKED** — handset, and partly on Phase 3: the packs ship no audio yet, so a cold start measured now would not include the preload |
| Memory flat across 10 rounds | **BLOCKED** — handset |

**Exit condition — "60fps on a real mid-range Android, not the simulator" — is a device
measurement and cannot be met by machine.** No frame time is produced anywhere in this phase.
ADR 0008 rejected derived figures explicitly, and that still holds: a number with a caveat
attached is a number people quote without the caveat.

---

## The A5 profiling procedure

Everything here is executable by one person with the handset. Follow it exactly; where it
says *record*, write the value down, because the harness cannot read it and a guess would
make an unverifiable trace look verified.

### Before you start — device setup

1. **Vivo V60 Lite 5G**, the confirmed 8GB variant (`06-TESTING-STRATEGY.md` §8).
2. **Power mode: default.** Settings → Battery → confirm neither Performance nor Battery
   Saver is on. *Players will not change it, so neither do we.* A trace taken in Performance
   mode measures a device nobody has.
3. **Extended RAM: enabled.** Settings → RAM → confirm the extension is on. This is the
   shipping default and §8d is explicit that disabling it measures a different phone.
4. **Charge above 50%, then unplug.** Some vivo builds throttle differently on charge.
5. **Close other apps.** Not for fairness — for the memory test, which is meaningless if
   something else is causing the pressure.
6. **Let the phone sit at room temperature for ten minutes** before the thermal run. §8c
   wants warm-versus-cold, and a phone that started warm has no cold baseline.

### Build and install

```bash
cd app
flutter build apk --profile
flutter install --profile
```

**It must be `--profile`.** A debug build's frame times measure the debugger. The harness
says so on screen and stamps `debug (INVALID for A5)` into the report file, but check the
command anyway — that label is a backstop, not the plan.

### Run it

1. Launch the app. You land on host setup.
2. Scroll to **"Profiling harness (A5)"** near the bottom and tap it. *(The button does not
   exist in a release build — see `profilingAvailable`.)*
3. **Note the pack name** in the header. The pack is drawn per session, so relaunching is
   how you get a different one.
4. Tap **"Run all four scenarios"**. It runs unattended for roughly four minutes:
   reveal 10s → handoff 10s → vote tally 10s → ten thermal rounds.
5. **Do not touch the screen while it runs.** A stray tap adds frames that were not the
   scenario.
6. When it finishes it writes a file and shows the path on screen.

### Do it twice, on two different packs

A5 requires the same trace under at least two Vibe Packs, and specifically a **bouncy** one
against a **precise** one — a bouncy profile must not blow a budget a precise one meets.

- Bouncy: **Sayaw** or **Tugtog**
- Precise: **Lamig** or **Tahimik**

The pack is drawn at random per session. Force-stop the app and relaunch until the header
shows one from each group, then run the full set on each. Two report files.

### Retrieve the reports

```bash
adb exec-out run-as ph.teamlanzones.diakooi ls files/
adb exec-out run-as ph.teamlanzones.diakooi cat files/diakooi-profile-TIMESTAMP.json > report.json
```

Then **fill in the three `UNRECORDED` fields** in each file — `device`, `powerMode`,
`extendedRam`. A trace that does not say what it was taken on cannot be checked later, and an
uncheckable trace is not evidence.

### The backgrounding test — run this separately, by hand

§8c calls Funtouch background management the most likely real bug on this device, and it is
the one thing the harness cannot automate.

1. Start a **normal game** (not the harness) with at least three players, and give at least
   one of them a **real selfie** rather than a skip.
2. Get to the voting grid, so there is session state worth losing.
3. In turn, checking after each:
   - press Home, wait **60 seconds**, reopen
   - pull down the notification shade, dismiss it, return
   - have someone **call the phone**, decline, return
   - open three other apps, then return
4. After each: **is the roster still there, are the selfies still showing, is the vote state
   intact?**

**A lost selfie is a bug, not a privacy win.** They exist nowhere else, and losing them
mid-game means restarting onboarding at a table.

Note also whether the first few frames after resuming stutter. §8d predicts they might: a
page fault into Extended RAM is a UFS read, and resuming may have to fault the working set
back in.

### What counts as a pass

The frame target is **120Hz / 8.3ms** (`FrameBudget.target`). Read these off the report:

| Reading | Pass | Marginal | Fail |
|---|---|---|---|
| `medianMs` per scenario | ≤ 8.3 | 8.3–10 | > 10 |
| `p99Ms` per scenario | ≤ 8.3 | ≤ 12 | > 12 |
| `framesOverBudget` ÷ `frameCount` | < 1% | 1–3% | > 3% |
| Thermal: last round median vs first | within 15% | 15–30% | > 30% |
| Memory across the 10 rounds | flat | slow creep | grows every round |

**`worstMs` is not a pass/fail number on its own.** One dropped frame in a run shows up there
and nowhere else — p99 will not catch it, by construction — so read it, but do not fail a run
on a single spike.

**The reveal scenario is the one that matters.** It is the measurement ADR 0008 has been
waiting on since Phase 3, and the reason the frame target was in question at all.

### If the reveal fails

Do not start optimising. Walk the ladder in `06-TESTING-STRATEGY.md` §8b, in order, changing
one thing at a time:

1. **Confirm which technique was measured.** The default is `prerenderedCrossFade`
   (ADR 0008). If the trace was taken on that and failed, go to 2.
2. **Try `downscaledBlur`.** One line at the `RevealSurface` call site. Then make an eye
   judgement at arm's length on the 6.77" panel: blur radius is perceptual and resolution is
   not, but that has a limit and where it sits is not a calculation.
3. **Commission a Rive artefact** (ADR 0012). The interface is already shaped for it — four
   named states, a single 0..1 progress input. This is the point at which paying for art is
   justified by a measured need rather than a guess.
4. **Cap to 60Hz.** Change `FrameBudget.target` to `FrameTarget.hz60`, doubling the budget to
   16.6ms. `06-TESTING-STRATEGY.md` §8a calls this legitimate but visibly less premium on a
   120Hz panel. Last resort, and record it as a decision rather than a default.

### What to report back

Attach both JSON files and answer these:

- Did `prerenderedCrossFade` hold 8.3ms during a sustained reveal? **This is the headline.**
- Did the 20-player grid hold it?
- Did frame times degrade across the ten thermal rounds, and by how much?
- Did the bouncy pack and the precise pack differ materially?
- Did the app survive all four backgrounding cases **with selfies intact**?
- Did resuming stutter, and for roughly how long?

### Phase 6 — Interference Mode · **AUDIT-INCOMPLETE**

Every event is built, rollable, resolvable and reachable from a debug menu. The one thing
outstanding is the question only a table can answer.

| A6 item | Status |
|---|---|
| Every event triggerable via debug menu, verified end to end | **PASS** — host setup → "Every event (A6)", debug and profile builds only. A widget test taps all 38 and asserts each renders; "Nothing" is asserted to render *nothing*, since that is the §9b outcome keeping rolls uncertain |
| Simulation: 10,000 games, all events on — no unbounded loss, no unreachable state, no crash | **PASS** — and genuinely all events this time; see the note below |
| **Spread the Blame produces a resolvable plurality** at 3, 10, 20 | **PASS, with a correction** — the cap makes a plurality *reachable*, not guaranteed. Ten voters spread two-per-tile is a legal ballot and a real five-way tie, which the Mayor breaks. Both pinned, plus the arithmetic showing why the cap is 2 and not 1 |
| **Near-Unanimous cannot be unilaterally blocked** by imposters alone | **PASS** — checked at 4, 6, 10 and 20 with the default imposter counts |
| **Mercy Round blocks every damage source** | **PASS** — vote, Life Drain, Steal a Life and a Taboo slip stacked in one round, all zero |
| Every `enforcement: 'social'` event shows a constraint banner | **PASS** — and the three secret constraints are asserted *not* to |
| Every event has `requiresColocation` set — audit is a query | **PASS** — `InterferenceRoller.eligible()` is that query |
| Interference visual language clearly distinct from the calm reveal card | **PASS** — chamfered vs rounded, pack interference accent, goldened across all six packs |
| **Playtest: is a full-chaos session legible, or noise?** | **BLOCKED** — needs a table, and it is the question the whole phase exists to answer |

**The simulation was not what it looked like.** The existing 10k run in `properties_test.dart`
lists only round-start events in `enabledEventIds`, and a non-empty list means everything
absent is *disabled* — so **no §9b event had ever fired in it**. It was right about what it
claimed and wrong about what it appeared to cover. The new run enables both catalogues
explicitly, and a second test asserts every event actually fired at least once across 4,000
games, because a pool filter that silently drops one leaves the simulation green while
covering less than it claims.

**The simulator now drives the production roller.** It had its own copy of the rolling logic,
which meant the A1 properties were asserted against the simulator's idea of §9 rather than the
app's. A simulation that reimplements what it tests proves only that the copy agrees with
itself.

**Three of my own assertions were wrong and the code was right.** All three are kept as
documentation rather than quietly corrected:

1. Spread the Blame guarantees a plurality — it does not, and cannot.
2. A tie under Spread the Blame always resolves — not when the Mayor is one of the accused
   (§7a), which that modifier makes far more likely than normal voting does.
3. Double Imposter rerolls at 3 players with 1 imposter — it fires, producing two imposters
   against one crew member. That is proposal 0002 finding 3, now pinned with a note to update
   the proposal rather than delete the test.

**One real bug, and it would have shipped.** All five Phase 5 animation widgets rebuild their
`AnimationController` in `didChangeDependencies` so a pack change re-times them, and all five
used `SingleTickerProviderStateMixin` — which asserts on a second ticker even after the first
is disposed. **A Vibe Pack reroll on Play Again is exactly that**, so the second game of every
session would have crashed. Nothing in the Phase 5 suite changed theme mid-widget; it surfaced
only because an interference test pumped one card under six packs in a row.

**What a human needs to do:**

1. **Play a full-chaos session.** Everything on, probability high, 6+ people. The question is
   whether it reads as a game bending or as noise — and if it is noise, which events to move
   off `defaultEnabled` rather than which to delete.
2. **Watch the Taboo reconciliation specifically.** It is the one event whose penalty the app
   cannot adjudicate, and the design bets that showing the words *after* the lap keeps the
   tension while making the call fair. That bet is untested at a table.
3. **Decide proposal 0002.** Interference does not change the shape of the Rounds/word-bank
   ceiling, but it does make the imposter-floor question concrete: Double Imposter can now put
   two imposters against one crew member at a small table.

**Golden count: 11 → 12.** `matrix_interference_card.png` was added; the other eleven came
back byte-identical, which is the check that nothing else moved. **A Linux run reporting
fewer than 12 golden groups means they stopped executing.**
