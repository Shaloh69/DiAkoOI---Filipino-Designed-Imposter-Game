# Templates & Starting Points

Real, checked, currently-maintained starting points for all three surfaces. Checked
August 2026.

**Rule before adopting anything here: read `package.json` / `pubspec.yaml`, not the
README.** Templates routinely claim to be current while depending on a framework version
behind. The manifest is the source of truth.

---

## 1. Mobile app — Flutter

### Primary: Flutter Casual Games Toolkit, `basic` template

**<https://github.com/flutter/games>** → `templates/basic`
Docs: <https://docs.flutter.dev/resources/games-toolkit> · <https://flutter.dev/games>

This is the right base and it is not a close call. Google maintains it, and it already
ships the exact subsystems this project needs:

```
lib/
  audio/            ← AudioController: music/SFX split, lifecycle handling
  style/            ← theming, palette, transitions
  settings/         ← persisted settings incl. mute
  main_menu/
  play_session/
  app_lifecycle/    ← pause audio on background (you WILL need this)
  game_internals/
```

> **Corrected at adoption (2026-08-22).** Earlier revisions of this file showed these under
> `lib/src/`. Upstream has flattened that away — there is no `lib/src/` at commit
> `ae636d23`. In DiAkoOi they sit at `app/lib/audio/` and `app/lib/style/`, as siblings of
> the `lib/engine/` and `lib/ui/` folders CLAUDE.md §Structure mandates.

**Why it matters for DiAkoOi specifically:** the Vibe Pack system is an audio controller
plus a swappable theme, and both already exist here in working form. Building an audio
stack from scratch to then discover the lifecycle edge cases (call interrupts, background,
headphone unplug) is a week you don't need to spend.

It uses `audioplayers` for sound and `provider` for state. **Swap `provider` for Riverpod**
to match the rest of the project.

> **Corrected at adoption (2026-08-22): verify absent, then remove the residue.**
>
> Earlier revisions of this file — and the Phase 0 prompt in `08-PROMPTS.md` §2 — said to
> strip AdMob, `in_app_purchase`, `games_services` and `crashlytics` "entirely", describing
> a template that "assumes you want to monetise". **None of those four packages exist at
> upstream `ae636d23`.** `templates/basic/pubspec.yaml` depends only on `audioplayers`,
> `go_router`, `logging`, `provider` and `shared_preferences`; AdMob now lives in a separate
> `samples/ads/`. Following the old wording means hunting for dependencies that were never
> there and concluding, wrongly, that removal work was done.
>
> What actually remained were two pieces of **residue** left behind after upstream removed
> the packages, both stripped in the adoption commit:
>
> 1. a `googlemobileads` meta-data tag —
>    `io.flutter.plugins.googlemobileads.FLUTTER_GAME_TEMPLATE_VERSION` — in
>    `android/app/src/main/AndroidManifest.xml`
> 2. `achievementIdIOS` / `achievementIdAndroid` fields on `GameLevel` in
>    `lib/level_selection/levels.dart`, hooks for a store achievements service
>
> So the instruction is: **confirm each package is absent, then grep for residue.** CI runs
> that grep over `app/` on every PR and fails if any such reference returns. Record the
> outcome as a verification, not as a removal — see `docs/adr/0002-templates.md`.

Get it:
```bash
git clone --filter=blob:none https://github.com/flutter/games.git
cd games/templates/basic
```

The bundled music is CC-BY (credited to Mr Smith) and the SFX are CC0. **Replace both** —
but note the bundled tracks are legitimately licensed, so they are usable as placeholders
during development if credited.

### Reference only: Best-Flutter-UI-Templates

**<https://github.com/mitesh77/Best-Flutter-UI-Templates>**

Do **not** fork this as a base — it's a screen collection, not an architecture. Useful to
read for animation and layout technique when building the reveal card and voting grid.
Look, borrow the idea, write your own.

### Architecture reference

**<https://github.com/momshaddinury/flutter_template>** — production-ready Flutter with
Riverpod, feature-first folders, clean architecture. Read its structure for how to
organise `lib/`, then apply that shape inside the games-toolkit base.

### Packages

| Need | Package |
|---|---|
| Audio | `audioplayers` (already in the template) |
| State | `riverpod` / `flutter_riverpod` |
| Models | `freezed` + `json_serializable` |
| Camera (in-memory capture) | `camera` — use `startImageStream()`, see 01-DESIGN.md §4b |
| Motion (transitions, micro-interactions) | `flutter_animate` |
| Reveal card state machine | **Rive** (`rive`) — has a real state machine, unlike Lottie's baked playback. The card is idle → holding → revealed → closing with crew/imposter variants, which is exactly Rive's case |
| Golden tests | `alchemist` |
| Lints | `very_good_analysis` |

