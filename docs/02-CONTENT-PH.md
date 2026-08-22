# Philippine Content Specification

The word bank is the product. Mechanics can be copied in a weekend; a well-tuned Filipino
word bank with three authored clue tiers per word cannot. Treat this as the most valuable
artifact in the repo.

---

## 1. Scale

| | Target |
|---|---|
| Topics at launch | 12 (01-DESIGN.md §13a) |
| Words per topic | **60 minimum**, 80 comfortable |
| Clues per word | 3 (tight / standard / loose) |
| **Total authored clues at launch** | **~2,160** |

This is a content project, not a side task. Phase 2 of the implementation plan exists
purely for it, and it runs in parallel with engine work.

**Decision: all 12 topics ship at launch**, authored by three people (Hubs, Ivan, Race).
At ~4 minutes per word for all three tiers that is roughly 48 focused hours total, ~16
each — two or three weekends per person. Volume is not the risk. **Drift between authors
is**, and §7 exists entirely to manage it.

**Ship order within the phase** — author in this sequence so that if the schedule slips,
what's finished is still a coherent launch set rather than twelve half-topics:

| Wave | Topics | Why this order |
|---|---|---|
| **1** | `pagkain` · `aktor` · `kpop` · `buhaypinoy` · `teleserye` | Widest demographic reach. A table with titas, students, and K-Pop stans all find something. **This wave alone is a shippable game** |
| **2** | `opm` · `lugar` · `brands` · `basketball` | Broad appeal, slightly narrower. Rounds out a full session |
| **3** | `internet` · `anime` · `kasaysayan` | Most polarising — `internet` dates fastest, `kasaysayan` needs the most careful review, `anime` splits hard by age |

Wave 1 is the Phase 2 exit gate. Waves 2 and 3 may land during Phase 4 without blocking
anything, since the loader is version-driven.

---

## 2. Authoring rules

1. **A clue never contains the word or an unambiguous synonym.**
2. **A clue must be true.** Misdirection is the players' job. An author who lies makes the
   round unwinnable rather than hard.
3. **Write in natural Taglish.** How the table actually talks. "somewhere you eat when
   nagmamadali" not "a location for expedited dining." Stiff English reads as a
   translation and kills immersion instantly.
4. **Tight survives three crew clues. Loose fails by lap two.** If a word doesn't behave
   that way in playtest, retune the word — never the tier definition.
5. **No proper nouns inside clues** unless the noun is broader than the answer. A clue for
   *Sarah Geronimo* may say "isang singer na sikat sa noontime shows"; it may not name a
   specific show she is uniquely tied to.
6. **Avoid words requiring narrow generational knowledge** unless the topic is explicitly
   retro. A 19-year-old and their tita should both have a shot.
7. **Difficulty rating 1–5 per word**, so a session can be balanced rather than
   accidentally brutal.
8. **Set `region`** — `national` for launch. The field exists so Visayas/Mindanao packs
   land later with no migration (01-DESIGN.md §13c).

---

## 3. Tier calibration

The tiers are defined by **how many of the word's core features the clue hands over.**
This is the operational rule; `/content/STYLE.md` has the full method and worked examples.

The distinction that matters is **similarity** (things sharing features) versus
**association** (things that merely co-occur). A feature-based clue gives the imposter
attributes they can describe, so they can talk. An association-based clue tells them the
neighbourhood and hands them nothing to say. Tight is feature overlap; loose is
association.

| Tier | Features given | Function | Test |
|---|---|---|---|
| **Tight** | 3–4 | Near-neighbour sharing most attributes | Could a stranger produce three plausible clues from this alone? Yes → tight |
| **Standard** | 2 | Functional description, one or two safe clues | One good clue, shaky by the second → standard |
| **Loose** | 1 | Broad frame, then you're on your own | Only one vague clue possible → loose |

List 4–6 features per word before writing anything. If you can't say how many features a
clue conveys, it isn't ready.

**Quality flag: tiers too similar.** If tight and standard read nearly the same, the
difficulty setting does nothing and the host's choice is fake. The admin console flags
this automatically (WEB-SPEC §B3).

---

## 4. Sample entries

Format for the bank. These are calibration references — match this register.

### `pagkain` — Pagkain

