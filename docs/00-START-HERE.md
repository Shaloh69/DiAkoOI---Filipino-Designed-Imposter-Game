# START HERE

**Read this, then `CLAUDE.md`, then stop and confirm a plan before writing code.**

You are picking up a game project from a design phase. Everything is specified; nothing is
built. Your first job is not to write code — it is to set up the repo so all later work is
verifiable.

---

## 1. What this is

**DiAkoOi** — from *"Di ako, 'oi!"*, "Not me!" — a pass-and-play social deduction party
game **built for Filipino players**. One phone goes around the group. Everyone sees a
secret word except the imposter(s), who get a deliberately vague clue. Players describe
the word aloud in Taglish, then accuse. Bad accusations cost the accusers personally.
Players at zero lives take an open-ended forfeit, then return with one life.

| Surface | Stack | Purpose |
|---|---|---|
| **Mobile app** | Flutter | The game. Fully offline |
| **Public site** | Astro (AstroWind + Starlight) | Landing, changelog, privacy, feedback |
| **Admin console** | Next.js + shadcn/ui | Feedback triage, telemetry, word banks |
| **API** | Node + Fastify + Postgres, self-hosted | Feedback, word-bank delivery, telemetry |

**Identity:** application id `ph.teamlanzones.diakooi`. **Android only for v1** — no iOS
target. Not on any store yet, so the public site is the release vehicle and a first-class
deliverable, not an afterthought.

---

## 2. Read these in order

Files are numbered in reading order. **`CLAUDE.md` is deliberately not numbered** — Claude
Code auto-loads it by that exact filename, and renaming it silently breaks the load. It
must stay `CLAUDE.md` at the repo root. Everything else lives in `/docs`.


1. **`CLAUDE.md`** — conventions, commands, hard rules. Loaded every session.
2. **`01-DESIGN.md`** — the game. **Source of truth for all rules.** Don't invent mechanics;
   if something seems underspecified, check §12 before assuming.
3. **`02-CONTENT-PH.md`** — the Philippine word bank. This is the actual product moat.
4. **`03-VIBE-SYSTEM.md`** — music-driven theming. **Read §1 before touching audio.**
5. **`05-IMPLEMENTATION-PLAN.md`** — eleven phases with audits. Work in order.
6. **`06-TESTING-STRATEGY.md`** — what gets tested with what. Read before writing any test.
7. **`07-TEMPLATES.md`** — vetted starting points. Use these instead of searching.
8. **`08-PROMPTS.md`** — phase-by-phase Claude Code prompts.
9. **`09-WEB-SPEC.md`** — page-by-page spec for site and console.
10. **`04-MUSIC-SOURCING.md`** — the free-track hunt list and per-track workflow.
11. **`10-TRADEMARK-SEARCH.md`** — the search protocol, ready to run.
12. **`12-HOSTING.md`** — the self-hosting topology. **Nothing before Phase 7 needs it**,
    but read §2b before writing any networking code: the API hostname rotates, so the app
    resolves it at runtime and must never hardcode a base URL.

---

## 3. Five things that will trip you up

**Playwright cannot test the Flutter app.** Playwright drives browsers; the game is a
Flutter mobile app. Use `flutter test` for unit/widget, **Alchemist** for goldens,
`integration_test` for E2E. Playwright covers `/site` and `/admin` only. Getting this wrong
wastes days — see `06-TESTING-STRATEGY.md` §1.

**The app must never write a selfie to storage or transmit one.** This is the stated
privacy differentiator (`01-DESIGN.md` §4b). Both `image_picker` and `camera.takePicture()`
write a temp file by default, silently breaking the promise. Capture from the preview
stream into `Uint8List`, downscale at capture, or read-then-delete inside a `finally`. A
required test asserts zero new files across a full onboarding run.

Say it at that scope and no wider. "Never touches disk" is **not** guaranteeable — vendor
Extended RAM pages memory below the app layer (ADR 0005).

