# Testing Strategy

*DiAkoOi. Read alongside `CLAUDE.md` §Testing.*

## 1. The tool split — read this before writing any test

The single most expensive mistake available on this project is assuming Playwright can
test the game. It cannot. Playwright drives browsers; the game is a Flutter mobile app.

| Surface | Tool | Why |
|---|---|---|
| Game logic (`lib/engine/`) | `flutter test` | Pure Dart, no device needed, milliseconds |
| Widget behaviour | `flutter test` | Renders in a virtual environment |
| Flutter visual regression | **Alchemist** goldens | Playwright's equivalent, for Flutter |
| Flutter end-to-end | `integration_test` or **Patrol** | Real device; Patrol also drives native dialogs (camera permissions) |
| API contract | **Schemathesis** vs `openapi.yaml` | Generates cases from the spec |
| API behaviour | Vitest + Supertest | Handwritten happy/error paths |
| Public site + admin console | **Playwright** | These are real browsers |

"Design cross-referencing with Playwright" applies to `/site` and `/admin`. The Flutter
equivalent is Alchemist goldens plus, optionally, an AI vision loop (§5).

---

## 2. Flutter test pyramid

Target ratios, adapted from current Flutter practice:

| Layer | Share | Runs |
|---|---|---|
| Unit (engine, pure Dart) | 60–70% | Every PR, < 30s |
| Widget | 20–25% | Every PR, < 2min |
| Golden | 5–10% | Every PR, < 1min |
| Integration | ~5% | Nightly + on tag |

The engine is unusually testable here because it is pure and takes a seeded RNG, so
lean harder on unit tests than a typical app would.

### Property tests that matter

Beyond example-based tests, these invariants should hold across thousands of seeded
games. They are the real safety net for Interference Mode stacking:

- No player loses more than 2 lives in a round (except Sudden Death)
- Crew always get the real word; imposters never do
- Turn-order rotation distributes the last-speaker advantage evenly
- Every event × every round modifier resolves without throwing
- Identical seed → identical transcript
- **Topic draw converges to host weights** within ±2% over 10,000 rounds, and the
  no-repeat window is never violated (01-DESIGN.md §13b)
- **Tally weight never becomes damage** — a Double Vote or Megaphone player on a losing
  target loses exactly 1 life, never 2 (01-DESIGN.md §7)
- **Mayor tie rule** holds in all four cases: no tie, tie the Mayor voted in, tie the
  Mayor didn't vote in (wash), Mayor is one of the tied accused (wash)
- **Spread the Blame yields a resolvable plurality** at 3, 10, and 20 players
- **Near-Unanimous cannot be blocked by imposters alone** at any player count

---

## 3. Golden tests (Alchemist)

Alchemist is the current standard, having replaced the discontinued `golden_toolkit`.
It is maintained by Very Good Ventures and Betterment.

**Rules:**

- **Use CI mode for CI baselines.** Alchemist renders text as coloured blocks using
  the Ahem font in CI mode, which sidesteps the font-rendering differences that make
  goldens flaky across macOS/Linux/Windows. Platform goldens are for local use only.
- **Generate baselines in Docker.** Local generation plus CI validation is the classic
  false-failure source.
- **Component-level, not screen-level.** Golden the design-system primitives and the
  reveal-card states. Screens change too often and produce unreadable diffs.
- **The matrix is every primitive × every Vibe Pack.** This is the load-bearing test of
  the whole theming system (03-VIBE-SYSTEM.md): it proves themes are data rather than
  decoration, and it catches a hardcoded colour the moment one appears. Adding a seventh
  pack should extend the matrix automatically, with zero Dart changes.
- **Never golden anything nondeterministic** — timestamps, randomised layouts,
  mid-animation frames, network images. Stub them.
- **Tag goldens** (`--tags golden`) so they can be run and skipped independently. Use
  constants, not magic strings, and configure via `dart_test.yaml`.
- **Review every diff before updating.** Blindly running `--update-goldens` is how a
  real regression gets committed as a baseline.

Config lives in `app/test/flutter_test_config.dart`.

Reference: <https://pub.dev/packages/alchemist> ·
<https://engineering.verygood.ventures/development/testing/testing_golden_file/>

---

## 4. Playwright (site + admin only)

### Functional
Standard E2E: navigation, the feedback form, admin auth redirects, word-bank publish.

### Visual regression
`toHaveScreenshot()` ships in `@playwright/test` — no third-party service needed. It is
powered by pixelmatch and writes expected/actual/diff images into the HTML report on
failure.

**Configuration that actually matters:**

