# BLOCKED — human gates and handoff

Audit items that cannot be satisfied by code, and the state of the run.

**A phase with an outstanding human gate is never "done".** Where later work does not
depend on the gate, building continues past it and the dependency is noted; where it does,
the run stops.

---

## Handoff — start a fresh session here

**Last completed:** Phase 2 (content pipeline — A2 AUDIT-INCOMPLETE by design).
**Next:** Phase 3 (Vibe Packs & design system).

Open pull requests, stacked — `main` is still at the initial specification commit, so each
branch is based on the one before it and GitHub retargets as they merge:

| PR | Branch | Base | State |
|---|---|---|---|
| [#1](https://github.com/Shaloh69/DiAkoOI---Filipino-Designed-Imposter-Game/pull/1) | `phase/00-foundation` | `main` | CI green |
| [#2](https://github.com/Shaloh69/DiAkoOI---Filipino-Designed-Imposter-Game/pull/2) | `chore/step-0-housekeeping` | `phase/00-foundation` | CI green |
| [#3](https://github.com/Shaloh69/DiAkoOI---Filipino-Designed-Imposter-Game/pull/3) | `phase/01-engine` | `chore/step-0-housekeeping` | CI green |
| [#4](https://github.com/Shaloh69/DiAkoOI---Filipino-Designed-Imposter-Game/pull/4) | `phase/02-content` | `phase/01-engine` | CI green |

Phase 3 should branch from `phase/02-content`.

**The stack is four deep.** Merging the green ones would flatten it.

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

### Phase 3 — Vibe Packs · will be **AUDIT-INCOMPLETE**

Build the full theming system with PLACEHOLDER audio (silent ogg stubs, `licence.json`
marked PLACEHOLDER). Loader, ThemeExtension, motion profiles, primitives, golden matrix and
contrast checks are all autonomous. Do the hold-to-reveal blur spike here — Mali-G615 MC2 is
a two-core GPU and this is the core interaction; report findings and do not guess at numbers
that need hardware to measure. A3 stays open on real licensed tracks.
