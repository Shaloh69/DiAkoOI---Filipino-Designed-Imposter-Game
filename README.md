<div align="center">

# DiAkoOi

**"Di ako, 'oi!"** — *Not me!*

A pass-and-play social deduction party game built for Filipino tables.

[![License: MIT](https://img.shields.io/badge/Code-MIT-blue.svg)](LICENSE)
[![Content: CC BY-NC-SA 4.0](https://img.shields.io/badge/Content-CC%20BY--NC--SA%204.0-lightgrey.svg)](LICENSE-CONTENT)
[![Platform: Android](https://img.shields.io/badge/Platform-Android-3DDC84.svg)]()
[![Status: Pre-alpha](https://img.shields.io/badge/Status-Pre--alpha-orange.svg)]()

</div>

---

## What it is

One phone goes around the group. Everyone sees a secret word — except the Imposter(s), who
get a deliberately vague clue instead. Players take turns describing the word aloud in
Taglish, trying to blend in. Then everyone accuses someone.

Get it right, the Imposter loses lives. Get it wrong, **only the people who accused wrongly
pay for it.** Hit zero lives and you take a forfeit of your own choosing, then come back
with one life and a grudge.

3–20 players. One device. No internet required, ever.

## Why it's different

| | |
|---|---|
| 🇵🇭 **Philippine-only content** | Every topic and clue authored for a Filipino table — aktor at aktres, K-Pop, pagkain, OPM, teleserye, PBA. Not a translated global word list |
| 🎲 **Weighted random topics** | Set a mix by percentage (20% Aktor / 60% K-Pop / 20% Pagkain) and the app rolls each round. Nobody picks, so nobody games it |
| 🕵️ **A real clue, not a blank card** | Imposters get an authored clue at one of three difficulty tiers — enough to bluff with, never enough to be safe |
| ⚖️ **Accuser-pays voting** | A bad accusation costs *you*, not the whole crew. Reading people well is finally worth something |
| 🎵 **Vibe Packs** | A licensed instrumental is drawn each session and drives the entire visual theme — palette, type, motion. Same game, different mood every time |
| 📸 **Selfie identity** | Your own face becomes your suspect ID across the whole UI. Never leaves the device |
| ⚡ **Interference Mode** | Optional chaos layer — 15 player events, 22 round modifiers, 10 items, every one individually toggleable |

## Status

**Pre-alpha. Nothing is built yet.** This repository currently contains the complete design
specification and implementation plan. Development starts at Phase 0.

Track progress in [`docs/05-IMPLEMENTATION-PLAN.md`](docs/05-IMPLEMENTATION-PLAN.md).

---

## Repository structure

```
DiAkoOi/
├── app/                    Flutter mobile app — the game itself
│   ├── lib/engine/           pure Dart game logic, NO Flutter imports
│   ├── lib/ui/               widgets, screens, animations
│   ├── assets/vibes/         Vibe Packs: track.ogg + theme.json + licence.json
│   ├── assets/wordbank/      bundled word bank (offline fallback)
│   ├── test/engine/          unit tests
│   ├── test/ui/              widget tests
│   ├── test/golden/          Alchemist visual regression
│   ├── test/privacy/         disk-write assertions — DO NOT WEAKEN
│   └── integration_test/     end-to-end on device
├── site/                   Astro — public site, changelog, privacy, credits
├── admin/                  Next.js + shadcn/ui — feedback triage, word banks
├── api/                    Node + Fastify + Postgres
│   └── openapi.yaml          the contract, written before implementation
├── e2e/                    Playwright — /site and /admin ONLY
├── content/                word bank CSVs, one per topic
│   └── STYLE.md              clue authoring house style
├── scripts/                CSV validator, word bank bundler
├── docs/                   numbered specs 00–11, in reading order
│   ├── adr/                  architecture decision records
│   └── licences/             licence screenshots for bundled audio
├── CLAUDE.md               agent instructions — MUST keep this exact filename
└── docker-compose.yml      postgres + api + cloudflared
```

## Documentation

Read in order. Start with `00`.

| # | Doc | What it covers |
|---|---|---|
| — | [`CLAUDE.md`](CLAUDE.md) | Conventions, commands, hard rules |
| 00 | [`START-HERE`](docs/00-START-HERE.md) | Orientation, gotchas, decision status |
| 01 | [`DESIGN`](docs/01-DESIGN.md) | **Source of truth for every game rule** |
| 02 | [`CONTENT-PH`](docs/02-CONTENT-PH.md) | Topics, word bank spec, authoring workflow |
| 03 | [`VIBE-SYSTEM`](docs/03-VIBE-SYSTEM.md) | Music-driven theming |
| 04 | [`MUSIC-SOURCING`](docs/04-MUSIC-SOURCING.md) | Free-track hunt list and licensing workflow |
| 05 | [`IMPLEMENTATION-PLAN`](docs/05-IMPLEMENTATION-PLAN.md) | 11 phases with gated audits |
| 06 | [`TESTING-STRATEGY`](docs/06-TESTING-STRATEGY.md) | Tool split, device profile |
| 07 | [`TEMPLATES`](docs/07-TEMPLATES.md) | Vetted starting points |
| 08 | [`PROMPTS`](docs/08-PROMPTS.md) | Claude Code prompts per phase |
| 09 | [`WEB-SPEC`](docs/09-WEB-SPEC.md) | Page-by-page site and console spec |
| 10 | [`TRADEMARK-SEARCH`](docs/10-TRADEMARK-SEARCH.md) | IPOPHL search protocol |
| 11 | [`RESOURCES`](docs/11-RESOURCES.md) | Links and competitive landscape |

---

## Getting started

**Prerequisites:** Flutter SDK, Node 20+, pnpm, Docker.

```bash
git clone https://github.com/Shaloh69/DiAkoOI---Filipino-Designed-Imposter-Game.git
cd DiAkoOI---Filipino-Designed-Imposter-Game

# The game
cd app && flutter pub get && flutter test

# Web surfaces
cd site  && pnpm install && pnpm dev
cd admin && pnpm install && pnpm dev
cd api   && pnpm install && pnpm dev

# Backend stack
docker compose up -d
```

Full command reference: [`CLAUDE.md`](CLAUDE.md).

## Three rules that never bend

**1. Selfies never touch disk or network.** In-memory bytes only, discarded on new roster.
`image_picker` and `camera.takePicture()` both write temp files by default and will
silently break this. `app/test/privacy/` proves it. Never weaken that test.

**2. All music must be licensed, with the licence recorded.** Every pack in `assets/vibes/`
ships a `licence.json`. No record, no ship. A credit watermark is not a licence.

**3. `docs/01-DESIGN.md` is the source of truth for game rules.** Several look wrong until
you read the rationale. Propose changes; don't apply them.

---

## Licensing

This repository is **dual-licensed**, because the code and the content have different
purposes.

| What | Licence | Meaning |
|---|---|---|
| **Source code** — everything in `app/`, `site/`, `admin/`, `api/`, `e2e/`, `scripts/` | [MIT](LICENSE) | Use it, fork it, ship it commercially. Attribution appreciated |
| **Game content** — `content/`, `app/assets/wordbank/`, and the design docs in `docs/` | [CC BY-NC-SA 4.0](LICENSE-CONTENT) | Share and adapt with credit, **non-commercially**, under the same terms |
| **Bundled audio** — `app/assets/vibes/*/track.ogg` | Third-party, see each `licence.json` | Not ours to relicense. Each track carries its own terms |
| **Name and logo** — "DiAkoOi" and associated marks | Not licensed | Fork the code, but don't ship it under this name |

**Why the split.** The engine is just software and there's no reason to hoard it. The word
bank is roughly 2,160 hand-authored Taglish clues written and culturally reviewed by
Filipinos — that's the part that took the real work, and the non-commercial clause exists
so it can't simply be lifted into someone else's paid app. Use it in your own free project,
credit us, share alike.

---

## Contributing

Contributions welcome, especially **word bank content and regional corrections**. A clue
that doesn't land in Cebu, Davao, or Iloilo is a bug worth reporting.

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Content contributions must follow
[`content/STYLE.md`](content/STYLE.md) and pass the validator.

## Credits

Built by **Team Lanzones** in Cebu, Philippines.

Music credits for every Vibe Pack are listed in-app and on the public site's credits page,
generated from the `licence.json` files in the build.

<div align="center">
<sub>Gawa sa Pilipinas 🇵🇭</sub>
</div>