```ts
// playwright.config.ts
export default defineConfig({
  expect: {
    toHaveScreenshot: {
      maxDiffPixelRatio: 0.01,
      animations: 'disabled',
      scale: 'device',
    },
  },
  use: {
    viewport: { width: 1280, height: 720 },
    reducedMotion: 'reduce',
  },
  updateSnapshots: 'none', // CI: a missing baseline must fail loudly
});
```

**Practices, in rough order of how much pain they save:**

1. **Generate baselines in CI using the Playwright Docker image**, never on a laptop.
   Baselines are platform-locked; this is the number one source of CI failures.
2. **Mask everything dynamic** — timestamps, counters, avatars, live feeds — with the
   `mask` option.
3. **Disable animations** at capture. Belt and braces: also inject a stylesheet zeroing
   animation and transition durations.
4. **Per-component thresholds.** A hero image and a data table do not want the same
   tolerance.
5. **Commit baselines to git.** They are test artifacts and belong beside the code, so
   checking out an old commit gives you the baselines valid for it.
6. **Tag visual tests separately** and run them on PRs, not every push.
7. **Prefer component screenshots over full-page** — smaller files, faster diffs,
   more precise failures.
8. Wait for fonts to load before capturing.

Reference: <https://playwright.dev/docs/test-snapshots>

### Accessibility
`@axe-core/playwright` on every page. Zero critical or serious violations is the gate.
Consider `toMatchAriaSnapshot` for structural assertions that are less brittle than
pixels.

---

## 5. Agentic verification loop

Claude Code can verify its own UI work rather than guessing.

**For the web surfaces — Playwright MCP or CLI:**

```bash
claude mcp add playwright npx @playwright/mcp@latest
```

The agent drives a real browser through the accessibility tree — not screenshots — so
generated locators are semantic and stable. Note that **Microsoft now recommends the
Playwright CLI over MCP for coding agents**: a typical task costs roughly 114k tokens
via MCP versus 27k via CLI, because the CLI writes snapshots to disk instead of
streaming them into context. Claude Code has filesystem access, so prefer CLI + Skills;
keep MCP for exploratory loops that need persistent browser state.

Known failure modes, from teams running this at scale: it works well for first-pass
test authoring, selector refactors, debug loops, and generating API tests from an
OpenAPI spec. It breaks on long flows, dynamic data, deep conditionals, and OAuth.

**For Flutter — the throwaway-golden loop.** Very Good Ventures documented this
pattern: generate a temporary Alchemist test with `autoUpdateGoldenFiles = true`, run
it to produce a PNG, read that PNG with vision, compare against the design reference,
iterate until parity, then delete the throwaway test. It gives the agent eyes on its
own output. Keep permanent goldens separate from these disposable ones.

Reference: <https://github.com/microsoft/playwright-mcp> ·
<https://verygood.ventures/blog/figma-to-flutter-claude-code-skill-golden-tests/>

---

## 6. API contract testing

`openapi.yaml` is written **before** the implementation and is the source of truth.

**Schemathesis** reads the spec and generates property-based cases — valid and invalid
— hunting for crashes, schema violations, and spec drift. For a public API with unknown
consumers, provider-driven testing like this is the right model: anyone could depend on
any field, so validate the full declared contract.

```bash
schemathesis run api/openapi.yaml --checks all
```

Run it as its own CI job named `contract`, separate from unit and integration.

**Practices worth adopting up front:**

- **Document error shapes.** Forgetting error bodies is the most common way to violate
  a contract, and the easiest to prevent.
- Pin JSON Schema draft 2020-12 explicitly to avoid validator mismatches.
- Pick snake_case or camelCase once, globally. Casing arguments are pure test noise.
- Treat the contract as code: it lives in the repo, changes in PRs, versions with git.
- Use `deprecated: true` and a migration window rather than breaking silently.

Layer Vitest + Supertest on top for behaviour Schemathesis cannot infer — auth flows,
rate limiting, business rules.

Reference: <https://schemathesis.io/> ·
<https://qaskills.sh/blog/api-contract-testing-schemathesis-guide>

---

## 7. CI layout

```
dart      flutter analyze, flutter test, flutter test --tags golden   (every PR)
api       vitest, supertest                                            (every PR)
contract  schemathesis vs openapi.yaml                                 (every PR)
web       build site + admin, lint                                     (every PR)
e2e       playwright functional + axe                                  (every PR)
visual    playwright toHaveScreenshot, Docker image                    (PR, tagged)
flutter-e2e  integration_test on emulator                              (nightly + tag)
```

Target under 5 minutes for PR feedback. Shard the slow jobs.

---

## 8. Reference device — Vivo V60 Lite 5G

