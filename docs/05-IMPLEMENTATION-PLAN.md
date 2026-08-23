# Implementation Plan

Eleven phases. A phase is done when its **audit** passes, not when its code exists. Do not
start N+1 before N is green.

**Sequencing logic:** engine before UI (rules testable without pixels) · **content in
parallel from the start** (it's the long pole and the playtests need it) · theming before
screens (so goldens have something stable to baseline) · core loop before Interference
(prove the base game is fun before bending it) · app before web (the app is the product,
the site is the shopfront).

| Phase | Focus | Audit |
|---|---|---|
| 0 | Foundation, templates, decisions | A0 Setup |
| 1 | Game engine, pure Dart | A1 Logic |
| 2 | **Content pipeline & word bank** | A2 Content |
| 3 | Vibe Packs & design system | A3 Theme baseline |
| 4 | Core loop UI | A4 Playability |
| 5 | Animation pass | A5 Performance |
| 6 | Interference Mode | A6 Balance |
| 7 | API & self-hosting | A7 API + Security |
| 8 | Public site & changelog | A8 Web + A11y |
| 9 | Admin console | A9 Access control |
| 10 | Release readiness | A10 Ship |

Prompts for each phase: **08-PROMPTS.md**.

---

## Phase 0 — Foundation

```
[x] Adopt flutter/games templates/basic as /app (07-TEMPLATES.md §1)
    [x] Strip AdMob, in_app_purchase, games_services, crashlytics in the FIRST commit
        — all four ALREADY ABSENT at upstream ae636d23; verified by grep, not removed.
        Actual residue stripped: a googlemobileads manifest tag and GameLevel's
        achievementId fields. See docs/adr/0002-templates.md
    [x] Swap provider → flutter_riverpod; keep audio/ and style/
        — upstream flattened lib/src/, so these are lib/audio/ and lib/style/
    [x] Swap lints → very_good_analysis (all 137 findings fixed, not suppressed)
[x] Scaffold /site (AstroWind + Starlight subpath), /admin (Kiranism starter),
    /api (Fastify), /e2e (Playwright), /content
[x] pnpm workspaces for JS; plain dirs for Flutter
[x] CI: jobs dart / web / api / e2e / contract — written and validated locally;
    NOT YET OBSERVED GREEN ON A PR (needs a push; see A0 below)
[x] Docker Compose: postgres + api + cloudflared
    — cloudflared moved behind a `tunnel` profile so plain `up -d` settles
[x] Playwright Docker baseline generation configured (official image in the e2e job)
[x] docs/adr/0001-stack.md and 0002-templates.md (which template, which commit,
    what was stripped, why)
[x] Set applicationId ph.teamlanzones.diakooi; ANDROID ONLY — no iOS job in CI,
    ios/ folder left buildable and untouched
[x] Perf target device: Vivo V60 Lite 5G (06-TESTING-STRATEGY.md §8)
[ ] Confirm the exact variant/chipset in Settings > About; record in docs/adr/0003
[ ] HUMAN: decide 120Hz vs capped 60Hz frame target; record as an ADR
[ ] HUMAN: run 10-TRADEMARK-SEARCH.md (~40 min) — blocks Phase 8
[ ] HUMAN: telemetry at launch, yes/no — blocks Phase 7
[x] Music sourcing: FREE/CC route decided — see 04-MUSIC-SOURCING.md
```

### A0 — Setup
- [ ] Every CLAUDE.md command executes without error
- [ ] CI runs all five jobs on a trivial PR
- [ ] `docker compose up -d` then `down` leaves no orphans
- [ ] No secrets in repo; `.env.example` exists
- [ ] Stripped template has zero references to ads/IAP/crashlytics remaining

---

## Phase 1 — Game Engine

```
[ ] freezed models per 01-DESIGN.md §11 — NO Room.code, NO Round.revote
[ ] FSM per §3 including VIBE_ROLL
[ ] Weighted topic selection (§13b) + no-repeat window
[ ] Imposter assignment, fresh roll per round
[ ] Turn rotation per §6a — per-round AND per-lap
[ ] resolveRound() PURE: accuser-pays, imposter −2, tally-weight-not-damage,
    Mayor tie rule (§7a), 2-life clamp last, Sudden Death as sole bypass
[ ] Life/consequence incl. restore-to-1 and High Stakes double-forfeit (§8)
[ ] Word bank loader + three-tier selection (§14)
[ ] Seeded RNG injected, never global
```

**Exit:** a 10-round game simulates in a test with zero Flutter imports.

### A1 — Logic
- [ ] `flutter analyze` clean; `lib/engine/` has no `package:flutter` import
- [ ] Engine line coverage ≥ 90%
- [ ] **Property:** across 10,000 seeded games, no player loses >2 lives in a round except
      via Sudden Death
- [ ] **Property:** crew always receive the real word; imposters never do
- [ ] **Property:** over 1,000 rounds, turn rotation gives every seat the last-speaker
      position within ±1 of uniform
- [ ] **Property:** topic draw converges to host weights within ±2% over 10,000 rounds,
      and the no-repeat window is never violated
- [ ] **Mayor table test:** no tie / tie Mayor voted in / tie Mayor didn't vote in (wash) /
      Mayor is one of the tied accused (wash)
- [ ] **Weight test:** a Double Vote player on a losing target loses exactly 1 life, not 2
- [ ] Table test: every §9b and §9c event resolves without throwing, alone and stacked
- [ ] Same seed → byte-identical transcripts across runs

---

## Phase 2 — Content Pipeline & Word Bank

Runs in **parallel** with Phase 1. It is the long pole: ~900 authored clues for launch.
Earlier drafts put content tooling in the admin console at Phase 9, which meant every
playtest ran on placeholder words. That was backwards.

```
[ ] CSV schema + validator (02-CONTENT-PH.md §5) as a standalone script — NOT the admin UI
[ ] Validation: word-in-clue, empty, >90 chars, tier similarity, duplicate, difficulty
[ ] JSON bundle generator → app/assets/wordbank/
[ ] One CSV per topic in /content/ so three authors never merge-conflict
[ ] HUMAN: calibration round — all 3 authors write the same 10 words, compare, then
    ratify /content/STYLE.md as v1 (a v0 draft already exists to argue with).
    02-CONTENT-PH.md §6a. DO THIS BEFORE AUTHORING AT SCALE
[ ] HUMAN: assign topic ownership, one owner per topic (§6b)
[ ] Wave 1 — pagkain · aktor · kpop · buhaypinoy · teleserye        (gates this phase)
[ ] Wave 2 — opm · lugar · brands · basketball                      (may land in Phase 4)
[ ] Wave 3 — internet · anime · kasaysayan                          (may land in Phase 4)
[ ] Difficulty rating every word; region = national
[ ] HUMAN: cross-review — every topic read by an author who didn't write it (§6c)
[ ] HUMAN: cultural review by Filipinos who did NOT author the content (§7)
[ ] Re-calibrate after the first 100 words — drift returns once people speed up
```

**Exit:** Wave 1 complete — 300 words / 900 clues validated and bundled, so a real game is
playable on real content by Phase 4's playtest. Waves 2 and 3 are version-driven and land
without blocking anything.

**Full launch target:** 720 words / 2,160 clues across all 12 topics, ~48 focused hours
split three ways.

### A2 — Content
- [ ] Validator rejects every failure class in 02-CONTENT-PH.md §5 (test each)
- [ ] `/content/STYLE.md` is at **v1**, not v0 — revision log signed by all three authors.
      A v0 draft in the repo is a starting point, not a ratified standard
- [ ] All Wave 1 topics at ≥ 60 words, zero validation errors
- [ ] **Tier separation:** no word where tight and standard read as near-identical
- [ ] **Cross-author consistency:** sample 10 words per author and confirm one author's
      "tight" is not another's "standard". This is the multi-author failure mode
- [ ] Every topic cross-reviewed by an author who didn't write it
- [ ] **Playtest calibration:** tight clues survive ≥3 crew clues, loose fail by lap 2
- [ ] Cultural review complete; flagged items resolved or cut
- [ ] Tested with at least one player under 20 and one over 45
- [ ] Bundle loads offline with no network

---

## Phase 3 — Vibe Packs & Design System

```
[ ] VibePack loader: track.ogg + theme.json + licence.json, data-driven
[ ] Riverpod provider + ThemeExtension; zero hardcoded design values anywhere
[ ] Motion profiles as real spring params — bouncy vs precise visibly different
[ ] Extend games-toolkit AudioController: loop, duck on reveal, stingers, mute
[ ] 6 launch packs sourced free/CC per 04-MUSIC-SOURCING.md; licence.json + licence
    screenshot committed for each; loop seams and levels checked
[ ] Primitives: PolaroidFrame, MonogramBadge, PlayerTile, LifePip, ItemBadge,
    PassInterstitial, ConstraintBanner, RevealCard, VibeWatermark
[ ] SPIKE: prototype hold-to-reveal blur on the V60 Lite and confirm it holds frame
    budget. If not, pick an alternative NOW (06-TESTING-STRATEGY.md §8b) — discovering
    this in Phase 5 means reworking the interaction the product is built around
[ ] Alchemist configured, CI mode, baselines generated IN DOCKER — they are
    byte-locked to Linux and skip elsewhere (docs/adr/0004-golden-baselines.md)
[ ] Widgetbook or equivalent gallery
```

**Exit:** every primitive has goldens across every pack, generated in Docker and
passing **in CI**.

### A3 — Theme baseline
- [ ] `flutter test --tags golden` green **in CI** on a clean checkout
- [ ] **Golden matrix: every primitive × every Vibe Pack** exists and passes **in CI**.
      Goldens execute on Linux only — a local green means they were *skipped*, not
      verified (docs/adr/0004-golden-baselines.md)
- [ ] **Every pack passes 4.5:1** body text and 3:1 large text contrast
- [ ] Crew vs imposter distinguishable **without colour** in every pack
- [ ] Watermark legible on every pack; never obstructs grid or card content
- [ ] **Every shipped track has a valid licence.json**; no uncleared commercial music
- [ ] Adding a 7th pack requires zero Dart changes (prove it)
- [ ] Reduced motion collapses all profiles to fade; palette still applies
- [ ] Layout holds at 320dp and 200% text scale

---

## Phase 4 — Core Loop UI

Interference is out of scope. Prove the base game.

```
[ ] Host setup: every §2 param, topic weight mixer + presets, Large Group auto-switch,
    host-as-player default-off warning (§2b)
[ ] Onboarding: name → selfie (Skip → monogram) → round-1 reveal
[ ] PRIVACY: in-memory capture + app/test/privacy/no_disk_write_test.dart
[ ] Reveal card: hold-to-reveal primary, tilt secondary
[ ] Pass interstitial with selfie + name + constraint banner slot
[ ] Discussion phase, roundabout tracking, optional soft timer (default off)
[ ] Voting grid: two-tap, live tally, progress indicator, self-vote rejected,
    Mayor tie wired to engine
[ ] Resolution, life check, consequence prompt, round recap
[ ] Game summary with the five §10 awards
[ ] Replay (roster persists, vibe rerolls) vs New Game (full teardown)
```

**Exit, split into two gates.** Content authoring is a parallel human track, so a single
exit condition mixing "the loop works" with "the words are good" leaves a finished phase
looking unfinished for a reason no code change can fix.

- **Machine gate — met.** Six seats play a full game on one device, offline, on the
  labelled placeholder bank. Everything the loop needs is present and exercised.
- **Human gate — open, and does not block Phase 5.** The same game played by real people
  on authored wave-1 content. Unblocks when Phase 2 authoring lands; tracked in
  `BLOCKED.md`.

Phases 5 and 6 depend on the loop, not on the bank. They proceed against the placeholder.

### A4 — Playability

Machine-closeable:

- [x] Airplane mode: no network call exists in the app — verified by construction; still
      needs one on-device run
- [x] `no_disk_write_test` passes
- [x] Every FSM transition reachable from UI; no dead ends
- [x] 20-player setup completes; Large Group Mode engages at 13
- [x] Topic weights produce the intended mix, measured over 6000 draws

Human gate — needs the handset:

- [ ] Airplane mode, full game, on the physical device
- [ ] Manually verify OS photo library untouched
- [ ] Kill and relaunch mid-game → no selfie recoverable from disk
- [ ] Back-button and interruption (call, notification) handled everywhere

Human gate — needs a table **and authored content**:

- [ ] **Manual playtest, 5+ real humans, on wave-1 content.** Record total time, per-round
      time, points of confusion, rules asked about twice. Non-negotiable, not simulatable
- [ ] Topic mix reads as intended to a table across a 10-round game
- [ ] **Playtest verdict on accuser-pays (§12.3):** did personal cost flatten discussion
      into safe consensus picks?
- [ ] **Playtest verdict on two-tap voting (§12.4):** fast enough at 10+?

---

## Phase 5 — Animation Pass

The stated differentiator. Competitors are largely browser wrappers with no native polish.

```
[ ] Selfie capture: shutter → develop → pin-to-corner; monogram uses IDENTICAL motion
[ ] Reveal: hold-to-clear blur, snap-in, crew/imposter treatment (Rive state machine)
[ ] Confirm-tap → handoff → interstitial as ONE beat
[ ] Voting grid: tiles respond, accuser thumbnails stack, tally builds
[ ] Resolution reveal with weight; consequence prompt with drama
[ ] EVERY animation reads timing/easing from the active pack's motion profile
[ ] Reduced-motion alternative for every animation
```

**Exit:** 60fps on a real mid-range Android, not the simulator.

### A5 — Performance
**Reference device: Vivo V60 Lite 5G** (Dimensity 7360-Turbo, Mali-G615 MC2, 120Hz).
Full profile and known risks: 06-TESTING-STRATEGY.md §8.
- [ ] **Frame target decided and recorded in an ADR: 120Hz/8.3ms or capped 60Hz/16.6ms.**
      This panel is 120Hz and Flutter follows the refresh rate — 16ms is NOT the budget
      unless you have explicitly capped
- [ ] Profile trace in **default power mode** (not performance mode): no frame over the
      chosen budget during reveal, handoff, or vote tally
- [ ] **Hold-to-reveal blur holds budget** — Mali-G615 MC2 is a 2-core GPU and this is the
      single most expensive interaction in the app. Prototyped back in Phase 3 (§8b)
- [ ] Jank check on the 20-player grid specifically
- [ ] Thermal check: 10 consecutive rounds, frame times stable as the device warms
- [ ] **Funtouch OS backgrounding:** app survives a call, a notification, and a background
      without losing in-memory session state INCLUDING selfies
- [ ] Profiled on the 8GB variant if you have one — test the worse case
- [ ] **Same trace run under at least two Vibe Packs** — a bouncy profile must not blow
      the budget a precise one meets
- [ ] No animation blocks input; all interruptible
- [ ] `MediaQuery.disableAnimations` honoured throughout
- [ ] Cold start under 2s **with audio preload** — only the drawn pack loads
- [ ] Memory flat across 10 rounds; no leak from selfie bytes or audio buffers

---

## Phase 6 — Interference Mode

```
[ ] Master toggle + 3 sub-toggles + per-event eligibility checklists
[ ] All §9b events, tagged app / social / retroactive
[ ] All §9c events; Sudden Death off by default; Item Drop gated on itemsEnabled
[ ] Item system: 10 items, one held, use-or-lose on second pickup
[ ] Taboo end-of-lap reconciliation (Clean / Slipped)
[ ] Constraint banners for socially-enforced rules
[ ] Suppression: lap-dependent events removed under No Roundabouts
[ ] Stacking precedence: player-pick → round-start → items → clamp
[ ] Tag every event requiresColocation + requiresItemSystem
[ ] Interference visuals driven by the pack's interference accent
```

### A6 — Balance
- [ ] Every event triggerable via debug menu, verified end-to-end
- [ ] Simulation: 10,000 games, all events on — no unbounded loss, no unreachable state,
      no crash
- [ ] **Spread the Blame produces a resolvable plurality** at 3, 10, and 20 players
- [ ] **Near-Unanimous cannot be unilaterally blocked** by imposters alone at any count
- [ ] **Mercy Round blocks every damage source**, not just vote resolution
- [ ] Every `enforcement: 'social'` event shows a constraint banner
- [ ] Every event has `requiresColocation` set — audit is a query, not a re-read
- [ ] Interference visual language clearly distinct from the calm reveal card
- [ ] Playtest: is a full-chaos session legible, or noise?

---

## Phase 7 — API & Self-Hosting

Spec first. `openapi.yaml` before implementation.

**Follow `docs/12-HOSTING.md`, not older hosting assumptions elsewhere in these docs.**
It is the source of truth for the topology, and §7 there is the setup checklist.

```
[ ] openapi.yaml: POST /v1/feedback, GET /v1/word-banks, GET /v1/word-banks/{topic},
    POST /v1/telemetry
[ ] Fastify + Zod at every boundary; Postgres schema + migrations
[ ] Feedback attachments: SHA-256 filenames, encrypted at rest, signed URLs (§16b)
[ ] Rate limiting on all public endpoints
[ ] Host: WSL2 + Docker Engine — NOT Docker Desktop, which needs an interactive
    login and so leaves the stack down after an unattended reboot (12-HOSTING §1b)
[ ] Repo cloned INSIDE the WSL filesystem, never under /mnt/c/ (12-HOSTING §1b)
[ ] Task Scheduler auto-start, verified across a real unattended reboot (§1c)
[ ] Cloudflare **Quick Tunnel** for beta — no domain purchased (§2a).
    The hostname rotates on every cloudflared restart
[ ] scripts/publish-endpoint.sh: scrape the new tunnel URL, write endpoint.json,
    publish it. Wired into WSL startup AFTER docker compose up (§2b)
[ ] App-side endpoint discovery: resolve the API base URL at runtime from
    endpoint.json, cache with a short TTL, and fall back SILENTLY to bundled
    content on any failure — offline, 404, timeout, malformed (§2b, §2c).
    **No hardcoded API base URL anywhere, ever**
[ ] Tailscale: admin + Postgres bound to the tailnet IP only, NO Funnel (§4)
[ ] Cloudflare Tunnel ingress lists the API hostname ONLY — never a wildcard (§4)
[ ] pg_dump cron, encrypted, off-box — AND a tested restore (§5)
[ ] App-side: word-bank sync with bundled fallback, offline feedback queue
[ ] LATER, on any §2a trigger: buy a domain, switch to a Named Tunnel. This is a
    one-line endpoint.json edit with zero app changes, provided §2b was followed
```

### A7 — API + Security
- [ ] `schemathesis run api/openapi.yaml --checks all` passes
- [ ] Vitest + Supertest cover happy and error paths per endpoint
- [ ] **Every error shape documented in the spec** — the most common contract gap
- [ ] Rate limits verified by test, not inspection
- [ ] **External port scan:** only Cloudflare-proxied 443 responds. Verified from mobile
      data with Tailscale OFF, not by reading the config (12-HOSTING §4)
- [ ] Endpoint discovery proven: app falls back silently with `endpoint.json` unreachable
- [ ] Admin unreachable off-tailnet — verified from an outside network
- [ ] No selfie-shaped payload accepted by any endpoint; assert in a test
- [ ] Telemetry contains no names, photos, or device identifiers
- [ ] **Restore drill:** rebuild the DB from backup into a clean container
- [ ] Secrets in env; DB not exposed on 0.0.0.0

---

## Phase 8 — Public Site

Page specs in `09-WEB-SPEC.md`.

```
[ ] AstroWind landing + Starlight subpath for changelog/how-to-play
[ ] Landing, Changelog, How to Play, Privacy, Feedback, Press/About
[ ] Privacy policy stating the v1-SCOPED selfie claim accurately (§4b)
[ ] Music attribution page listing every pack's licence
[ ] Feedback form → POST /v1/feedback
[ ] OG images, sitemap, robots.txt, favicon set
[ ] Deploy: Cloudflare Pages, separate from the home-server API
```

### A8 — Web + Accessibility
- [ ] Playwright E2E: pages load, nav works, feedback form submits
- [ ] Visual baselines at 375 / 768 / 1440, Docker-generated
- [ ] axe-core: zero critical or serious violations
- [ ] Keyboard-only pass through the whole site including the form
- [ ] Every internal and external link resolves — automated crawl
- [ ] Lighthouse ≥ 95 performance, ≥ 100 accessibility
- [ ] **Privacy policy reviewed line by line against actual app behaviour**
- [ ] **Music attribution page matches every licence.json in the build**
- [ ] Changelog entries match shipped git tags

---

## Phase 9 — Admin Console

```
[ ] Next.js + shadcn from the vetted starter (07-TEMPLATES.md §3)
[ ] Auth: single admin. Tailnet-bound is the real control
[ ] Feedback triage: list, filter, status, attachment view, notes
[ ] Telemetry: sessions, player-count distribution, topic weight popularity,
    Vibe Pack draw rates, Interference adoption, rounds per game
[ ] Word bank UI on top of the Phase 2 pipeline: CRUD, three-tier editor,
    CSV import/export, versioned atomic publish, quality flags
```

### A9 — Access control
- [ ] Playwright: every route redirects when unauthenticated
- [ ] Console unreachable from a non-tailnet network — verified externally
- [ ] Word-bank publish atomic; a failed publish leaves the previous version live
- [ ] Destructive actions confirm; deletes are soft
- [ ] Attachments via signed URLs, never raw paths
- [ ] Admin action log exists

---

## Phase 10 — Release Readiness

```
[ ] Beta: Play internal testing, or direct APK from the site
[ ] Crash reporting, privacy-clean config
[ ] Play Store assets; content rating questionnaire — open-ended forfeits and
    Truth-or-Dare framing will push this higher than you expect
[ ] Support email and response process
[ ] v1.0.0 tagged; changelog published
[ ] docs/adr complete
```

### A10 — Ship
- [ ] Full playtest on real Android hardware (iOS out of scope for v1)
- [ ] Fresh install on a device that has never run the app
- [ ] All prior audits re-run green on the release commit
- [ ] Play Data Safety declaration matches actual collection, field by field
- [ ] **10-TRADEMARK-SEARCH.md §7 exit criteria met**
- [ ] **Every bundled track's licence permits commercial distribution on Google Play**,
      with the licence screenshot on file (04-MUSIC-SOURCING.md §6)
- [ ] 01-DESIGN.md §12 open items closed or consciously deferred with a note

---

## Standing rules

**Every phase:** `flutter analyze` and lint clean · full suite green · no new TODO without
a linked issue · dependencies checked for advisories.

**"Full suite green" means green in CI.** Golden tests execute on Linux only. On a Windows
or macOS machine they skip, print a `GOLDENS NOT VERIFIED` banner, and the run still exits
0 — so a local pass is not visual verification. See docs/adr/0004-golden-baselines.md.

**Escalate to a human when:**
- A design rule appears wrong (propose, don't patch — several are counterintuitive on
  purpose)
- An audit fails twice for the same reason
- A privacy, security, or **licensing** control needs weakening for any reason at all
- A phase looks like it will take more than double its estimate
