# ADR 0015 — No telemetry in v1

**Status:** Accepted · **Date:** 2026-08-24 · **Decided by:** product owner

## Context

`01-DESIGN.md` §16a listed telemetry as one of four things the backend exists for —
aggregate only: session counts, player-count buckets, topic weights, toggle rates, with no
names, photos or device identifiers. `05-IMPLEMENTATION-PLAN.md` Phase 7 carried a
`POST /v1/telemetry` endpoint, and `09-WEB-SPEC.md` §B1 and §B4 described an admin dashboard
built on it.

The decision was tracked as an open gate in `BLOCKED.md` from Phase 0, because it is not a
technical question. §16d states the consequence plainly: **even anonymous counters must be
declared in the App Store privacy label and covered by a policy URL at submission.**

## Decision

**v1 collects nothing. The endpoint is omitted from the spec entirely rather than stubbed.**

Three reasons, in the order they matter:

**A documented endpoint that returns 501 is a contract to maintain for nothing.** It appears
in generated clients, has to be covered by contract tests, needs its error shapes documented,
and invites someone to "finish" it later without revisiting the decision. Absent is cheaper
and clearer than present-but-disabled.

**At beta scale a single playtest outvalues a thousand aggregate counters.** The open
questions this project actually has — is full-chaos Interference legible or noise (§12), does
accuser-pays flatten discussion (§12.3), is two-tap voting fast enough at 10+ (§12.4) — are
all questions about *why*, and counters answer *what*. With roughly twenty beta users the
sample is too small to answer either, and a real table answers all three in one evening.

**Adding collection in v1.1 is a policy update; un-declaring it is not graceful.** A privacy
label that grows is routine. One that shrinks invites the question of what was being
collected and why it stopped, and answering that publicly is a worse position than never
having started.

## Consequences

**Good.**

- The Play Data Safety declaration is "no data collected", which is both true and the
  simplest thing to submit.
- No privacy policy URL is required for v1 submission.
- One fewer public endpoint on a residential host — a smaller surface to rate-limit, secure
  and keep up.
- The admin console loses its telemetry dashboard, which was the only part of it that needed
  data the app does not otherwise send.

**Costs.**

- **No aggregate visibility at all.** Nobody knows how many games are played, what player
  counts are typical, or which Vibe Packs get pinned. That is a real loss, accepted
  knowingly rather than overlooked.
- Feedback becomes the only signal, so the feedback path matters more than it otherwise
  would — which is part of why it has an offline queue rather than a fire-and-forget POST.
- If v1.1 wants telemetry, it needs the endpoint, the schema, the policy URL and a store
  declaration update together. None of that is hard; it is simply not free.

## What changed

| File | Change |
|---|---|
| `api/openapi.yaml` | `POST /v1/telemetry` never added; the absence is documented in `info.description` so a reader does not assume an oversight |
| `api/src/migrations/001_initial.sql` | No telemetry table, stated in the header comment |
| `docs/05-IMPLEMENTATION-PLAN.md` | Removed from the Phase 7 task list and the A7 audit |
| `docs/09-WEB-SPEC.md` §B1, §B4 | Telemetry dashboard removed |
| `docs/01-DESIGN.md` §16a | **Proposed, not patched** — see `docs/proposals/0003-remove-telemetry.md`. §16 is design, and design is proposed rather than edited |
| `BLOCKED.md` | Gate closed |

## Alternatives rejected

**Ship the endpoint, disabled behind a flag.** All of the maintenance cost, none of the data,
and a flag someone flips without revisiting the store declaration.

**Collect locally, upload never.** A counter nobody reads is a counter nobody should write,
and it still has to be declared if it exists on disk in a form that could be uploaded.

**Anonymous counters only, no declaration.** Not an option. §16d is explicit that anonymity
does not exempt a collector from the label.