Do **not** use a package for the pass interstitial or handoff. Those are `Hero` and
`AnimatedBuilder` work, and staying in framework primitives keeps them interruptible.

---

## 2. Public site — Astro

### Primary: AstroWind

**<https://github.com/onwidget/astrowind>**

Astro + Tailwind, actively maintained, built for exactly this — a marketing landing page
with app download CTAs. Good Lighthouse scores out of the box, dark mode included.

### Alternative: astro-landing-page (shadcn port)

**<https://github.com/swiing/astro-landing-page>** — Astro v5 + TypeScript + Tailwind v4,
a port of shadcn-landing-page. Pick this if you want the visual language to match the
admin console (also shadcn), which is a real advantage for a solo maintainer.

### Changelog: Starlight

**<https://starlight.astro.build>**

Add as a subpath (`/docs`, `/changelog`) rather than as the whole site. Starlight is
excellent for structured content — sidebar, search via Pagefind, zero JS by default,
typically under 50KB per page — and poor as a landing page. Use both: AstroWind for `/`,
Starlight for changelog and how-to-play.

`astro-og-canvas` handles per-page OG images, which Starlight doesn't do natively.

Browse more: <https://astro.build/themes/> · <https://htmlrev.com/free-astro-templates.html>

---

## 3. Admin console — Next.js

### Primary: next-shadcn-dashboard-starter

**<https://github.com/Kiranism/next-shadcn-dashboard-starter>** (~5.9k stars, weekly
commits)

The distinction that matters: most dashboard templates are static demo boilerplate —
screens that look finished but need rebuilding the moment real data arrives. This one's
tables actually search, filter, sort, and paginate, and its forms validate and mutate with
cache invalidation. It also ships a cleanup script for stripping unused features.

### Alternative: next-shadcn-admin-dashboard

**<https://github.com/arhamkhnz/next-shadcn-admin-dashboard>** — theme presets and RBAC
built in. Overkill for a single-admin console, but the theme preset system is worth reading
since the Vibe Pack theming problem is structurally similar.

shadcn/ui components are copied into your source rather than installed as a dependency, so
there's no lock-in and you own every file.

---

## 4. Music sources

Full licensing rules in **03-VIBE-SYSTEM.md §1** — read that before downloading anything.

| Source | Licence | Link |
|---|---|---|
| Kenney | CC0, no attribution | <https://kenney.nl/assets> |
| Pixabay Music | Pixabay Content Licence | <https://pixabay.com/music/> |
| Free Music Archive | Per-track CC | <https://freemusicarchive.org/> |
| Incompetech | CC-BY | <https://incompetech.com/music/> |
| WOW Sound | Revenue-tiered, Content-ID free | <https://wowsound.com/royalty-free-music-for-mobile-games/> |
| Mixkit | Free stock music | <https://mixkit.co/free-stock-music/> |
| Epidemic Sound | Subscription | <https://www.epidemicsound.com/> |

---

## 5. What NOT to start from

| Tempting | Why not |
|---|---|
| A generic "Flutter starter" with 40 screens | You'd delete 38. The games toolkit gives you the 4 subsystems you actually need |
| Flame game engine | Flame is for game loops, sprites, collision. DiAkoOi is an app-like turn-based game — Flame adds a rendering layer you'd fight |
| A Firebase-backed template | v1 is offline-first with a self-hosted API. Firebase would invert the architecture |
| Any template with AdMob wired in | Strip it. Ads in a party game passed hand to hand is an awful experience, and it complicates the privacy label |
| Paid theme bundles | You'd pay for 40 templates to use one. All three primaries above are free and MIT/BSD |

---

## 6. Adoption checklist

Per template, before committing:

```
[ ] Read package.json / pubspec.yaml — actual versions, not README claims
[ ] Check last commit date and open issue count
[ ] Confirm licence permits commercial use (MIT/BSD/Apache fine; check anything else)
[ ] Run it clean before changing a single line
[ ] Strip everything unused in the FIRST commit, not later
[ ] Record the adoption as an ADR: what, which commit, what was stripped, why
```

That last one matters more than it looks. Six months on, "why is this folder structured
like this" has an answer, and a template's upstream changes can be diffed against a known
starting commit.
