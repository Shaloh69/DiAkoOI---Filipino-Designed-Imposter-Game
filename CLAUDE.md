# CLAUDE.md

DiAkoOi ("Di Ako, 'Oi!" — *not me*) — pass-and-play Filipino social deduction party game.
Flutter app (offline-first), Astro public site, Next.js admin console, Node/Postgres API.
See `docs/00-START-HERE.md`.

**Identity:** application id `ph.teamlanzones.diakooi` · **Android only for v1** — no iOS
target, no TestFlight. Distribution is Play internal testing or a direct APK from the
site. Keep the iOS folder buildable but do not spend time on it.

## Structure

```
/app          Flutter mobile app — the game
  /lib/engine   pure Dart game logic, NO Flutter imports
  /lib/ui       widgets, screens, animations
  /assets/vibes Vibe Packs: track.ogg + theme.json + licence.json
  /test         unit + widget tests
  /test/golden  Alchemist golden tests
  /test/privacy disk-write assertions — off-limits
/site         Astro (AstroWind + Starlight subpath) — public site & changelog
/admin        Next.js + shadcn/ui — admin console
/api          Node + Fastify + Postgres    (/openapi.yaml is the contract)
/content      word bank CSVs, per topic
/e2e          Playwright — /site and /admin ONLY
/docs         numbered specs, 00-11, in reading order
/docs/adr     architecture decision records
CLAUDE.md     this file — MUST keep this exact name, Claude Code loads it by filename
```

## Commands

```bash
cd app && flutter test                      # unit + widget
cd app && flutter test --tags golden        # golden only
cd app && flutter test --update-goldens     # regenerate baselines
cd app && flutter analyze                   # must be clean

cd site && pnpm dev | pnpm build
cd admin && pnpm dev | pnpm build | pnpm lint
cd api && pnpm test | pnpm dev

cd e2e && pnpm exec playwright test
schemathesis run api/openapi.yaml --checks all
docker compose up -d
```

## Hard rules

**Selfies never touch disk or network.** In-memory `Uint8List` only, tied to the session,
discarded on new roster. `image_picker` and `camera.takePicture()` write temp files by
default — capture from the preview stream instead, or read-then-delete in a `finally`.
`app/test/privacy/no_disk_write_test.dart` must assert zero new files under temp and
documents dirs across a full onboarding run. Never weaken this test.

**Music must be licensed, and the licence recorded.** Every pack in `assets/vibes/` ships
a `licence.json` with source, type, URL, and attribution. No record, no ship. Never add a
commercial track — see 03-VIBE-SYSTEM.md §1 for why a credit watermark is not a licence.
Sourcing plan and per-track workflow: 04-MUSIC-SOURCING.md.

**No hardcoded design values.** Every colour, duration, radius, and spacing resolves from
the active Vibe Pack theme. A hardcoded `Color(0xFF...)` outside a theme file is a bug.

**`lib/engine/` imports nothing from Flutter.** Pure Dart. Resolution is a pure function
`(votes, roles, modifiers, itemUsages) → lifeDeltas` with the damage cap as a final clamp.
No game logic in widget callbacks.

**The app works fully offline.** No network call may block starting or finishing a game.
Word bank and all Vibe Pack audio ship bundled; the server copy is an update, not a
dependency.

**`01-DESIGN.md` is the source of truth for rules.** Do not invent or "fix" mechanics.
Several look wrong until you read the rationale — §7a (Mayor), §7b (damage cap), §9b
(Role Swap rejection), and §9c (Spread the Blame, Near-Unanimous) especially. If something
seems underspecified, check §12, then ask.

**Content is Philippine-only.** Every topic and clue is authored for a Filipino table, in
natural Taglish. Never generate a generic global word list. See 02-CONTENT-PH.md.

**Playwright never touches the Flutter app.** Browsers only. Flutter visual regression is
Alchemist goldens.

## Conventions

- **Dart**: `very_good_analysis`. Feature-first folders. Riverpod. `freezed` +
  `json_serializable`. No `dynamic` without a comment.
- **TypeScript**: strict. Zod at every boundary. No `any`. Named exports.
- **API**: REST, plural nouns, kebab-case, `/v1/` prefix. Success `{ data, meta }`, error
  `{ error: { code, message } }`. `openapi.yaml` written first.
- **Naming**: the chaos layer is **Interference Mode**, never "Chaos Mode" — a competitor
  ships a Chaos Mode meaning something else. Never revert this.
- **Commits**: Conventional Commits, one per task. **Branches**: `phase/NN-short-name`.

## Testing

Read `06-TESTING-STRATEGY.md` before writing tests.

| Layer | Tool | Where |
|---|---|---|
| Game logic | `flutter test` | `app/test/engine/` |
| Widget behaviour | `flutter test` | `app/test/ui/` |
| Flutter visuals | Alchemist goldens | `app/test/golden/` |
| Flutter E2E | `integration_test` | `app/integration_test/` |
| API contract | Schemathesis | CI |
| API behaviour | Vitest + Supertest | `api/test/` |
| Web E2E + visual | Playwright | `e2e/` |

Goldens: Alchemist **CI mode**, baselines generated in Docker. Golden primitives and
reveal-card states, not whole screens. **The golden matrix is every primitive × every Vibe
Pack** — that's what proves theming works and catches hardcoded values.

**Goldens execute on Linux/CI only.** Baselines are byte-locked to Linux, so on Windows or
macOS the golden groups skip, print a `GOLDENS NOT VERIFIED` banner, and the run still
exits 0. **A local green is not verification** — only CI is. Regenerate and verify with
`docker compose -f docker-compose.goldens.yml run --rm goldens`. See
`docs/adr/0004-golden-baselines.md`.

Playwright visual: `animations: 'disabled'`, mask dynamic content, Docker baselines
committed, `updateSnapshots: 'none'` in CI.

## Off-limits without explicit instruction

- `app/test/privacy/` — the disk-write assertions
- `assets/vibes/*/licence.json` — licence records
- `api/openapi.yaml` — regenerate clients, don't hand-edit to match code
- Any committed golden or Playwright baseline — update via flag, review the diff
- `01-DESIGN.md` — propose changes, don't apply them

## Process

- Plan first for anything touching more than two files; wait for approval.
- Finish each phase with its audit from `05-IMPLEMENTATION-PLAN.md`; paste results in the PR.
- Use subagents for research so exploration stays out of the main context.
- Record non-obvious decisions as an ADR in `docs/adr/`.
- Prompt library for each phase is in `08-PROMPTS.md`.
