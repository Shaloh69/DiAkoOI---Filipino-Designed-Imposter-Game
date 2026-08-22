# Contributing to DiAkoOi

Thanks for wanting to help. The most valuable contributions here are probably not code.

---

## What's most useful

| Priority | What | Why |
|---|---|---|
| 🥇 | **Regional corrections** | A clue that doesn't land in Cebu, Davao, or Iloilo is a real bug. The launch content is national-scoped and Manila-centric blind spots are the likeliest flaw |
| 🥇 | **New word bank entries** | 720 words is the launch target. More topics and more depth are always welcome |
| 🥈 | **Playtest reports** | Round length, points of confusion, rules asked about twice. Nothing in the test suite tells us this |
| 🥈 | **Bug reports** | Especially on Android devices we don't own |
| 🥉 | **Code** | Read `docs/00-START-HERE.md` first. The design is settled; implementation is where help lands |

---

## Content contributions

The word bank is the project. Contributions to it must follow `content/STYLE.md`.

**Before you write anything:**
1. Read [`content/STYLE.md`](content/STYLE.md) — especially the feature-count method
2. Read [`docs/02-CONTENT-PH.md`](docs/02-CONTENT-PH.md) §2 authoring rules
3. Look at existing entries in `content/` for register

**The short version:**
- List 4–6 core features of the word first
- **Tight** = 3–4 features · **Standard** = 2 · **Loose** = 1
- Natural Taglish, the way you'd say it to a friend
- Never contains the word or an obvious synonym
- Every clue must be **true** — misdirection is the players' job
- Under 90 characters

**Format** — one CSV per topic, in `content/`:
```csv
topic_id,word,clue_tight,clue_standard,clue_loose,difficulty,region
pagkain,Adobo,"ulam na may toyo at suka, matagal lutuin","isang ulam na kinakain with rice","isang pagkain sa bahay",1,national
```

**Run the validator before opening a PR:**
```bash
python scripts/validate_content.py content/pagkain.csv
```

**Set `region` honestly.** If a word or clue is specific to Luzon, Visayas, or Mindanao,
tag it. Mistagging as `national` is worse than not contributing it.

---

## Code contributions

Read [`CLAUDE.md`](CLAUDE.md) for conventions. The rules that will get a PR rejected:

- **Anything that writes a selfie to disk or network.** Non-negotiable. See
  `docs/01-DESIGN.md` §4b
- **Any hardcoded colour, duration, radius, or spacing.** Everything resolves from the
  active Vibe Pack theme
- **Flutter imports in `app/lib/engine/`.** That directory is pure Dart
- **Game logic in widget callbacks.** Resolution stays a pure function
- **Weakening `app/test/privacy/`** or any committed golden baseline
- **Commercial audio.** A credit is not a licence — see `docs/03-VIBE-SYSTEM.md` §1

**Changing game rules?** Open an issue first. `docs/01-DESIGN.md` is the source of truth and
several rules look wrong until you read the rationale — §7a (Mayor ties), §7b (damage cap),
and §9c (why Spread the Blame caps at 2 instead of banning duplicates) each fix a bug that
a "cleaner" version reintroduces. Propose, don't patch.

**Commits:** [Conventional Commits](https://www.conventionalcommits.org/), one per task.
**Branches:** `phase/NN-short-name` or `fix/short-description`.

---

## Reporting a bad clue

Fastest path. Open an issue with the **content** template, or in-app: Feedback → Content.

Include the word, the topic, which tier was wrong, why it didn't work, and where you're
from. That last one matters more than you'd think.

---

## Licensing of contributions

- **Code** contributions are licensed under [MIT](LICENSE)
- **Content** contributions are licensed under [CC BY-NC-SA 4.0](LICENSE-CONTENT)

By opening a PR you agree to these terms.

---

## Code of conduct

Be decent. This is a party game about accusing your friends of lying — keep that energy in
the game and out of the issue tracker.

Content that would land badly at a family reunion doesn't belong in the word bank.
Political figures, anything tied to ongoing tragedy, and religious content are handled
carefully or omitted entirely.
