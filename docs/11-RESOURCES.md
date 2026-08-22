# Resources

Checked August 2026. Prefer these over searching — and verify `package.json` /
`pubspec.yaml` versions before adopting anything, since READMEs routinely claim currency
they don't have.

Templates get their own file: **07-TEMPLATES.md**. Music licensing: **03-VIBE-SYSTEM.md §1**.

---

## Claude Code

| Resource | Link |
|---|---|
| Official best practices | <https://code.claude.com/docs/en/best-practices> |
| Prompt engineering overview | <https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/overview> |
| Best-practices wiki, CLAUDE.md templates | <https://github.com/MuhammadUsmanGM/claude-code-best-practices> |
| Command → Agent → Skill orchestration | <https://github.com/shanraisshan/claude-code-best-practice> |

**Rules that matter most:**

- **Keep CLAUDE.md under ~200 lines.** Frontier models reliably follow roughly 150–200
  instructions and Claude Code's own system prompt already consumes ~50. Past a couple
  hundred lines you get context rot: adherence drops across *all* rules, not just later
  ones. This repo's CLAUDE.md is deliberately terse at ~120.
- **Put each rule on the right surface.** Must be enforced → hooks or permissions.
  Contextual knowledge → a skill. Delegation boundary → a subagent. Always-on project
  guidance → CLAUDE.md, briefly.
- **Be specific, not aspirational.** "Write clean code" is noise; "use Riverpod, see
  `lib/state/`" changes behaviour.
- **Plan mode before anything complex; subagents for research** so exploration doesn't eat
  the main context window.
- **Nested CLAUDE.md** works for large repos — specialist guidance next to the files it
  governs.
- AI-generated code skews toward *conceptual* bugs that pass type checks rather than
  syntax errors. Review accordingly; the audits are structured around this.

Per-phase prompts are pre-written in **08-PROMPTS.md**.

---

## Testing

| Resource | Link |
|---|---|
| Playwright visual comparisons | <https://playwright.dev/docs/test-snapshots> |
| Playwright MCP server | <https://github.com/microsoft/playwright-mcp> |
| Playwright + Claude Code, real failure modes | <https://qaby.ai/blog/claude-code-playwright-tests-guide> |
| Alchemist (Flutter goldens) | <https://pub.dev/packages/alchemist> |
| VGV golden-test practices | <https://engineering.verygood.ventures/development/testing/testing_golden_file/> |
| Golden-test common mistakes | <https://leancode.co/glossary/golden-tests-in-flutter> |
| Figma→Flutter with AI vision + golden loop | <https://verygood.ventures/blog/figma-to-flutter-claude-code-skill-golden-tests/> |
| Schemathesis | <https://schemathesis.io/> |
| Contract testing, provider vs consumer | <https://spec-coding.dev/blog/contract-testing-plan-from-openapi-to-ci> |

**MCP vs CLI:** Microsoft recommends the Playwright **CLI** over MCP for coding agents —
roughly 27k tokens per task versus 114k, because the CLI writes accessibility snapshots to
disk instead of streaming them into context. Claude Code has filesystem access, so default
to CLI + Skills; keep MCP for exploratory loops needing persistent browser state. Note
`browser_run_code` was renamed `browser_run_code_unsafe` in April 2026 — it is
RCE-equivalent, so opt in deliberately.

**Alchemist replaced `golden_toolkit`**, which is discontinued. Use CI mode (font-only,
text as coloured blocks) for CI baselines; platform goldens are OS-unstable.

---

## Flutter

| Resource | Link |
|---|---|
| Casual Games Toolkit (the base — see 07-TEMPLATES.md) | <https://docs.flutter.dev/resources/games-toolkit> |
| Animation & transition package index | <https://fluttergems.dev/animation-transition/> |
| Rive (state-machine driven) | <https://pub.dev/packages/rive> |
| Lottie for Flutter | <https://pub.dev/packages/lottie> |
| Testing strategy at scale | <https://medium.com/@m.m.shahmeh/flutter-testing-strategy-at-scale-af1aa236958e> |

**Rive vs Lottie here.** Lottie plays baked After Effects JSON — fine for fire-and-forget
micro-interactions. Rive has a **state machine**, so animations respond to runtime input.
The reveal card is state-driven (idle → holding → revealed → closing, × crew/imposter,
× Vibe Pack motion profile), which is exactly Rive's case.

**Split:** Rive for the reveal card and interference event cards · `flutter_animate` for
transitions and micro-interactions · Lottie only if a pre-made asset is worth using.

Do **not** reach for a package for the pass interstitial or handoff — those are `Hero` and
`AnimatedBuilder` work, and framework primitives stay interruptible.

---

## Backend & hosting

| Topic | Note |
|---|---|
| Cloudflare Tunnel | Public API only. No inbound router ports |
| Tailscale | Admin + Postgres. **Never Tailscale Funnel** — that publishes it |
| Cloudflare free-plan terms | Restrict disproportionate non-HTML content; move blobs to R2 |
| Cloudflare R2 | S3-compatible, free tier, no egress fees |
| Backups | `pg_dump` cron, encrypted, off-box, **with a tested restore** |

Content-addressed storage (filename = SHA-256 of bytes) gives dedup and integrity, not
security. Encryption at rest gives security. Use both for feedback attachments; neither
applies to selfies, which never reach the server at all.

---

## Competitive landscape

| App | Hook |
|---|---|
| Impostor Who? | 2000+ word packs, 3–20 players, pass-and-play |
| Impostor Party | 3-in-1 incl. Werewolf roles; **already ships a "Chaos Mode"** |
| Imposter Game – Party Edition | "Find the Liar", local + online |
| imposter.app | Browser-based, 6-digit codes, 20s clue timer |
| Imposter Up | Video-call companion |

**Three things to carry into every decision:**

1. **Nobody has Philippine content.** Every competitor ships generic global word lists.
   A Filipino table playing *Pagkain* or *Aktor at Aktres* in Taglish is not something
   any of them can answer quickly. This is the moat — 02-CONTENT-PH.md is the most valuable
   file in the repo.
2. **Almost none have native polish.** Several are literally browser wrappers. That gap is
   why Phase 5 exists as its own phase with a performance audit rather than being folded
   into UI work — and why Vibe Packs are worth the effort.
3. **The old name collision is gone.** "Imposter" sat on top of three named competitors;
   "DiAkoOi" doesn't. Still needs a trademark search before store submission, but it's now
   a formality rather than a real risk. Note Impostor Party's "Chaos Mode" is why ours is
   called **Interference Mode** — same word, different mechanic, same stores.

Serious competitors bundle multiple hidden-role formats (Werewolf with Seer, Cupid,
Hunter, Witch). DiAkoOi is deliberately single-mode for v1: the differentiation is
Philippine content plus polish, and a second mode dilutes both. Expect reviewers to name
it as a gap — that's a considered stance, not an oversight.

Already borrowed from the wider genre: the **mayor with a tie-breaking vote** (01-DESIGN.md
§7a) and the **fool who wins by being eliminated** (§9b/§9c).
