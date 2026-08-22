# ADR 0001 — Technology stack

**Status:** Accepted · **Date:** 2026-08-22

## Context

DiAkoOi is a pass-and-play Android party game with three secondary web surfaces. The game
must run fully offline; the web surfaces are the release vehicle while there is no store
presence.

## Decision

| Surface | Choice |
|---|---|
| Mobile app | **Flutter**, Android only for v1. Riverpod, freezed, very_good_analysis |
| Base template | **flutter/games `templates/basic`** (Casual Games Toolkit) — see ADR 0002 |
| Public site | **Astro** — AstroWind landing + Starlight subpath for changelog |
| Admin console | **Next.js + shadcn/ui**, Tailscale-bound |
| API | **Node + Fastify + Postgres**, self-hosted, Docker Compose |
| Application id | `ph.teamlanzones.diakooi` |

## Rationale

**Flutter over React Native.** Stronger animation primitives, and the Casual Games Toolkit
gives a working audio controller and theming layer for free — both are load-bearing for
the Vibe Pack system.

**Android only.** Target market is the Philippines, where Android dominates. iOS doubles
store, signing, and privacy-label work for a v1 that has not proven itself. The `ios/`
folder stays buildable but gets no time.

**Fastify + Postgres over Supabase or Firebase.** The game is offline-first; a BaaS would
invert that architecture and pull the app toward requiring a network it must never need.
Self-hosting also keeps selfies architecturally impossible to upload.

**Astro over Next.js for the public site.** Zero JS by default, ~50KB pages. The site is
content, not an application.

## Consequences

- No iOS users at launch. Accepted.
- Self-hosting means uptime equals ISP uptime — acceptable because nothing the game needs
  is served from it.
- Two JS frameworks in one repo (Astro, Next). Accepted; they serve genuinely different
  purposes and share nothing.