| Word | Tight | Standard | Loose | Diff |
|---|---|---|---|---|
| Adobo | "ulam na may toyo at suka, matagal lutuin" | "isang ulam na kinakain with rice" | "isang pagkain sa bahay" | 1 |
| Halo-halo | "malamig na dessert na maraming sangkap" | "kinakain kapag mainit ang panahon" | "isang matamis na bagay" | 1 |
| Balut | "kinakain sa gabi, binebenta sa kalye" | "isang street food na hindi lahat kaya" | "isang pagkain na galing sa hayop" | 2 |
| Sisig | "mainit na ulam sa plate, pang-pulutan" | "ulam na sikat sa Pampanga" | "isang ulam na inihahain" | 2 |
| Taho | "binebenta ng naglalakad tuwing umaga" | "matamis na inumin na may sago" | "isang bagay na binibili sa labas" | 2 |
| Kwek-kwek | "orange na street food, isinasawsaw" | "pagkain sa labas ng school" | "isang meryenda" | 3 |
| Bibingka | "niluluto sa dahon, sikat tuwing Pasko" | "isang kakanin na kinakain sa umaga" | "isang matamis na pagkain" | 3 |
| Dinuguan | "maitim na ulam, kadalasang may puto" | "isang ulam na hindi lahat kumakain" | "isang ulam na may sarsa" | 3 |

### `aktor` — Aktor at Aktres

| Word | Tight | Standard | Loose | Diff |
|---|---|---|---|---|
| Vice Ganda | "host ng noontime show, kilala sa pagpapatawa" | "isang sikat na TV personality" | "isang tao sa showbiz" | 1 |
| Coco Martin | "lead sa isang matagal na aksyon na teleserye" | "isang aktor na sikat sa TV" | "isang artista" | 2 |
| Nora Aunor | "legendary na aktres, may iconic na linya sa pelikula" | "isang aktres mula sa nakaraang panahon" | "isang tao sa pelikula" | 3 |
| Kathryn Bernardo | "aktres na sikat sa love team movies" | "isang batang aktres" | "isang artista" | 2 |
| Dolphy | "tinawag na Comedy King, matagal nang sikat" | "isang komedyante noong araw" | "isang sikat na tao" | 3 |

### `kpop` — K-Pop

| Word | Tight | Standard | Loose | Diff |
|---|---|---|---|---|
| BLACKPINK | "girl group na apat ang miyembro" | "isang sikat na Korean group" | "isang grupo ng mga tao" | 1 |
| BTS | "boy group na may pitong miyembro, sobrang sikat" | "isang Korean group na kilala worldwide" | "isang grupo sa music" | 1 |
| Lisa | "miyembro ng girl group, hindi Korean ang lahi" | "isang idol na sikat sa sayaw" | "isang tao sa music industry" | 2 |
| TWICE | "girl group na marami ang miyembro" | "isang Korean girl group" | "isang grupo" | 2 |
| NewJeans | "girl group na bago pa lang pero sikat agad" | "isang bagong Korean group" | "isang music group" | 3 |

### `buhaypinoy` — Buhay Pinoy

| Word | Tight | Standard | Loose | Diff |
|---|---|---|---|---|
| Jeepney | "sinasakyan, makulay, may abot-abot na bayad" | "isang paraan ng pagbiyahe" | "isang bagay sa kalsada" | 1 |
| Sari-sari store | "maliit na tindahan sa tabi ng bahay" | "kung saan bumibili ng tingi" | "isang lugar na binibilhan" | 1 |
| Tricycle | "may sidecar, sinasakyan papuntang malapit" | "isang sasakyan sa barangay" | "isang bagay na sinasakyan" | 2 |
| Palengke | "maingay, maraming tindero, sariwang paninda" | "kung saan bumibili ng pagkain" | "isang lugar na maraming tao" | 2 |
| Videoke | "may mic, may score sa dulo, maingay sa gabi" | "isang libangan tuwing may okasyon" | "isang bagay na ginagawa sa party" | 2 |
| Fiesta | "taunang selebrasyon, maraming handa" | "isang okasyon sa barangay" | "isang pagtitipon" | 3 |

### `teleserye` — Teleserye at Pelikula

| Word | Tight | Standard | Loose | Diff |
|---|---|---|---|---|
| Darna | "superhero na Pinay, may lumilipad na kapangyarihan" | "isang bidang may kapangyarihan" | "isang karakter" | 2 |
| Eat Bulaga | "noontime show na matagal nang umeere" | "isang programa tuwing tanghali" | "isang palabas sa TV" | 2 |
| One More Chance | "romance movie na may sikat na linya tungkol sa pagmamahal" | "isang pelikulang pang-jowa" | "isang pelikula" | 3 |
| Ang Probinsyano | "aksyon na teleserye na sobrang tagal umere" | "isang teleserye tungkol sa pulis" | "isang palabas sa TV" | 2 |

