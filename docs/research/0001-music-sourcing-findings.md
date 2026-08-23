# Music sourcing — verified findings

**Date:** 2026-08-24 · **Researched by:** Claude · **Status:** research, not a decision

What follows is licence text I actually read, on the dates shown. It is **not** clearance —
nobody has downloaded a file, checked whether it loops, or screenshotted a licence page, and
`04-MUSIC-SOURCING.md` §4 requires all three per track before anything ships.

The one finding that changes the plan is in §1. Read that first.

---

## 1. Incompetech fails criterion 3, and it is ranked #2 in our own doc

`04-MUSIC-SOURCING.md` §1 makes five criteria mandatory, and the third is:

> Content ID free / DMCA-safe — your players will post clips, and a claim on their TikTok
> kills word of mouth faster than any bug

**Incompetech tracks get Content ID claims.** Incompetech's own
[YouTube Content ID page](https://incompetech.com/music/royalty-free/youtube-contentid.html)
exists specifically to deal with them: it tells affected users to add credit to the video
description and then *dispute* the claim, which is released within about 72 hours. There is a
bulk-release form for channels with many affected videos.

That is a claims process, not an absence of claims. Our criterion is not "claims can be
resolved" — it is that a player posting a clip should never see one. A 72-hour dispute on
someone's TikTok is exactly the friction §1 rules out.

**Recommendation: drop Incompetech from the shortlist, or accept the criterion is relaxed.**
It should be a conscious choice either way. Incompetech's catalogue is genuinely the largest
and best-organised free option, so this costs something real — but the criterion was written
knowing that.

The licence itself is otherwise fine: CC BY 4.0, commercial use permitted, attribution
required in a specific form (`"Title" Kevin MacLeod (incompetech.com) Licensed under Creative
Commons: By Attribution 4.0`), and we are building an attribution watermark anyway.

---

## 2. Source-by-source, against the five criteria

| Source | Licence | Commercial | Attribution | Content ID | Verdict |
|---|---|---|---|---|---|
| **Kenney** | CC0 | yes | none | none | **Safest**, but see §3 |
| **OpenGameArt** (CC0 filter) | CC0 | yes | none | none | **Best fit for full tracks** |
| **Pixabay** | Pixabay Content Licence | yes, with a caveat | none | none known | Usable, caveat in §4 |
| **Incompetech** | CC BY 4.0 | yes | required | **claims happen** | Fails criterion 3 |
| **Free Music Archive** | per-track CC | varies | varies | varies | Per-track check, no blanket answer |
| **Mixkit** | Mixkit licence | not verified | not verified | not verified | Not checked |

CC0 is the only category where all five criteria are satisfied without reading a second page,
because CC0 waives everything and there is no rights-holder left to register with a PRO or
file a Content ID reference.

---

## 3. Kenney is jingles, not tracks

`04-MUSIC-SOURCING.md` ranks Kenney first and notes "the Music Jingles pack is the main music
offering". Confirmed, and the shape matters: [Music
Jingles](https://kenney.nl/assets/music-jingles) is **85 short jingles**, CC0 — event stings,
transitions, notifications. Not 2–4 minute loopable beds.

So Kenney covers the **SFX** side of §3 completely and at zero legal risk — interference
stinger, reveal whoosh, card flip, shutter click, vote tap — and covers **none** of the six
Vibe Pack tracks.

---

## 4. Pixabay's standalone-distribution caveat

The [Content License
Summary](https://pixabay.com/service/license-summary/) permits commercial use with no
attribution, and prohibits selling or distributing content "on a Standalone basis" — meaning
where no creative effort has been applied and it remains substantially as it appears on their
site.

Bundling a track as the soundtrack of a game is the ordinary reading of "creative effort
applied", and is not standalone distribution. **That is an interpretation, not a guarantee**,
and Pixabay's terms have changed before — §2 of our own doc says to verify the current
language on the day of download. If Pixabay is used, screenshot the licence page that day.

They also do not address app-store distribution explicitly, and their summary says only the
full licence is binding.

---

## 5. Concrete candidates to evaluate

All CC0 on OpenGameArt, so all five criteria are satisfied by the licence alone. **Nobody has
listened to these.** They are a starting shortlist, not selections.

| Pack | Mood needed | Candidate | Notes |
|---|---|---|---|
| **Sayaw** | Upbeat synth-pop | [Calm Ambient 2 (Synthwave 15k)](https://opengameart.org/content/calm-ambient-2-synthwave-15k) | The Cynic Project, written for *Pixelsphere*. Likely calmer than Sayaw wants |
| **Lamig** | Cold minimal electronic | [Calm Ambient 1 (Synthwave 4k)](https://opengameart.org/content/calm-ambient-1-synthwave-4k) | Same author; the "calm ambient" framing fits Lamig better than Sayaw |
| **Alon** | Hazy drift | [CC0 — Calm / Relaxing Music](https://opengameart.org/content/cc0-calm-relaxing-music) | A collection, needs listening through |
| **Tahimik** | Sparse piano | same collection | Same |
| **Palengke** | Bright, percussive | [CC0 Retro Music](https://opengameart.org/content/cc0-retro-music) | Retro/chiptune may read as too game-y |
| **Tugtog** | Sunny bounce, dancehall-adjacent | **nothing found** | The hardest one. Reggae/island instrumental is thin in CC0 |

[CC0 Music](https://opengameart.org/content/cc0-music-0) — a curated collection by *midcyber*
of roughly 700 CC0 pieces in MP3/OGG/WAV/FLAC, many explicitly loopable — is the single best
place to start, and is where the four unfilled packs most likely get solved.

**Tugtog is the likely problem.** It is the most culturally specific brief in the set, and
free CC0 reggae/island instrumental is scarce. Options, in order: search FMA per-track with a
CC0/CC-BY filter; relax Tugtog toward a generic upbeat groove; or make Tugtog the one
commissioned track.

---

## 6. What still needs a human

Nothing above discharges §4's per-track workflow. For each of the six:

1. **Listen to it.** Nothing here has been heard. Mood fit is the whole point of a Vibe Pack
   and it is not researchable.
2. **Read the licence page for that specific asset and screenshot it.** OpenGameArt is
   per-asset; a collection being labelled CC0 does not make every item in it CC0.
3. **Confirm it loops**, or can be looped with a short crossfade.
4. **Convert to OGG**, 2–4 MB, six packs under ~20 MB total.
5. **Write `licence.json`** — source, type, URL, acquired date, attribution — and set
   `isPlaceholder: false`. A test then requires a track file to exist.

A10 additionally requires that every bundled track's licence permit commercial distribution
on Google Play, **with the screenshot on file**. CC0 satisfies that; a screenshot is still
required as evidence.

---

## 7. Recommendation

**Take the CC0-only route.** It satisfies all five criteria by construction, needs no
attribution bookkeeping across six packs, and removes the Content ID question entirely rather
than managing it.

Concretely: Kenney for every SFX, OpenGameArt CC0 for five of the six beds, and treat Tugtog
as the exception to solve last — either from FMA or by commissioning it.

The watermark still ships regardless. `03-VIBE-SYSTEM.md` §5 requires attribution UI to be
consistent across packs even where a licence does not demand it, because inconsistent
attribution looks like an accident.

**Sources**

- [Pixabay Content License Summary](https://pixabay.com/service/license-summary/)
- [Incompetech licensing FAQ](https://incompetech.com/music/royalty-free/faq.html)
- [Incompetech YouTube Content ID](https://incompetech.com/music/royalty-free/youtube-contentid.html)
- [Kenney — Music Jingles](https://kenney.nl/assets/music-jingles)
- [OpenGameArt — CC0 Music](https://opengameart.org/content/cc0-music-0)
- [OpenGameArt — CC0 Calm / Relaxing Music](https://opengameart.org/content/cc0-calm-relaxing-music)
- [OpenGameArt — CC0 Retro Music](https://opengameart.org/content/cc0-retro-music)
- [OpenGameArt — Calm Ambient 1 (Synthwave 4k)](https://opengameart.org/content/calm-ambient-1-synthwave-4k)
- [OpenGameArt — Calm Ambient 2 (Synthwave 15k)](https://opengameart.org/content/calm-ambient-2-synthwave-15k)
