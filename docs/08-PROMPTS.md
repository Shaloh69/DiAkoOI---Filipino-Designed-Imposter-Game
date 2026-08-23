# Claude Code Prompt Library

Phase-scoped prompts. Each is designed to be pasted whole into Claude Code at the start of
a session. They assume `CLAUDE.md` is loaded automatically.

---

## 1. How to prompt this project

**The four rules that change output quality most:**

1. **Plan mode before anything spanning more than two files.** `claude --plan` or ask for a
   plan and approve it. Skipping this is the single biggest cause of rework.
2. **Be specific, not aspirational.** "Write clean code" is noise. "Use Riverpod, see
   `lib/state/`, no logic in widget callbacks" changes behaviour.
3. **Subagents for research.** "Use a subagent to read the games-toolkit audio controller
   and report back how it handles lifecycle" keeps 40k tokens of exploration out of your
   main context.
4. **Reference the doc, don't restate it.** "Implement §7a exactly as written" beats
   pasting §7a — and if the model deviates you have a single source to point at.

**Design-specific rules for this project:**

- **Never let it invent visual design.** Every colour, radius, duration, and spacing value
  comes from the active Vibe Pack's `theme.json` (03-VIBE-SYSTEM.md §2). A prompt that
  produces a hardcoded `Color(0xFF...)` anywhere outside a theme file has failed, and the
  golden matrix will catch it.
- **Ask for the golden test in the same prompt as the widget.** Otherwise you get a widget
  and a promise.
- **Give it the failure mode, not just the goal.** "Capture the selfie" produces a
  disk-writing implementation. "Capture the selfie without ever writing to disk —
  `image_picker` and `takePicture()` both write temp files, use `startImageStream()`"
  produces the right one.

---

## 2. Phase 0 — Foundation

```
Read 00-START-HERE.md and CLAUDE.md first, then produce a plan before writing any code.

Set up the DiAkoOi monorepo per CLAUDE.md §Structure. Do not write any feature code.

1. Adopt the Flutter Casual Games Toolkit basic template as /app:
   git clone --filter=blob:none https://github.com/flutter/games.git
   Copy templates/basic to /app. Then, in the FIRST commit:
     - VERIFY AdMob, in_app_purchase, games_services and crashlytics are absent
       (they are, at upstream ae636d23), then remove the residue they left:
       the googlemobileads FLUTTER_GAME_TEMPLATE_VERSION meta-data tag in
       AndroidManifest.xml, and achievementIdIOS/achievementIdAndroid on
       GameLevel in lib/level_selection/levels.dart
     - replace provider with flutter_riverpod
     - keep lib/audio/ and lib/style/ — the Vibe Pack system builds on both
     - swap lints to very_good_analysis
     - remove bundled placeholder music/SFX from the repo, leave the folders
2. Scaffold /site (AstroWind), /admin (Kiranism/next-shadcn-dashboard-starter),
   /api (Fastify + Postgres), /e2e (Playwright). pnpm workspaces for the JS side.
3. Docker Compose: postgres + api + cloudflared. `docker compose up -d` must succeed.
4. GitHub Actions with jobs: dart, web, api, e2e, contract. All must run green on the
   empty scaffolds.
5. Write docs/adr/0001-stack.md AND docs/adr/0002-templates.md — the second records
   which template, which upstream commit, and exactly what was stripped.

Verify every command in CLAUDE.md §Commands executes without error, then run the Phase 0
audit from 05-IMPLEMENTATION-PLAN.md and paste results. Stop there.

> **Corrected 2026-08-23, after Phase 0 ran this prompt.** Two instructions above were
> wrong and are fixed in place: there is no `lib/src/` at upstream `ae636d23` (the tree is
> flattened to `lib/`), and none of the four monetisation/telemetry packages are present, so
> that step is a verification plus residue removal rather than a strip. Full detail in
> `docs/07-TEMPLATES.md` §1 and `docs/adr/0002-templates.md`. Phase 0 is already complete;
> this prompt is kept for the record.
```

