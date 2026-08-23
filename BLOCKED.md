# BLOCKED — human gates and handoff

Audit items that cannot be satisfied by code, and the state of the run.

**A phase with an outstanding human gate is never "done".** Where later work does not
depend on the gate, building continues past it and the dependency is noted; where it does,
the run stops.

---

## Handoff — start a fresh session here

**Last completed:** Phase 1 (engine). **Next:** Phase 2 (content pipeline).

Open pull requests, stacked — `main` is still at the initial specification commit, so each
branch is based on the one before it and GitHub retargets as they merge:

| PR | Branch | Base | State |
|---|---|---|---|
| [#1](https://github.com/Shaloh69/DiAkoOI---Filipino-Designed-Imposter-Game/pull/1) | `phase/00-foundation` | `main` | CI green |
| [#2](https://github.com/Shaloh69/DiAkoOI---Filipino-Designed-Imposter-Game/pull/2) | `chore/step-0-housekeeping` | `phase/00-foundation` | CI green |
| [#3](https://github.com/Shaloh69/DiAkoOI---Filipino-Designed-Imposter-Game/pull/3) | `phase/01-engine` | `chore/step-0-housekeeping` | see PR |

Phase 2 should branch from `phase/01-engine`.

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
- Two version pins are cross-referenced and must change together: Flutter
  (`docker/goldens.Dockerfile` ↔ `ci.yml`) and Playwright (`e2e/package.json` ↔ the CI
  container image). Both drifted once and broke CI.

---

## Outstanding human gates

### Currently blocking nothing, but blocking later phases

| # | Needed | From | Blocks |
|---|---|---|---|
| 1 | **Frame target: 120Hz/8.3ms vs capped 60Hz/16.6ms.** Implement as a single config value, never scattered assumptions. Defaulting to 120Hz/8.3ms and flagged provisional | Product owner | **A5** (Phase 5) |
| 2 | **Trademark search on "DiAkoOi"** — protocol ready in `docs/10-TRADEMARK-SEARCH.md`, ~40 minutes | Human | **Phase 8** |
| 3 | **Telemetry at launch, yes or no.** Any collection needs a privacy policy URL and a Play Data Safety declaration; shipping with zero telemetry is defensible and simpler | Product owner | **Phase 7** |
| 4 | **Confirm the Vivo V60 Lite 5G variant/chipset** in Settings → About. The spec table is from published figures, not the physical handset | Whoever holds the device | A5 precision |

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

### Phase 2 — Content · will be **AUDIT-INCOMPLETE**

A2 cannot go green in this run. Build all tooling — CSV validator, JSON bundler, one CSV
per topic, tests for the validator itself — and generate **candidate drafts into
`content/drafts/`, not `content/`**. Ship a clearly-labelled ~20-word placeholder bundle so
Phase 4 has something to run.

A2 stays open until humans ratify `content/STYLE.md` at v1 and finish cultural review.
