# ADR 0002 — Template adoption

**Status:** Accepted · **Date:** 2026-08-22

## Context

Building an audio stack, a theming layer, and an admin shell from scratch is weeks of work
that has been done well already. See `docs/07-TEMPLATES.md`.

## Decision

### `/app` — Flutter Casual Games Toolkit, `templates/basic`

Source: <https://github.com/flutter/games> · Upstream commit:
**`ae636d23deae83fd0e7fec9b862a7fcdf2bcfdd8`** ("Remove IDX/FS remnants from repository",
#152), adopted 2026-08-22.

**Kept:**
- `lib/audio/` — AudioController with music/SFX split and lifecycle handling. This is
  the foundation of the Vibe Pack system (`docs/03-VIBE-SYSTEM.md`)
- `lib/style/` — theming and transitions
- `lib/settings/`, `lib/app_lifecycle/`

> **Note on paths.** `docs/07-TEMPLATES.md` and earlier drafts of this ADR describe these
> as `lib/src/audio/` and `lib/src/style/`. Upstream has since flattened the tree: there is
> no `lib/src/`. They live at `lib/audio/` and `lib/style/`, as siblings of the
> `lib/engine/` and `lib/ui/` folders mandated by CLAUDE.md §Structure.

**Also kept, deliberately:** the demo screens (`main_menu`, `level_selection`,
`play_session`, `win_game`, `game_internals`, `player_progress`) and `test/smoke_test.dart`.
They are a working harness that keeps `flutter test` meaningful and proves the toolchain
end to end. Phase 4 replaces them with the real core loop. Removing them in Phase 0 would
have meant writing replacement screens, which is feature code this phase must not produce.

**Stripped in the first commit:**
- **Placeholder audio** — 3 Mr Smith tracks and 26 SFX files, plus their READMEs. The
  folders remain. `songs.dart` and `sounds.dart` keep their types with empty registries,
  and `AudioController` is guarded so an empty playlist or SFX list is a silent no-op
  rather than a `StateError` / `nextInt(0)` crash
- **A `googlemobileads` meta-data tag** (`FLUTTER_GAME_TEMPLATE_VERSION`) in
  `AndroidManifest.xml`
- **`achievementIdIOS` / `achievementIdAndroid` on `GameLevel`** — Play Games / Game Center
  hooks left behind by the achievements integration. DiAkoOi ships no achievements
- Template scaffolding: `codelab_rebuild.yaml`, the app-local `.gitignore` (the monorepo
  root already covers `app/`), and the template README

> **What was *not* stripped, because it was not there.** The Phase 0 brief and
> `docs/07-TEMPLATES.md` both call for removing AdMob, `in_app_purchase`,
> `games_services` and `crashlytics`. **None of them exist at this upstream revision** —
> `templates/basic/pubspec.yaml` depends only on `audioplayers`, `go_router`, `logging`,
> `provider` and `shared_preferences`, and AdMob now lives in a separate `samples/ads/`.
> The manifest tag and achievement fields above were the entire residue. This is recorded
> rather than glossed over so nobody later mistakes a verification for a removal. A CI step
> greps `app/` on every PR and fails if any such reference returns.

**Swapped:**
- `provider` → `flutter_riverpod` 3.4.2. `lib/providers.dart` replaces the `MultiProvider`
  tree; `AppLifecycleObserver` becomes a `Provider` that owns the `AppLifecycleListener`
  directly, so there is no observer widget to forget to mount. `PlayerProgress` and
  `LevelState` use `ChangeNotifierProvider` from `flutter_riverpod/legacy.dart` — they are
  template `ChangeNotifier`s that Phase 1 replaces with freezed models and `Notifier`s, so
  rewriting them now would be thrown away
- default lints → `very_good_analysis` 10.3.0. All 137 resulting findings were **fixed, not
  suppressed** — `unawaited(...)` on fire-and-forget persistence and audio calls, cascades,
  named `bool` parameters on the settings persistence interface, and assert messages

### `/site` — AstroWind + Starlight subpath

Source: <https://github.com/onwidget/astrowind> · Upstream commit
**`62e877519fd27f0c8aba73db18d59d334910fadc`**. AstroWind owns `/`; Starlight 0.41.7 owns
`/changelog`.

Two upstream behaviours worth recording:
- Starlight 0.41 **removed `routeBasePath`**. The URL now follows the content directory, so
  `src/content/docs/changelog/**` serves at `/changelog/**`.
- Starlight must be registered **before `mdx()`** — it pulls in `astro-expressive-code`,
  which enforces that ordering.

Removed from the template: **its own `CLAUDE.md`** — Claude Code loads `CLAUDE.md` by
filename, so a nested copy would silently override this repo's rules — plus `AGENTS.md`,
`Dockerfile`, `docker-compose.yml`, `netlify.toml`, `vercel.json`, `nginx/` and
`package-lock.json`, which are deployment config for AstroWind's own demo.

The landing page is still AstroWind's demo copy. Phase 8 replaces it
(`docs/09-WEB-SPEC.md`).

### `/admin` — Kiranism/next-shadcn-dashboard-starter

Source: <https://github.com/Kiranism/next-shadcn-dashboard-starter> · Upstream commit
**`5f42819faf6d797a768b1aa1a2cb8c579b77ab3b`**. Next 16.2.12, React 19.2.4, Tailwind 4,
oxlint.

Chosen because its tables actually search, filter, sort, and paginate, and its forms
validate and mutate with cache invalidation — most dashboard templates are static demo UI
that needs rebuilding the moment real data arrives.

**Stripped:** `@clerk/nextjs` and `@sentry/nextjs`, via the starter's own `cleanup` script.
Both require API keys to build, and per ADR 0001 the real access control for this console
is **Tailscale binding**, not an auth SaaS. The script missed four error boundaries under
`src/app/dashboard/overview/` that still imported `@sentry/nextjs` after the dependency was
removed; those were cleaned by hand.

Its React correctness lints (`set-state-in-effect`, `purity`, `refs`,
`incompatible-library`) are scoped to warnings for `src/components/ui/**`,
`src/components/modal/**`, `src/hooks/**` and `src/features/**` — where all 11 errors were,
all in vendored shadcn primitives and demo features. Our own code keeps the stricter
default. Phase 9 owns those files properly.

## Consequences

- Upstream changes can be diffed against a known starting commit.
- The audio lifecycle edge cases (call interrupts, backgrounding, headphone unplug) come
  solved rather than being discovered in Phase 5.
- shadcn components are copied into source, not installed — no lock-in, we own every file.
- Three templates carry demo content into the repo. Phases 4, 8 and 9 each delete their
  own share; until then the scaffolds are what make CI meaningful rather than vacuous.
