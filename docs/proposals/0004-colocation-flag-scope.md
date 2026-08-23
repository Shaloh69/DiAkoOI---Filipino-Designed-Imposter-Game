# Proposal 0004 — Say what `requiresColocation` counts, in §17

**Status:** Proposed · **Date:** 2026-08-24 · **Blocks:** nothing in v1

## The finding

`01-DESIGN.md` §17 lists, under "cheap now, expensive later":

> 4. Tag every interference event with `requiresColocation` as authored.

The field was added to `InterferenceEventDefinition` in Phase 6 with `@Default(false)`, and
**no event ever set it**. All 38 events read as "does not require co-location", which is
wrong for at least four of them. The audit §17 promises would have returned an empty set and
looked like a clean bill of health.

A test named `every event carries requiresColocation` was green throughout. It asserted
`expect(event.requiresColocation, isA<bool>())` — true of every bool ever constructed. This
is the failure mode `CLAUDE.md` now has a standing rule about: a green test proves what it
asserts, not what its name implies.

Both are now fixed on the implementation side. The tagging is done and the test asserts the
exact tagged set, verified by three mutations. **What is not resolved is which set §17 meant**,
and that is what this proposal is for.

## The ambiguity

§17 says:

> Remote is a different product — it kills roughly a third of the interference pool outright
> (Silent, Whisper, gestures, Interrogation all assume you can see and hear each other).

The parenthetical and the fraction point at different sets.

**Narrow reading — the mechanic needs a shared room.** Gestures, whispering, and a live
yes/no interrogation stop working the moment players are not physically together, whatever
the client looks like. That is exactly the four events named:

| id | why |
|---|---|
| `silent_round` | gestures only |
| `silent_round_all` | gestures only, whole lap |
| `whisper_only` | a whisper does not survive any channel |
| `interrogation` | live question and answer before the vote |

Four of 38 is **11%**, not a third.

**Wide reading — the app cannot enforce it, so a table must.** Everything with
`EventEnforcement.social`, plus `taboo` which is `retroactive`:

`silent_round`, `whisper_only`, `one_word_only`, `copycat`, `liars_tax`, `interrogation`,
`one_word_round`, `the_chain`, `silent_round_all`, `double_clue`, `taboo`

Eleven of 38 is **29%** — "roughly a third", and that is almost certainly where the figure
in §17 came from.

## Why the narrow reading was implemented

Because the wide set is not durable. `one_word_only`, `copycat`, `the_chain` and `taboo` are
socially enforced *today* only because the v1 app never sees a clue — clues are spoken. A
client where clues are typed could enforce every one of them automatically, anywhere in the
world. Tagging them `requiresColocation` records a fact about **v1's architecture**, not
about the event, and would mislead exactly the v2 audit the flag exists to serve.

Under the wide reading the flag is also redundant: it would be precisely
`enforcement != EventEnforcement.app`, computable, and storing it invites the two to drift.

## The change requested

In §17, replace:

> That's what `requiresColocation` is for: tag each event as you author it and the v2 audit
> becomes a query instead of a re-read.

with:

> That's what `requiresColocation` is for: tag each event as you author it and the v2 audit
> becomes a query instead of a re-read. **It means the event's mechanic needs a shared
> room** — gestures, whispering, live interrogation — and not merely that the app cannot
> enforce it. Word-shape constraints (One Word, Copycat, The Chain, Taboo) are socially
> enforced in v1 only because the app never sees a spoken clue; a client that read clues
> could enforce them at any distance, so they are not tagged. For "what can the app not
> police", query `enforcement` instead.

And correct the fraction in the paragraph above it: **"roughly a third"** describes the
socially-enforced pool, not the co-location-dependent one, which is four events. Suggested:

> it kills the four events whose mechanic needs a shared room outright (Silent, Whisper,
> gestures, Interrogation), and strands the rest of the socially-enforced pool — roughly a
> third of the catalogue — with no table to police it

That sentence is also more useful than the original, because those are two different
problems with two different v2 answers: the first four get cut, the other seven get an
enforcement mechanism.

## If you prefer the wide reading

Then say so and the flag widens to eleven events — but please also delete the field and
derive it from `enforcement`, because under that reading they are the same predicate and
two sources of one truth is how they diverge.

## Alternatives considered

- **Leave §17 alone and just tag.** Rejected: the next person to read §17 gets the same
  ambiguity and may widen the set, and nothing in the doc tells them they would be changing
  its meaning. The pinning test would then look like an obstacle rather than a decision.
- **Tag both, with two fields.** Rejected as speculative. Nothing in v1 or the sketched v2
  reads either flag; a second one is more surface for no current consumer.
