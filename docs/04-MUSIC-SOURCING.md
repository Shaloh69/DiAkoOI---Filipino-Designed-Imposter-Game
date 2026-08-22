# Music Sourcing — Free Route

**Decision: source free/CC-licensed tracks for v1.** Commissioning a Filipino artist stays
on the table for v2 and would be a real differentiator, but it has weeks of lead time and
should not block Phase 3.

Read **03-VIBE-SYSTEM.md §1** first for why commercial tracks are off the table. This file is
the practical hunt.

---

## 1. Filter criteria — apply before downloading anything

A track qualifies only if **all five** are true:

```
[ ] Commercial use permitted, explicitly, in the licence text
[ ] Usable in a mobile app on Google Play (not "YouTube creators only")
[ ] Content ID free / DMCA-safe — your players will post clips, and a claim on
    their TikTok kills word of mouth faster than any bug
[ ] PRO-free — the composer is not registered with ASCAP/BMI/FILSCAP, or the
    licence explicitly covers performance rights
[ ] Loops cleanly, or can be looped with a short crossfade
```

"Free" and "royalty-free" are not the same thing, and "free for YouTube" is not free for
an app. Read the actual licence page, not the download button.

---

## 2. Sources, ranked for this project

| # | Source | Licence | Attribution | Verdict |
|---|---|---|---|---|
| 1 | **Kenney** — <https://kenney.nl/assets> | **CC0** | None required | **Start here.** Zero legal risk, safe on any storefront including DRM-locked ones. Small catalogue, game-oriented. The Music Jingles pack is the main music offering |
| 2 | **Incompetech** (Kevin MacLeod) — <https://incompetech.com/music/> | CC-BY | Required, clear instructions | Huge catalogue, filterable by mood, decades of game use. The workhorse. Attribution is fine since you're building a watermark anyway |
| 3 | **OpenGameArt** — <https://opengameart.org/> | Mixed (CC0/CC-BY/GPL) | Varies per asset | Game-ready, clear licence tags. **Filter to CC0 or CC-BY only** — avoid GPL-licensed audio, it complicates distribution |
| 4 | **Free Music Archive** — <https://freemusicarchive.org/> | Per-track CC | Varies | Deep and genuinely good. **Every track carries a different CC flavour** — check each one, and skip anything NonCommercial |
| 5 | **Pixabay Music** — <https://pixabay.com/music/> | Pixabay Content Licence | Not required | Free and broad. **Terms have changed before** — verify current commercial language on their licence page the day you download |
| 6 | **Mixkit** — <https://mixkit.co/free-stock-music/> | Mixkit licence | Not required | Straightforward, decent quality, clear per-download licence notes |

**Avoid for this project:** anything NonCommercial (`CC BY-NC`), anything ShareAlike
(`CC BY-SA` — it can propagate obligations), and any library whose terms are scoped to
"YouTube videos."

---

## 3. Hunt list per Vibe Pack

Search terms to use on the sources above. Target **one 2–4 minute loopable instrumental
per pack**, six total.

| Pack | Mood | Search terms | Best source to try first |
|---|---|---|---|
| **Tugtog** | Sunny bounce, dancehall-adjacent | `reggae instrumental`, `island groove`, `upbeat tropical`, `ska loop`, `dub` | Incompetech (has a reggae/island section), FMA |
| **Alon** | Hazy bedroom-pop drift | `lo-fi chill`, `dreamy ambient guitar`, `bedroom pop instrumental`, `soft lofi loop` | Pixabay, FMA — lo-fi is the most abundant free genre online |
| **Palengke** | Bright, busy, percussive | `upbeat percussion`, `marimba loop`, `playful cheerful game`, `bouncy casual` | Kenney, OpenGameArt |
| **Lamig** | Cold minimal electronic | `minimal techno loop`, `ambient electronic`, `dark synth loop`, `tension bed` | Incompetech, OpenGameArt |
| **Tahimik** | Sparse piano / ambient | `solo piano ambient`, `sparse piano loop`, `calm minimal piano` | Incompetech, FMA |
| **Sayaw** | Upbeat synth-pop | `synthwave loop`, `upbeat electronic pop`, `retro synth game`, `dance loop` | Pixabay, OpenGameArt |

**Also grab** while you're there — you'll need them in Phase 5:
- **Interference stinger** (1–2s glitch/alert) — Kenney UI Audio, CC0
- **Reveal whoosh**, **card flip**, **shutter click**, **vote tap** — Kenney Interface
  Sounds / UI Audio, all CC0, no attribution

Kenney's SFX packs cover essentially all of this at CC0, which is why they're first on the
list — SFX attribution across dozens of tiny sounds gets unwieldy fast.

---

## 4. Per-track workflow

For each of the six:

```
[ ] Read the licence page. Screenshot it
[ ] Confirm all five criteria in §1
[ ] Download the highest quality available
[ ] Convert to OGG, target 2-4MB (six packs should stay under ~20MB total)
[ ] Trim and set a clean loop point — test the seam on repeat for 2 minutes
[ ] Normalise to a consistent LUFS across all six, so switching packs doesn't
    blow someone's ears out
[ ] Write assets/vibes/<pack_id>/licence.json
[ ] Commit the licence screenshot to docs/licences/<pack_id>.png
```

**`licence.json` schema:**
```json
{
  "packId": "tugtog",
  "trackTitle": "",
  "artist": "",
  "source": "incompetech.com",
  "sourceUrl": "",
  "licenceType": "CC-BY-4.0",
  "licenceUrl": "",
  "acquiredDate": "2026-08-22",
  "attributionText": "\"Track Title\" by Artist — CC BY 4.0",
  "commercialUse": true,
  "contentIdFree": true,
  "proFree": true
}
```

This file is **not optional and not editable without instruction** (CLAUDE.md
§Off-limits). A3 audits that every shipped track has one; A8 checks the public credits
page matches them exactly.

---

## 5. Realistic expectations

Free tracks will be **less distinctive** than commissioned work. Six free loops will sound
like six competent library tracks, not like a soundtrack someone wrote for your game. That
is an acceptable v1 trade — the theming system is what carries the feature, and a good
palette shift on a decent track still reads as "this session feels different."

Where it will show: **Tugtog and Alon are the two hardest to source well**, because they're
the most specific moods. Budget extra hunting time there, and accept "close enough" rather
than stalling Phase 3 over it. The pack names are yours, so a track that isn't quite
dancehall can still be Tugtog.

Two upgrade paths later, in order of cost:
1. **Swap individual tracks** as you find better ones. The system is data-driven, so
   replacing a track is a file swap plus a `licence.json` edit — no code change.
2. **Commission 6 original OPM-adjacent loops** for v2. A student-rate commission from a
   Filipino musician may cost less than a year of a subscription library, you own the
   result outright, and it makes the app unmistakably local in a way no library track can.

---

## 6. Exit criteria for A3

- [ ] Six tracks acquired, one per pack
- [ ] Every track passes all five §1 criteria
- [ ] Every track has a complete `licence.json` and a committed licence screenshot
- [ ] Loop seams tested — no audible click or gap over 2 minutes
- [ ] Levels normalised across all six
- [ ] Total bundled audio under ~20MB
- [ ] SFX set acquired (stinger, whoosh, flip, shutter, tap) — CC0 preferred