---

## 3. Phase 1 — Engine

```
Implement the DiAkoOi game engine in app/lib/engine/ as PURE DART. No package:flutter
import may appear anywhere in that directory — this is enforced in CI.

01-DESIGN.md is the source of truth. Several rules look wrong until you read the rationale;
§7a, §7b, and §9b in particular are counterintuitive on purpose. Do not "fix" them. If
something seems underspecified, check §12 open items, then ask.

Build:
1. freezed models mirroring 01-DESIGN.md §11 exactly. Note: no Room.code, no Round.revote —
   both were deliberately removed.
2. Finite state machine per 01-DESIGN.md §3, including the VIBE_ROLL state.
3. Weighted topic selection (§13b): roll against host weights, enforce the no-repeat
   window (no word twice per session, no topic more than twice consecutively).
4. Imposter assignment, N per round, fresh roll each round.
5. Turn rotation per §6a — per-round AND per-lap shift.
6. resolveRound() as a PURE function:
     (votes, roles, modifiers, itemUsages) -> lifeDeltas
   It must implement:
     - accuser-pays (§7)
     - caught imposter -2
     - tally weight affects TALLY ONLY, never damage (§7 explicit)
     - Mayor tie rule per §7a — weight applies ONLY when a tie exists, and a tie the
       Mayor didn't vote in, or where the Mayor is accused, is a wash
     - 2-lives-per-round clamp as a FINAL step (§7b)
     - Sudden Death as the sole cap bypass
7. Life/consequence system incl. restore-to-1 after serving, and the High Stakes
   double-forfeit rule in §8 (restore once, after the second).
8. Word bank loader with three-tier clue selection (§14).
9. Seeded RNG injected everywhere, never global. Determinism is required.

Write unit tests as you go, not after. Target 90% line coverage on the engine.
Exit criteria: a full 10-round game simulates in a test with zero Flutter imports.
```

---

## 3a. Phase 2 — Content pipeline & word bank

> **Added 2026-08-23.** This section did not exist: the file jumped from Phase 1 straight to
> Phase 3, so a session reaching Phase 2 had no brief and had to reconstruct it from
> `05-IMPLEMENTATION-PLAN.md` and `02-CONTENT-PH.md`. Written from what Phase 2 actually
> built, so the next reader does not repeat that.

```
Read 02-CONTENT-PH.md and content/STYLE.md fully before starting.

Phase 2 runs in PARALLEL with Phase 1 and is the long pole: ~2,160 authored clues.
It cannot be finished by a machine. Build the whole pipeline, generate candidates,
and leave A2 explicitly AUDIT-INCOMPLETE.

Build:
1. CSV schema + validator as a STANDALONE SCRIPT, not the admin console. Authors must
   be able to check their own file before anyone imports anything, and CI must be able
   to reject a broken bank without a browser.
2. Validation per 02-CONTENT-PH.md §5. Respect the reject/warn split exactly:
     REJECT — clue contains the word or a synonym, any clue empty, duplicate word
              within a topic, difficulty outside 1-5, unknown topic, unknown region
     WARN   — clue over 90 characters, tight/standard too similar (§3)
   A warning that blocked would make authors edit around the tool instead of thinking.
3. JSON bundle generator -> app/assets/wordbank/. Sort topics and words so the
   committed bundle diffs cleanly, and decode the result back through the engine's
   own WordBankEntry in a test — valid JSON is not the same as loadable.
4. One CSV per topic in /content/ so three authors never merge-conflict. Header only;
   authored rows are theirs to add.
5. Tests for the validator itself, one per failure class in §5.

Then:
6. Generate CANDIDATE drafts for wave 1 into content/drafts/, NOT content/. Follow
   content/STYLE.md — list features per word, write all three tiers. These are drafts
   for humans to edit and reject, and the tooling must not be able to bundle them by
   accident.
7. Ship a clearly-labelled placeholder bundle (~20 words) so Phase 4 has something to
   run. Flag it in the bundle itself, not just in a comment.

A2 stays AUDIT-INCOMPLETE until humans ratify content/STYLE.md at v1, author wave 1 at
60+ words per topic, cross-review it (§6c) and complete cultural review (§7). Record
that in BLOCKED.md and say so in the PR. Do not mark the phase done.
```

