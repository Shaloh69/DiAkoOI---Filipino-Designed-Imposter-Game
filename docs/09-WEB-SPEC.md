# Web Surfaces Specification

Two deployments with deliberately different security postures.

| | Public site | Admin console |
|---|---|---|
| Stack | Astro (AstroWind + Starlight subpath) | Next.js + shadcn/ui |
| Hosting | Cloudflare Pages (static) | Home server, Tailscale-only |
| Reachable from internet | Yes | **No** |
| Audience | Players, press | You |

The site is static and hosted away from the home server so ISP downtime never takes down
the shopfront. The console is never published — not password-protected on the open
internet, but genuinely unreachable off the tailnet.

Templates and adoption notes: **07-TEMPLATES.md**.

---

## Part A — Public Site

**Why this split:** AstroWind for the landing page (built for app marketing, good
Lighthouse out of the box), Starlight on a subpath for changelog and how-to-play (sidebar,
Pagefind search, zero JS, ~50KB pages). Starlight is excellent for structured content and
poor as a landing page; using both plays to each.

### A1. Landing — `/`

Not on any store yet, so this page carries the entire pitch and the download.

```
[ ] Hero: DiAkoOi, one-line pitch, primary CTA (download / join beta)
[ ] The name explained — "Di ako, 'oi!" = "Not me!" It IS the pitch, use it
[ ] The hook in one sentence: imposters get a vague clue, not nothing
[ ] Differentiators with visuals:
      · Philippine-only content — aktor, K-Pop, pagkain, OPM, teleserye
      · vague clue instead of a blank card
      · accuser-pays voting — bad accusations cost the accuser
      · Vibe Packs — the game looks different every session
      · selfie-based suspect identity
[ ] Gameplay clip or animated stills. This is an animation-led product; static
    screenshots undersell it badly. Show at least two Vibe Packs so the theming
    difference is visible, not just claimed
[ ] "How it works" in three steps
[ ] Requirements: one device, 3-20 players, no internet needed
[ ] Privacy line, prominent: photos stay on your device
[ ] Footer: changelog, privacy, music credits, feedback, contact
```

**Copy rules.** Write the Philippine angle as the lead, not a footnote — it's the
differentiator with no competitor answer. State the privacy claim **as scoped in 01-DESIGN.md
§4b**; do not write an absolute "photos never leave your device" that v2 will falsify.
Taglish in marketing copy is fine and probably better; keep the privacy and legal sections
in plain English so they're unambiguous.

### A2. Changelog — `/changelog` *(Starlight)*

The release vehicle while there's no store presence. Treat it as a product surface.

```
[ ] Keep a Changelog format: Added / Changed / Fixed / Removed
[ ] Semantic versioning, newest first; one MDX file per release, matching git tags
[ ] Each entry: version, date, human summary before the bullets
[ ] Download link per release for direct-install builds
[ ] Known issues where relevant
[ ] RSS feed
```

Write for players. "Fixed a crash when the 13th player joined" — never "fixed null deref
in `PlayerService`."

### A3. How to Play — `/how-to-play` *(Starlight)*

```
[ ] Quick start: 5 steps to a first game
[ ] Full rules: roles, roundabouts, voting, lives, consequences
[ ] Voting explained carefully — accuser-pays is genuinely novel in this genre and is
    the rule that most needs explaining
[ ] The Mayor explained — it's private and it only matters on ties
[ ] Topic mix: how weights work, what the presets do
[ ] Interference Mode: what each toggle does, with the honest warning that a full-chaos
    session is a different game
[ ] Host tips: player count sweet spot, roundabout count, why host-doesn't-play is the
    default
[ ] FAQ
```

### A4. Privacy — `/privacy`

Legally required once anything is collected, and the strongest trust asset available.

```
[ ] Plain-language summary at top, legal text below
[ ] Explicit: the APP never writes selfies to storage and never transmits them.
    Do NOT claim they can never touch disk — vendor RAM-extension features page
    memory below the app layer (01-DESIGN.md §4b, 06-TESTING-STRATEGY.md §8e).
    A8 audits this page line by line against actual behaviour; an overclaim here
    is the policy being wrong, not the app
[ ] What IS collected: feedback you submit, aggregate usage counters
[ ] What is NOT collected: names, photos, device identifiers, contacts
[ ] Retention periods, stated concretely
[ ] Contact for deletion requests; last-updated date
```

**This page and the app must agree exactly.** Audit A8 checks it line by line. If they
disagree, one is wrong, and it is not always the policy.

### A5. Music credits — `/credits`

New, and not optional — it's a licence obligation for CC-BY tracks and good practice for
the rest.

```
[ ] Every Vibe Pack: pack name, track title, artist, licence type, licence URL
[ ] Generated from the licence.json files in the build, never hand-maintained —
    hand-maintained credit pages drift and drift silently
[ ] Linked from the in-app watermark tap target
```

