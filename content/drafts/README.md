# Candidate drafts — NOT authored content

**Everything in this directory was machine-generated. None of it has been written,
reviewed, or approved by a human author.** It exists to give the calibration round
something to argue with instead of a blank page (`content/STYLE.md`), and to give the
pipeline real data to run against.

Nothing here ships. `content/*.csv` — one file per topic, currently headers only — is where
authored content goes, and the tooling deliberately reads only the top level of `content/`
so these cannot be bundled by accident.

---

## Status

| | |
|---|---|
| Topics | Wave 1 — `pagkain`, `aktor`, `kpop`, `buhaypinoy`, `teleserye` |
| Words | 30 per topic, **150 total** |
| Clues | **450** |
| Validation | passes with 0 rejections, 0 warnings |
| Reviewed by a human | **no** |
| Cultural review | **no** |

**This is half of the wave-1 target**, which is 60 words per topic (`02-CONTENT-PH.md` §1).
That was deliberate. The constraint on this phase is not volume — it is author agreement
(§6a) and cultural review (§7). Generating 300 unreviewed entries instead of 150 would have
produced more review work, not more shippable content.

---

## What to do with these

1. **Run the calibration round first** (`02-CONTENT-PH.md` §6a). All three authors write the
   same 10 words independently, compare, then ratify `content/STYLE.md` as v1. Do this
   *before* touching anything here — agreement you did not participate in is not agreement.
2. **Treat every row as a proposal.** Rewrite, retune the difficulty, or delete outright.
   Deleting is a perfectly good outcome; a word nobody at the table would say is worse than
   no word.
3. **Move approved rows into `content/<topic>.csv`.** Only that directory is bundled.
4. **Re-run validation** as you go:
   ```
   cd app && dart run tool/content_cli.dart validate --dir ../content
   cd app && dart run tool/content_cli.dart stats    --dir ../content
   ```

## Known weaknesses to look for

These are the failure modes most likely present in machine-generated Taglish, and the ones
the validator cannot catch:

- **Register.** `02-CONTENT-PH.md` §2 rule 3 wants how the table actually talks. Some of
  these read like careful Tagalog rather than natural Taglish.
- **Truth.** §2 rule 2 — a clue must be *true* of the word. Verify each one; a plausible-
  sounding but wrong clue makes a round unwinnable rather than hard.
- **Tier behaviour.** §2 rule 4 — tight should survive three crew clues, loose should fail
  by lap two. Only a playtest settles this, and it cannot be checked mechanically.
- **Generational reach.** §2 rule 6 — a 19-year-old and their tita should both have a shot.
  The `aktor` and `teleserye` sets in particular lean on names that may not travel.
- **Difficulty ratings** are guesses. They need a table to calibrate.

## Feature lists

`content/STYLE.md` §2 requires listing 4–6 core features per word *before* writing clues,
because that is what makes "how many features does this clue hand over" a countable
question rather than a vibe.

The generated rows below were written against these feature lists. Recorded here in
STYLE.md's own format so the reasoning is auditable and so authors can disagree with the
features, not just the wording.

### `pagkain`

```
Adobo      — ulam · toyo+suka · maasim-alat · matagal lutuin · karne · nasa bahay
Sinigang   — ulam · may sabaw · maasim · may gulay · karne o hipon · mainit kainin
Halo-halo  — dessert · malamig · maraming sangkap · may yelo · pang-tag-init · hinahalo
Lechon     — buong baboy · iniihaw · malutong ang balat · pang-fiesta · nasa gitna ng handaan
Sisig      — ulam · mainit na plato · baboy · maasim-anghang · pulutan · galing Pampanga
Balut      — itlog · may sisiw · binebenta sa gabi · street food · hindi lahat kaya
Taho       — inumin · matamis · may sago · binebenta ng naglalakad · umaga
Pancit     — noodles · mahaba · pang-birthday · may gulay · pang-handaan
```

### `aktor`

```
Vice Ganda        — komedyante · host ng noontime · bakla/out · matalas magsalita · nasa pelikula rin
Coco Martin       — aktor · aksyon · matagal na teleserye · lead role · kilala sa isang serye
Sarah Geronimo    — mang-aawit · umaarte rin · sumikat sa noontime · maliit ang tindig
Nora Aunor        — beterana · maliit ang tindig · drama · lumang pelikula · iconic
Dolphy            — komedyante · matanda na · lumang pelikula · tinaguriang hari ng komedya
```

### `kpop`

```
BTS        — boy group · pitong miyembro · Korean · sikat worldwide · may pangalan ang fandom
BLACKPINK  — girl group · apat ang miyembro · Korean · sikat worldwide · sumasayaw
Twice      — girl group · maraming miyembro · Korean · cute na konsepto · sikat sa Asia
IU         — solo · babae · kumakanta · umaarte rin · Korean
Lightstick — gamit · may kulay · hawak sa concert · pang-fandom · umiilaw
```

### `buhaypinoy`

```
Jeepney       — sasakyan · makulay · pampubliko · abot-abot bayad · maraming tao · nasa kalsada
Palengke      — lugar · maingay · maraming tindero · sariwang paninda · tumatawad · maaga
Sari-sari     — tindahan · maliit · nasa tabi ng bahay · tingi · may bintana
Videoke       — kumakanta · may mic · may score · maingay sa gabi · sa okasyon
Bayanihan     — pagtutulungan · magkakapitbahay · pagbubuhat ng bahay · lumang ugali
```

### `teleserye`

```
Darna            — superhero · babae/Pinay · lumilipad · may bato · maraming gumanap · komiks noon
Ang Probinsyano  — teleserye · aksyon · pulis · sobrang tagal · isang lead actor
Encantadia       — fantaserye · engkantada · apat na kaharian · may mahika · sariling wika
Eat Bulaga       — noontime · may laro · matagal na · araw-araw · maraming host
Marimar          — lumang palabas · dalampasigan · may aso · sobrang sikat noon
```

Feature lists for the remaining words follow the same method and are implicit in the clue
sets; write them out as you review, because doing so is what catches a clue that hands over
more features than its tier should.
