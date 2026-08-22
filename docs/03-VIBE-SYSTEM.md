# Vibe Packs — Music-Driven Theming

A Vibe Pack is **one licensed instrumental track + one complete visual theme.** One is
drawn per session and drives how the entire game looks and moves.

---

## 1. Licensing — read this before anything else

**You cannot ship instrumentals of "It Wasn't Me" (Shaggy) or "Love" (Wave to Earth).**
This is not a caution, it's a hard blocker, and a credit watermark does not change it.

Recorded music carries **two separate copyrights**, and you need a licence for each:

| Right | Covers | Held by |
|---|---|---|
| **Sync licence** | The composition — melody, chords, lyrics | Publisher / songwriter |
| **Master licence** | The specific recording | Label / recording owner |

Traditional per-track licensing for an indie game runs roughly **$500–$2,000 per track**,
negotiated individually, and mainstream commercial releases are frequently simply not
available at indie scale. An "instrumental version" is still the same composition and
usually still someone's master.

**Attribution is not a licence.** Naming the artist in a watermark is what you do *after*
you have permission. On its own it is documentation of the infringement.

### Why this matters more for a party game than most

The failure mode isn't a lawyer. It's:
1. **Store takedown** — App Store and Play both action music claims.
2. **Content ID on your players.** Your users will post clips to TikTok, Reels, and
   YouTube. Uncleared music means their posts get claimed or muted — which strangles the
   exact organic spread a barkada game depends on.

So the requirement isn't just "legal," it's **streamer-safe / Content-ID-free**. Filter
for that explicitly when sourcing.

### What to use instead

The design goal was never those two specific songs — it was **two moods**: a loose,
sunny, dancehall-adjacent bounce, and a soft, hazy bedroom-pop drift. Those moods are
abundantly available cleared. Source from:

| Source | Licence model | Notes |
|---|---|---|
| **Kenney** (kenney.nl) | CC0, no attribution | Zero legal risk, safe on any storefront including DRM-locked ones. Small catalogue |
| **Pixabay Music** | Pixabay Content Licence | Free, broad. **Verify current commercial terms per track** — they have changed before |
| **Free Music Archive** | Per-track CC, varies | Filter carefully; every track can carry a different CC flavour |
| **Incompetech** (Kevin MacLeod) | CC-BY | Clear credit instructions. Long-standing workhorse |
| **WOW Sound** | Revenue-tiered | Common License covers projects under $100K. **DMCA-safe and Content ID free** — exactly the property you need |
| **Epidemic Sound / Soundstripe** | Subscription | Strongest legal clarity, ongoing cost |
| **Foximusic** | Lifetime, PRO-free | Pre-cleared for streaming, multiple versions per track |
| **Commission a Filipino artist** | You own it outright | Genuinely worth pricing. Local OPM-adjacent instrumentals would make the app unmistakably PH, and a student-rate commission for 6 loops may cost less than a year of Epidemic |

**PRO warning:** avoid tracks whose composer is registered with a PRO (ASCAP/BMI/FILSCAP)
unless the licence explicitly covers it — PRO-registered music can generate performance
obligations even when you hold a sync licence. Prefer **PRO-free** libraries.

**Per-track licence record is mandatory.** Every pack in `assets/vibes/` ships with a
`licence.json` recording source, licence type, licence URL, purchase/download date, and
required attribution text. `A6` audits that every shipped track has one. No record, no
ship.

---

## 2. Pack anatomy

```
assets/vibes/<pack_id>/
  track.ogg           # looping instrumental, seamless
  licence.json        # source, type, url, acquired, attribution
  theme.json          # design tokens (below)
```

```jsonc
// theme.json
{
  "id": "tugtog_init",
  "displayName": "Tugtog",
  "palette": {
    "bg": "#0E1116", "surface": "#171B22", "surfaceAlt": "#1F242D",
    "textPrimary": "#F2F4F8", "textMuted": "#8B94A3",
    "crew": "#4ADE80", "imposter": "#F0A868",
    "interference": "#C084FC", "danger": "#F87171"
  },
  "type": { "display": "Chillax", "body": "Inter", "scaleRatio": 1.25 },
  "motion": { "profile": "bouncy", "stiffness": 180, "damping": 14, "baseMs": 240 },
  "texture": { "card": "paper-grain", "grainOpacity": 0.06 },
  "watermark": { "track": "Tugtog", "artist": "Artist Name", "position": "bottom-center" }
}
```

Themes are **data, not code.** Adding a pack must never require a Dart change — this is
also what lets v2 sync a theme across devices (01-DESIGN.md §17).

---

## 3. Launch pack set