### A6. Feedback — `/feedback`

```
[ ] Type selector: bug / feature / balance / content (wrong or bad clue) / other
[ ] Description; optional email; optional screenshot
[ ] App version and platform captured automatically
[ ] POST /v1/feedback with client and server validation
[ ] Honeypot + rate limit; clear success and failure states
[ ] Note that attachments are stored and for how long
```

The **content** category matters more than it looks — bad or regionally-wrong clues are
the most likely real complaint, and they're cheap to fix if reported.

### A7. Press / About — `/about`

```
[ ] Short project story
[ ] Press kit: logo, screenshots across multiple Vibe Packs, key art, one-paragraph
    description
[ ] Contact
```

### Site-wide

```
[ ] OG images per page (astro-og-canvas)
[ ] sitemap.xml, robots.txt, full favicon set
[ ] Dark mode default, light available
[ ] Analytics: privacy-respecting or none at all
[ ] 404 in the app's voice — "Di ako, 'oi!" writes itself here
```

---

## Part B — Admin Console

Start from a maintained shadcn/ui starter rather than building the shell (07-TEMPLATES.md
§3). **Check real package versions before adopting** — templates routinely claim currency
while depending on a framework version behind. `package.json` is the source of truth, not
the README.

### B1. Dashboard — `/`

```
[ ] Unread feedback count
[ ] Word-bank status: current version, per-topic counts against the 60 minimum
[ ] Content health: topics below minimum, unreviewed drafts
```

**Every telemetry chart is gone.** v1 collects nothing (ADR 0015), so sessions over time,
player-count distribution, topic weight popularity, Vibe Pack draw rates and Interference
adoption have no data behind them and are not built.

The original rule stands for what remains: every panel should be able to change a decision.
With telemetry removed, feedback and content health are the only two that can — which is
the honest shape of a dashboard for a beta with no analytics.

### B2. Feedback triage — `/feedback`

The console's main job.

```
[ ] Table: date, type, version, platform, status, excerpt
[ ] Filter by type / status / version / platform; full-text search
[ ] Detail view with attachment via signed URL, never a raw path
[ ] Status: new → triaged → in progress → resolved → won't fix
[ ] Internal notes; tags; link to a GitHub issue
[ ] Bulk status change; soft delete only
[ ] Content reports link directly to the word in the word-bank editor
```

### B3. Word banks — `/word-banks`

The most valuable admin surface, because clue quality is the core differentiator and it's
hand-authored (02-CONTENT-PH.md).

This is a **UI on top of the Phase 2 pipeline**, not a replacement for it. The CSV
validator ships first as a script so content authoring never blocks on the console.

```
[ ] Topic list with word counts, version, difficulty distribution
[ ] Word CRUD with the three-tier clue editor: tight / standard / loose
[ ] Validation mirroring the Phase 2 validator exactly — same rules, same rejections
[ ] Difficulty rating and region field per word
[ ] Bulk CSV import/export — hand-authoring 60+ words per topic in a web form will not
    be tolerable for long, and the bulk path is how new topics actually land
[ ] Versioned publish; atomic, with rollback
[ ] Preview: exactly what an imposter sees at each tier
[ ] Quality flags: tiers too similar, clue too long, clue contains the word, duplicate
```

### B4. Removed — telemetry detail

There is no `/telemetry` route. v1 collects no telemetry at all (ADR 0015), so a browser
over aggregate events would have nothing to browse. Recorded as removed rather than deleted
silently, so a reader of an older draft knows this was a decision.

### B5. Settings — `/settings`

```
[ ] Admin account and session management
[ ] Feature flags for server-controlled behaviour
[ ] Backup status: last pg_dump, AND last verified restore
```

Surface the **last verified restore** date, not just the last backup. An untested backup
is a guess, and a dashboard showing only "last backup: 2 hours ago" is actively
misleading.

### Console-wide

```
[ ] Auth on every route; redirect when unauthenticated
[ ] Admin action log; confirmation on destructive actions
[ ] Optimistic UI with rollback on failure
[ ] Keyboard shortcuts (cmd+K) — small surface, high daily value
```

---

## Playwright coverage

| Test | Site | Admin |
|---|---|---|
| Pages load, nav works | ✓ | ✓ |
| Visual baseline @ 375/768/1440 | ✓ | ✓ |
| axe-core, zero critical/serious | ✓ | ✓ |
| Form submit, success + failure | feedback | word CRUD |
| Auth redirect when logged out | — | ✓ |
| Link crawl, all resolve | ✓ | — |
| Lighthouse ≥ 95 / 100 | ✓ | — |
| Credits page matches build licences | ✓ | — |
