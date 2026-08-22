# ADR 0002 — Template adoption

**Status:** Accepted · **Date:** 2026-08-22

## Context

Building an audio stack, a theming layer, and an admin shell from scratch is weeks of work
that has been done well already. See `docs/07-TEMPLATES.md`.

## Decision

### `/app` — Flutter Casual Games Toolkit, `templates/basic`

Source: <https://github.com/flutter/games> · Upstream commit: `<RECORD AT ADOPTION>`

**Kept:**
- `lib/src/audio/` — AudioController with music/SFX split and lifecycle handling. This is
  the foundation of the Vibe Pack system (`docs/03-VIBE-SYSTEM.md`)
- `lib/src/style/` — theming and transitions
- `lib/src/settings/`, `lib/src/app_lifecycle/`

**Stripped in the first commit:**
- `google_mobile_ads` — ads in a phone passed hand to hand is a terrible experience and
  complicates the Play Data Safety declaration
- `in_app_purchase`, `games_services`, `crashlytics`
- Bundled placeholder music and SFX (legitimately CC-licensed, but replaced)

**Swapped:**
- `provider` → `flutter_riverpod`
- default lints → `very_good_analysis`

### `/site` — AstroWind + Starlight subpath
### `/admin` — Kiranism/next-shadcn-dashboard-starter

Chosen because its tables actually search, filter, sort, and paginate, and its forms
validate and mutate with cache invalidation — most dashboard templates are static demo UI
that needs rebuilding the moment real data arrives.

## Consequences

- Upstream changes can be diffed against a known starting commit.
- The audio lifecycle edge cases (call interrupts, backgrounding, headphone unplug) come
  solved rather than being discovered in Phase 5.
- shadcn components are copied into source, not installed — no lock-in, we own every file.

## Note

**Record the exact upstream commit hash above at adoption time.** Six months from now,
"why is this structured like this" needs an answer.