Six packs. Each name is a mood, and the two marked ★ are the cleared stand-ins for the
moods originally requested.

| Pack | Mood target | Palette direction | Motion | Fits |
|---|---|---|---|---|
| **Tugtog** ★ | Loose sunny bounce, dancehall-adjacent — the *It Wasn't Me* feeling without the song | Warm dark, amber + lime accents | Bouncy, overshoot springs | Rowdy barkada nights |
| **Alon** ★ | Hazy bedroom-pop drift — the *wave to earth* feeling | Muted teal-slate, soft cyan accent | Slow, heavy damping, long fades | Chill, late, low-energy |
| **Palengke** | Bright, busy, percussive | High-chroma: red, yellow, cobalt on off-white | Snappy, short, punchy | Big loud groups, Pagkain topics |
| **Lamig** | Cold minimal electronic | Near-monochrome, single ice-blue accent | Precise, linear, no overshoot | Tense, serious, competitive tables |
| **Tahimik** | Sparse piano / ambient | Warm paper cream, ink brown, muted red | Very slow, gentle, almost still | Small groups, high-focus |
| **Sayaw** | Upbeat synth-pop | Neon magenta + violet on deep purple | Fast, energetic, lots of motion | K-Pop-heavy mixes, party peak |

Motion profiles are real spring parameters, not vibes-in-prose — `bouncy` and `precise`
must produce visibly different reveal-card behaviour, or the system is decoration.

---

## 4. Behaviour

| Moment | Behaviour |
|---|---|
| `VIBE_ROLL` | Pack drawn before onboarding so the theme is up from screen one. Brief title card: pack name + track + artist |
| During play | Track loops seamlessly under everything |
| Reveal card | Audio **ducks ~6dB** while a card is held open — reinforces the private moment |
| Interference event | Track ducks, stinger plays, track returns |
| Consequence prompt | Ducks noticeably; the room should get quieter |
| Game summary | Track swells back to full |
| Replay | Rerolls unless pinned |
| Mute | Always one tap away. **Watermark stays visible when muted** — attribution is a licence obligation, not an audio feature |

**No-repeat:** a pack cannot be drawn twice in a row unless it is the only one enabled.

---

## 5. Watermark

Small, persistent, bottom-centre. Format: `♪ Tugtog — Artist Name`. Tappable to open a
full attribution sheet listing licence type and source URL.

- Must not obstruct the voting grid or the reveal card content area.
- Contrast ≥ 4.5:1 against the pack's own background — check per pack, not once.
- Present in **every** pack regardless of whether the licence demands it. A CC0 track
  needs no credit, but inconsistent attribution UI looks like an accident.

---

## 6. Accessibility & performance

- **Reduced motion** (`MediaQuery.disableAnimations`) collapses every motion profile to a
  simple fade. The palette still applies — theme and motion are independent.
- **Contrast is per-pack.** Every palette must pass 4.5:1 for body text and 3:1 for large
  text. `Sayaw`'s neon-on-purple and `Palengke`'s high-chroma set are the two that will
  fail if unchecked.
- **Crew vs imposter accent must be distinguishable without colour** — a shape or texture
  difference too, since the accent pair changes per pack and some pairs will be poor for
  colour-blind players.
- Audio is bundled, not streamed (offline-first). Budget ~2–4MB per pack as OGG; six packs
  should stay under ~20MB total.
- Preload only the drawn pack's track. Decoding six at launch will blow the cold-start
  budget.

---

## 7. Implementation

Base on the **Flutter Casual Games Toolkit basic template**, which already ships
`lib/audio/` (an `AudioController` with music/SFX split and lifecycle handling) and
`lib/style/` for theming. Do not build an audio stack from scratch — see 07-TEMPLATES.md.

> **Path corrected 2026-08-23.** These were written as `lib/src/audio/` and `lib/src/style/`;
> upstream flattened `lib/src/` away, and both were adopted into DiAkoOi at
> `app/lib/audio/` and `app/lib/style/`. The song and SFX registries there are deliberately
> empty — the template's placeholder audio was removed at adoption, and Phase 3 fills them
> from `assets/vibes/`. `AudioController` treats an empty playlist or SFX list as a silent
> no-op, so nothing crashes before the packs land. See `docs/adr/0002-templates.md`.

- `audioplayers` for playback (already wired in the template).
- Theme delivered through a Riverpod provider exposing the active `VibePack`, consumed by
  a `ThemeExtension` so every widget reads tokens rather than constants.
- **No widget may hardcode a colour.** A golden test per primitive × per pack catches
  violations immediately, and that matrix is the real proof the system works.
