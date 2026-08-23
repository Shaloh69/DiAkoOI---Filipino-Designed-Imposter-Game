# Proposal 0003 — Remove telemetry from `01-DESIGN.md` §16

**Status:** Proposed · **Date:** 2026-08-24 · **Decision already taken:** ADR 0015

## Why this is a proposal and not an edit

The telemetry decision itself is made — the product owner chose **none in v1**, and ADR 0015
records it. Every consequence has been applied to the plan, the web spec, the API and the
schema.

`01-DESIGN.md` is the exception. It is the source of truth for the design and the standing
rule is propose, never patch (`CLAUDE.md` §Off-limits). So this is the change, written out,
for you to apply or reject.

## The change

**§16 preamble.** Currently:

> The backend exists for feedback, word-bank delivery, and coarse telemetry, all of which
> degrade to bundled or cached fallbacks.

Proposed:

> The backend exists for feedback and word-bank delivery, both of which degrade to bundled
> or cached fallbacks. **v1 collects no telemetry** — see `docs/adr/0015-no-telemetry-in-v1.md`.

**§16a table.** Remove the row:

> | Telemetry | Server, aggregate only | Session counts, player-count buckets, topic weights, toggle rates. No names, photos, or device IDs |

Replace it with:

> | Telemetry | **Not collected in v1** | No endpoint, no table, no local counters. ADR 0015 |

**§16d.** Keep the third bullet but change its tense, because the reasoning is exactly why
the decision went the way it did and deleting it would lose that:

> - **Telemetry has a store consequence:** even anonymous counters must be declared in the
>   App Store privacy label and covered by a policy URL at submission. Aggregate-only keeps
>   the label clean.

Proposed:

> - **Telemetry has a store consequence**, and it is why v1 has none: even anonymous
>   counters must be declared in the App Store privacy label and covered by a policy URL at
>   submission. v1 declares "no data collected", which is both true and the simplest thing to
>   submit. Adding collection in v1.1 is a policy update; un-declaring it is not graceful.

## What is deliberately not proposed

**§16c topology stays as written.** It describes Cloudflare Tunnel, Tailscale, Docker
Compose and backups, none of which depended on telemetry.

**§16b stays as written.** Hashing versus encryption is about feedback attachments and is
unaffected — and it is implemented as described.

## If you reject this

Then §16 keeps describing a telemetry pipeline that does not exist, and the next reader has
to work out which of the two sources is current. That is the only real cost; nothing in the
code changes either way, because the code already reflects ADR 0015.