---

## 4. Phase 3 — Design system + Vibe Packs

```
Read 03-VIBE-SYSTEM.md fully before starting. Plan first.

Build the Vibe Pack theming system and the design-system primitives.

1. VibePack loading: assets/vibes/<id>/{track.ogg, licence.json, theme.json}.
   Themes are DATA. Adding a pack must never require a Dart change.
2. Riverpod provider exposing the active VibePack; a ThemeExtension so widgets read
   tokens. NO widget may contain a hardcoded colour, duration, or radius — every value
   resolves from the active theme.
3. Motion profiles must be real spring parameters that produce visibly different
   behaviour. "bouncy" and "precise" should be obviously distinct when you hold a card.
4. Primitives: PolaroidFrame, MonogramBadge, PlayerTile, LifePip, ItemBadge,
   PassInterstitial, ConstraintBanner, RevealCard, VibeWatermark.
5. Extend the games-toolkit AudioController for: session track loop, ducking on reveal
   (~6dB), interference stingers, mute that KEEPS the watermark visible.
6. Alchemist goldens in CI mode, generated in Docker.

CRITICAL: the golden matrix is every primitive x every Vibe Pack. That matrix is what
proves the theming system actually works rather than being decoration, and it's what
catches a hardcoded colour immediately.

Also verify per pack: text contrast >= 4.5:1, and crew/imposter accents distinguishable
WITHOUT colour (shape or texture too) since the accent pair changes per pack.
```

---

## 5. Phase 4 — Core loop UI

```
Plan first. Interference Mode is explicitly OUT of scope — prove the base game works.

Build per 01-DESIGN.md §2-§8, §13:
1. Host setup: every §2 parameter. Topic weight mixer with presets (§13b). Large Group
   Mode auto-switch at 13. The host-as-player default-off warning per §2b.
2. Onboarding: name -> selfie (with Skip -> monogram) -> round-1 reveal.
3. PRIVACY, read 01-DESIGN.md §4b carefully: the APP must never write the selfie to
   storage. image_picker and camera.takePicture() BOTH write temp files by default and
   will silently break this. Use CameraController.startImageStream() and grab one frame
   to Uint8List, DOWNSCALED to display resolution at capture. Then write
   app/test/privacy/no_disk_write_test.dart asserting zero new files under temp and
   documents dirs across a full onboarding run, carrying the scope comment from
   app/test/privacy/README.md. Do NOT claim the selfie "never touches disk" — vendor
   Extended RAM pages memory below our layer (ADR 0005).
4. Reveal card: hold-to-reveal primary, tilt as secondary flourish only.
5. Pass interstitial with selfie + name, carrying the constraint banner slot.
6. Discussion phase with roundabout tracking; optional soft clue timer, default off.
7. Voting grid: two-tap (caller -> accused), live tally, progress indicator, self-vote
   rejected, Mayor tie handling wired to the engine.
8. Resolution, life check, consequence prompt (free-text), round recap.
9. Game summary with the five award callouts in §10.
10. Replay (roster + selfies persist, vibe rerolls) vs New Game (full teardown).

Exit: six people can play a full game on one device in airplane mode.
```

---

## 6. Phase 5 — Animation pass