**Music must be licensed, and a credit is not a licence.** You cannot ship instrumentals of
commercial songs — recordings carry two separate copyrights and indie licensing runs
$500–$2,000 per track. Worse, uncleared audio gets your *players'* TikToks Content-ID'd,
which kills the word of mouth a party game runs on. Source from cleared libraries or
commission a Filipino artist. `03-VIBE-SYSTEM.md` §1 has the full rules and sources.

**Nothing may hardcode a design value.** Colour, duration, radius, spacing — all resolve
from the active Vibe Pack theme. The golden matrix (every primitive × every pack) is what
catches violations, and it's what proves the theming system is real rather than decoration.

**The resolution function must stay pure.** `(votes, roles, modifiers, itemUsages) →
lifeDeltas`, damage cap applied as a final clamp. No game logic in widget callbacks. This
is what makes interference stacking testable and what moves server-side unchanged in v2.

---

## 4. Phase 0 — do this now

```
[ ] Adopt flutter/games templates/basic as /app; strip ads/IAP/crashlytics in commit one
[ ] Scaffold /site, /admin, /api, /e2e, /content per CLAUDE.md §Structure
[ ] CI: GitHub Actions, jobs dart / web / api / e2e / contract
[ ] Docker Compose: postgres + api + cloudflared
[ ] docs/adr/0001-stack.md and 0002-templates.md
[ ] Run the Phase 0 audit in 05-IMPLEMENTATION-PLAN.md
```

**Then stop and report.** Do not proceed to Phase 1 without the audit passing.

The prompt for this is ready to paste: `08-PROMPTS.md` §2.

---

## 5. Decisions — status

**Settled:**
- Application id `ph.teamlanzones.diakooi`, **Android only** for v1
- All 12 topics at launch, wave-ordered (02-CONTENT-PH.md §1), authored by three people
- All 11 phases in scope
- **Music: free/CC route** — sourcing plan in 04-MUSIC-SOURCING.md

**Still open, with owners:**
1. **Perf target device** — name the actual Android phone A5 profiles on, or the audit
   cannot be failed. Anything mid-range from the last 3 years is fine; it just has to be
   *named* and physically available.
2. **Trademark search on "DiAkoOi"** — protocol ready to run in 10-TRADEMARK-SEARCH.md, ~40
   minutes. *Blocks Phase 8.* No app-store conflict found in a preliminary check, which is
   encouraging and is not clearance.
3. **Telemetry at launch, yes or no.** Any collection requires a privacy policy URL and a
   Play Data Safety declaration. Aggregate-only counters are assumed (`01-DESIGN.md` §16a);
   shipping with zero telemetry is defensible and simpler. *Blocks Phase 7.*

---

## 6. How to work

- **Plan before editing.** Anything spanning more than two files gets a plan and approval.
- **Commit per task**, not per phase. Small commits are the undo button.
- **Branch per phase:** `phase/04-core-loop-ui`.
- **Run the audit at the end of every phase** and paste results into the PR. A phase is
  not done because the code exists.
- **When `01-DESIGN.md` and your instinct disagree, `01-DESIGN.md` wins** — or you raise the
  conflict. Several rules look wrong until you read the rationale. §7a (the Mayor tie
  rule), §7b (the damage cap), and §9c (why Spread the Blame caps at 2 rather than banning
  duplicates) are the clearest examples: each fixes a bug that a "cleaner" version
  reintroduces.
- **Use subagents for research** so exploration doesn't eat the main context.
- **Phase prompts are pre-written** in `08-PROMPTS.md` — start there rather than improvising.

---

## 7. Definition of done for v1

- Six people play a full game start to finish on one phone with no network
- Twelve topics × 60 words × 3 authored clue tiers, cross-reviewed and cultural review passed
  (Wave 1 of five topics is the Phase 2 gate; waves 2–3 may land during Phase 4)
- Six Vibe Packs, each with a valid licence record, each passing contrast checks
- Every phase audit passes
- Golden matrix covers every primitive × every pack
- Playwright green for site and console including visual baselines
- API has an OpenAPI spec and Schemathesis passes
- Public site has a real changelog, privacy policy, music attribution page, and a working
  feedback form
- No selfie has ever been written to disk — with a test proving it