---

## 5. Pipeline

```
Author (CSV) → validate → import via admin → version → publish → app syncs
                  ↑
            bundled fallback ships with every build
```

**CSV schema:**
```csv
topic_id,word,clue_tight,clue_standard,clue_loose,difficulty,region
pagkain,Adobo,"ulam na may toyo...","isang ulam na...","isang pagkain sa bahay",1,national
```

**Validation (blocks import):**
- Clue contains the word or a listed synonym → reject
- Any clue empty → reject
- Clue over 90 characters → warn (long clues are hard to read on the card)
- Tight/standard cosine similarity too high → warn (tiers too close, §3)
- Duplicate word within a topic → reject
- `difficulty` outside 1–5 → reject

**Versioning:** publish is atomic. A failed publish leaves the previous version live. The
app requests `GET /v1/word-banks?since=<version>` and falls back to bundled content on any
failure, including a slow response — offline-first means never blocking.

---

## 6. Multi-author workflow

Three authors is the right call for 2,160 clues and the wrong call for consistency unless
this is handled deliberately.

### 6a. Calibration round — do this before authoring anything at scale

**All three authors write the same 10 words independently**, then sit down together and
compare tier by tier.

Suggested calibration set (deliberately spans difficulty and topic):
`Adobo` · `Jeepney` · `BLACKPINK` · `Vice Ganda` · `Halo-halo` · `Palengke` · `Darna` ·
`Sisig` · `BTS` · `Videoke`

What you are looking for:
- **Whose "tight" is tightest?** Someone's tight will be another's standard. Pick the
  version that matches the §3 test and write down why.
- **Register mismatch.** One author writes fuller Tagalog, another writes heavier English.
  Pick a register and hold it.
- **Length drift.** If one author averages 40 characters and another 85, the cards look
  inconsistent.

Output is a one-page **house style note committed to `/content/STYLE.md`** with three or
four worked examples per tier. That file, not this document, becomes the day-to-day
reference while authoring.

**A draft `/content/STYLE.md` (v0) already exists** with a proposed method — tiers defined
by *feature count* rather than feel, plus worked examples for all ten calibration words.
Use it as the thing to argue with, not as the answer. It is explicitly unratified: commit
v1 with all three names on it after the session, or the alignment never actually happened.

Rerun a short calibration after the first 100 words. Drift reappears once people speed up.

### 6b. Topic ownership

One owner per topic — a topic authored by committee is worse than one authored by one
person. Suggested split by wave, adjust to whoever actually knows the material:

| Author | Wave 1 | Wave 2 | Wave 3 |
|---|---|---|---|
| A | `pagkain` · `buhaypinoy` | `brands` | `kasaysayan` |
| B | `kpop` · `teleserye` | `opm` · `basketball` | `internet` |
| C | `aktor` | `lugar` | `anime` |

**Author the topic you actually know.** A K-Pop topic written by someone who doesn't
follow K-Pop produces clues that are technically true and socially useless.

### 6c. Cross-review

Every topic is reviewed by **an author who did not write it**, before it reaches cultural
review. Checking for:
- Tier separation against `/content/STYLE.md`
- Clues that only work if you already know the answer
- Register and length consistency

Cheap, catches most drift, and it is not the same thing as §7 cultural review — this is
authors checking each other's craft, that is outsiders checking the content lands.

### 6d. Mechanics

- **One CSV per topic**, `/content/<topic_id>.csv`. Separate files mean no merge conflicts
  when three people author simultaneously.
- **Run the validator before every commit.** It is a script from Phase 2 precisely so it
  works without the admin console existing.
- **Commit in batches of ~20 words**, not 60. Small commits make a bad calibration easy to
  unwind.
- **Log difficulty honestly.** A `1` you found hard to write is probably a `3`.

---

## 7. Cultural review

Before launch, **a Filipino playtest group that did not author the content** reviews every
topic for:

- **Clues that only work if you're from Manila** → retag `region`, or cut.
- **Clues that are subtly wrong.** Regional food naming varies more than authors expect.
- **Anything that would land badly at a family table** — the app will be played at
  reunions. Political figures, anything tied to ongoing tragedy, and religious content are
  the three categories to handle carefully or omit.
- **Generational blind spots.** Test with at least one player under 20 and one over 45.

This review is a gate, not a suggestion. Content authored by one person for their own
barkada will not survive contact with a wider audience, and the word bank is the one part
of the product that is expensive to fix after launch.