All performance audits (A5) run on this device. Named, physically available, and
representative of the actual target market — a mid-range Android common in PH.

| | |
|---|---|
| Chipset | MediaTek Dimensity 7360-Turbo (4nm) |
| CPU | 4× Cortex-A78 @2.5GHz + 4× Cortex-A55 @2.0GHz |
| GPU | **Mali-G615 MC2** — two cores |
| RAM | 8GB or 12GB **LPDDR4X** |
| Storage | 256GB UFS 3.1 |
| Display | 6.77" AMOLED, 1080×2392, **120Hz**, HDR10+ |
| OS | Android 15 / Funtouch 15 |
| Sensors | Gyroscope present — tilt-to-reveal is viable |

**Confirm which variant you have before profiling.** There is a V60 Lite 4G and a 5G, and
vivo's own marketing pages describe different chipsets across the family (a Snapdragon 6
series appears on one listing, Dimensity 7360-Turbo on the 5G). Check Settings → About
and record the exact chipset in the ADR. A budget written against the wrong SoC is worse
than no budget.

### 8a. Frame budget — 120Hz changes the number

The docs previously said "no frame over 16ms," which is a 60fps target. **This panel is
120Hz and Flutter renders at the display refresh rate by default**, so the real budget is:

| Target | Budget per frame |
|---|---|
| 120Hz (default on this device) | **8.3ms** |
| 60Hz (if capped) | 16.6ms |

Decide explicitly which you're targeting and record it. Two defensible positions:

- **Target 120Hz / 8.3ms.** Correct choice — a party game passed hand to hand is judged
  almost entirely on feel, and 120Hz is why this phone feels expensive. This is the
  ambitious target and the one the animation differentiator argues for.
- **Cap at 60Hz.** Legitimate fallback if the reveal blur can't hold 8.3ms. Halving the
  budget is a real escape hatch, but a capped party game on a 120Hz panel is noticeably
  less premium than the competition-beating polish Phase 5 is supposed to deliver.

Do not leave this implicit. An uncapped app that misses 8.3ms janks visibly; a capped one
that hits 16.6ms is smooth but less impressive.

### 8b. The specific risk: hold-to-reveal blur

**Mali-G615 MC2 is a two-core GPU**, and the core interaction of the entire game is a
blur clearing under a thumb press (01-DESIGN.md §6b). `BackdropFilter` and blurred
`ImageFiltered` are among the most expensive things you can do on a mobile GPU, they scale
with surface area, and this is a 6.77" 1080p screen with LPDDR4X memory bandwidth.

Prototype the reveal blur **in Phase 3, not Phase 5.** If it can't hold budget:

1. Pre-render the blur as a static image and cross-fade opacity instead of animating a
   live filter. Cheapest fix, visually near-identical.
2. Blur a smaller surface and scale it up — blur radius is perceptual, resolution isn't.
3. Replace blur with a Rive-driven mask or dissolve, which is what Rive is there for.
4. Cap to 60Hz.

Finding this in Phase 5 means reworking the animation you built the product around.
Finding it in Phase 3 means picking a different technique before anything depends on it.

### 8c. What to also check on this device

- **Thermals.** vivo positions this as a gaming phone with battery-saver and performance
  modes. Profile in the **default** mode, not performance mode — your players won't change
  it. Run 10 rounds and confirm frame times don't degrade as the phone warms.
- **Funtouch OS aggression.** vivo skins are known for aggressive background management.
  Verify the app survives a backgrounding, a call, and a notification without losing
  in-memory session state — **including the selfies**, which exist nowhere else (§4b).
  This is the most likely real bug on this specific device.
- **RAM variant.** If you have the 8GB model, profile on that, not the 12GB. Test the
  worse case.

---

## 9. What is not automatable

Two things carry more signal than the entire suite, and neither can be scripted:

- **Playtesting with real humans.** Whether accuser-pays flattens discussion, whether
  full Interference Mode is legible or just noise, whether a round drags at 12 players
  — none of it shows up in a test. Phase 4 and Phase 6 audits both gate on it.
- **Cultural review of the word bank.** No validator can tell you a clue only makes sense
  if you grew up in Metro Manila, or that a dish is named differently in the Visayas, or
  that a word will land badly at a family reunion. Filipinos who did not author the
  content must review all of it. Phase 2 gates on this (02-CONTENT-PH.md §6).
- **Clue tier calibration.** Whether a tight clue actually survives three crew clues is a
  question only a table can answer. Automated similarity checks catch tiers that are too
  *close*; they cannot tell you a tier is mistuned.
- **Reviewing visual diffs.** A golden or screenshot diff tells you something changed,
  never whether the change is correct. Never bulk-approve baseline updates.