```
Read 03-VIBE-SYSTEM.md §3 for motion profiles. This is the stated product differentiator —
competitors in this genre are largely browser wrappers with no native polish, so this
phase is where DiAkoOi wins or doesn't.

Every animation below must read its timing and easing from the active Vibe Pack's motion
profile. A "bouncy" reveal and a "precise" reveal should feel like different apps.

1. Selfie capture: shutter flash -> develop -> pin-to-corner with rotation. The monogram
   fallback uses the IDENTICAL motion so it never reads as a downgrade.
2. Reveal: hold-to-clear blur, word snap-in, crew/imposter treatment.
3. Confirm-tap -> handoff -> next interstitial as ONE continuous beat, never a cut.
4. Voting grid: tiles respond as votes land, accuser thumbnails stack, tally builds
   visibly.
5. Resolution reveal with real weight. Consequence prompt with dramatic framing.
6. Use Rive for the reveal card specifically — it needs a state machine
   (idle -> holding -> revealed -> closing, x crew/imposter). flutter_animate for
   transitions and micro-interactions. Hero + AnimatedBuilder for the pass interstitial,
   no package.
7. Reduced-motion alternative for EVERY animation above. MediaQuery.disableAnimations
   collapses motion to a fade; the palette still applies.

Reference device is a Vivo V60 Lite 5G: Dimensity 7360-Turbo, Mali-G615 MC2 (2-core
GPU), 8GB LPDDR4X, and a 120Hz AMOLED panel. Read 06-TESTING-STRATEGY.md §8.

The 120Hz panel means the frame budget is 8.3ms, NOT 16ms, unless the app is explicitly
capped to 60. Confirm which target is recorded in the ADR before optimising against the
wrong number.

Profile in DEFAULT power mode, not performance mode — players won't change it.
Check the 20-player grid and a 10-round thermal run specifically.
```

---

## 7. Phase 6 — Interference Mode

```
Read 01-DESIGN.md §9 fully. Plan first.

Note three rules that were fixed from earlier drafts and must be implemented as written:
- Spread the Blame caps duplicates at 2. A full "no duplicates" ban is mathematically
  unresolvable (N voters across N tiles = permanent N-way tie).
- Near-Unanimous uses a 75% threshold, NOT true unanimity. Under true unanimity a lone
  imposter simply names someone nobody else did and guarantees a free round.
- Mercy Round blocks ALL life loss from any source, not just vote resolution.

Build:
1. Master toggle + three sub-toggles + per-event eligibility checklists.
2. All §9b player-pick events, tagged app / social / retroactive.
3. All §9c round-start events. Sudden Death unchecked by default. Item Drop only
   eligible when the item system is on.
4. Item system: 10 items, one held, use-or-lose on second pickup.
5. Taboo end-of-lap reconciliation (Clean / Slipped).
6. Constraint banners for socially-enforced rules (§9f).
7. Suppression: lap-dependent events removed under No Roundabouts.
8. Stacking precedence: player-pick -> round-start -> items -> damage clamp.
   Contradictions resolve toward whichever effect PROTECTS a player.
9. Tag every event with requiresColocation and requiresItemSystem.
10. Interference visual language: distinct from the calm reveal card, and driven by the
    active Vibe Pack's interference accent so it looks different every session.

Verify with a simulation of 10,000 games with all events enabled: no unbounded life loss,
no unreachable state, no crash.
```

---

## 8. Reusable prompt fragments

**When output drifts from the design:**
```
Stop. 01-DESIGN.md §<n> specifies this differently. Re-read it and explain the discrepancy
before changing anything. If you think the design is wrong, say so and why — do not
silently implement your version.
```

**When you want the test too:**
```
Include the Alchemist golden covering: default, active, disabled, overflow-long-name,
monogram fallback, and every Vibe Pack. Generate baselines in Docker, not locally.
```

**Research without burning context:**
```
Use a subagent to investigate <X> and report back a summary. Do not paste source files
into the main context.
```

**Before a phase ends:**
```
Run the Phase <N> audit from 05-IMPLEMENTATION-PLAN.md. Paste every checkbox with its actual
result — not a claim that it passes. A phase is not done because the code exists.
```

**Design review:**
```
Review this screen against 03-VIBE-SYSTEM.md. Flag: any hardcoded colour/duration/radius,
any contrast below 4.5:1 in any pack, any animation without a reduced-motion path, and
anywhere crew/imposter is distinguished by colour alone.
```
