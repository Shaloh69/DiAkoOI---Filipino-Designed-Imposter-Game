# DiAkoOi — Game Design Document

*Revision 4. Supersedes the "Imposter" revisions 1–3 entirely. This document specifies
**v1 (pass-and-play, single device)**. §17 records what changes for v2.*

**Di Ako, 'Oi!** — "Not me!" The thing every accused player shouts. The name is the
denial, which is the whole game.

---

## 1. Concept

A pass-and-play (single-device) social deduction party game **built specifically for
Filipino players**. One phone goes around the group. Everyone sees a secret word except
the Imposter(s), who get a deliberately vague clue. Players describe the word aloud in
Taglish, then accuse. Bad accusations cost the accusers personally. Players who hit zero
lives take an open-ended forfeit.

### Differentiators

| | What it is |
|---|---|
| **Philippine-only content** | Every topic and every clue is authored for a Filipino table — aktor/aktres, K-Pop, pagkain, OPM, teleserye, PBA. Not a translated global word list. This is the moat: no competitor has it. |
| **Weighted random topics** | Host sets a topic mix by percentage (e.g. 20% Aktor / 60% K-Pop / 20% Pagkain); the app rolls each round against those weights. Nobody picks, so nobody games it. |
| **Vibe Packs** | A licensed instrumental track is drawn per session, and it drives the entire visual theme — palette, type, motion feel. Same game, different mood every time (§15). |
| **Vague clue, three tiers** | Imposters get a real authored clue, not a blank card and not a decoy word (§14). |
| **Accuser-pays voting** | A bad accusation costs the people who made it, not the whole crew (§7). |
| **Selfie identity** | Every player's own photo carries through the UI as a Polaroid/ID motif. Never leaves the device in v1 (§4b). |
| **Interference Mode** | Fully optional chaos layer, per-event toggleable (§9). |

Nobody ever sits out. There is no elimination.

---

## 2. Host Setup Parameters

| Parameter | Range | Notes |
|---|---|---|
| Player count | 3–20 | **4–10 is the sweet spot**; 13+ auto-enables Large Group Mode (§2a) |
| **Topic mix** | Weighted % across topics | Must total 100%. Rolled fresh each round (§13). Presets provided |
| Clue difficulty | Tight / Standard / Loose | Which authored tier the imposter receives (§14) |
| Imposter count | 1–4 | Re-rolled each round. Default scales: 3–6 → 1, 7–11 → 2, 12–16 → 3, 17–20 → 4 |
| Lives per player | 1–5 | Persists across rounds; resets on replay |
| Rounds | Host-defined | Game ends when reached |
| Roundabouts per round | 1–3 | Clue-relay laps before voting opens |
| Early-end threshold | Off / N players served a consequence | N = 1–3 |
| **Vibe Pack** | Random / pinned | Default random per session (§15) |
| Interference Mode | Off / On | Master toggle, off by default (§9) |
| Host plays? | Yes / No | Default **No**. See §2b — this is not cosmetic |

### 2a. Large Group Mode (13–20 players)

At 20 players with 2 roundabouts a single round is 60 handoffs — 15+ minutes before
voting. At 13+ the app automatically caps roundabouts at 1 (overridable with a time
warning), splits the reveal phase into two halves with a return to the host between,
raises the suggested imposter count, and shows a soft pace hint on the interstitial
("~8 min left this round"). Below 13 none of this applies.

### 2b. Host-as-player (resolves a v3 hole)

The host holds the phone and therefore sees things players don't: the round modifier at
`ROUND_START`, Taboo banned words during reconciliation, who is Marked, and full accuser
attribution during voting. If the host is also playing and happens to be the imposter,
that is decisive information.

**Default is host-does-not-play**, and the app says so plainly at setup. If the host
opts in anyway:

- Round modifiers are shown on a **card the host must reveal deliberately**, the same
  hold-to-reveal gesture as a word card — so the table sees them learn it, not read it
  silently while everyone waits.
- Taboo reconciliation is deferred to a **neutral seat** (the player to the host's
  left runs it) in any round where the host is under a secret constraint.
- The host's own reveal is passed to the neighbour to operate.

This is a real constraint, not a warning label. It is cheaper than building a redacted
host view, and at a party the social protocol is enforceable.

---

## 3. Game State Machine

```
LOBBY
  ↓ (host configures §2; topic weights must sum to 100)
VIBE_ROLL
  ↓ (draw session Vibe Pack → theme + track load — §15)
PLAYER_ONBOARDING
  ↓ (per player: name → selfie/skip → round-1 reveal)
  ↓ [Interference SUPPRESSED during round 1 — §9f]
ROUND_START
  ↓ (roll topic against host weights → select word + clue tier — §13, §14)
  ↓ (rotate start seat: startingPlayerIndex = roundIndex % playerCount — §6a)
  ↓ (assign N imposters — fresh roll each round)
  ↓ [if Interference: roll round modifier — §9c]
WORD_DISTRIBUTION            (rounds 2+; round 1 folded into onboarding)
  ↓ ("Pass to X" → reveal card → Done → next)
  ↓ [if Interference: roll per-player event — §9b]
DISCUSSION_PHASE
  ↓ (× roundabouts; constraint banners shown — §9f)
  ↓ [end of each lap: Taboo reconciliation — §9b]
VOTING_PHASE
  ↓ (every player names a suspect aloud; host records caller → accused)
  ↓ [items may be played — §9d]
RESOLUTION
  ↓ (target is imposter → that imposter −2 | target is crew → each accuser −1)
  ↓ [tie → §7a Mayor rule]
  ↓ [modifiers apply, then §7b damage clamp]
LIFE_CHECK
  ↓ (0 lives → forfeit → restored to 1 once served)
ROUND_END_CHECK
  ├─ NO  → ROUND_START
  └─ YES → GAME_SUMMARY → REPLAY_PROMPT
```

---

## 4. Player Onboarding

Per player, passed device-to-device:

1. **Name entry.**
2. **Selfie capture** — becomes their identity everywhere (§4a). **"Skip photo" is
   always available** and produces a **monogram badge** (initial on an auto-assigned
   high-contrast colour) drawn in the same Polaroid frame. Party rooms are dark and some
   people decline; mixed rosters must look deliberate, not broken.
3. **Round-1 reveal** — word or clue, same card mechanic as §5.
4. **Done → handoff → "PASS TO [next]".**

No interference fires during onboarding. Round 1 is deliberately clean so people learn
the base loop before it bends.

### 4a. Selfie as a running motif

Suspect-ID / detective-board language, used on: reveal card (Polaroid pinned to corner,
slightly rotated), pass interstitial, voting grid tiles, consequence prompts, game
summary awards, lobby list. Capture animation: shutter flash → develop → pin-to-corner
with rotation. The monogram fallback uses the identical motion so it never reads as a
downgrade.

### 4b. Selfie storage & privacy

- **v1: in-memory only.** The app never writes a selfie to storage, never
  transmits one, and holds no persistence layer for them.
- **Scope of that guarantee.** It is an application-level guarantee. On devices with
  vendor "Extended RAM" / "RAM Plus" features, the OS may page process memory to a
  swap file — below our layer and not controllable from Flutter. See
  `06-TESTING-STRATEGY.md` §8e. Marketing and policy copy must say "the app never
  writes your photo to storage", never "your photo never touches disk".
- **Downscale at capture.** Store display-resolution bytes only (Polaroid thumbnail
  + grid tile), not the full sensor frame. Reduces memory pressure, paging
  likelihood, and the A5 memory-flat risk simultaneously.
- Scoping to v1 is deliberate — v2 networked play must transmit images or drop them, and
  a promise withdrawn later is worse than one never made. Marketing copy uses the scoped
  wording. §17 records the v2 position (monogram-only over the wire).
- **Play Again** (same roster) keeps the session alive; selfies persist.
- **New Game** tears the session down; selfies discarded, onboarding runs fresh.

> **Implementation warning.** Both `image_picker` and `camera.takePicture()` write a temp
> file by default and will silently break this. Either capture via
> `CameraController.startImageStream()` and grab one frame to `Uint8List` (preferred), or
> read-then-`File.delete()` inside a `finally`. A test must assert zero new files under
> temp and documents dirs across a full onboarding run.

---

## 5. Reveal Flow

1. **"Pass to [selfie + name]" interstitial** — full screen. Carries the constraint
   banner (§9f) during discussion.
2. **Reveal card** — hold-to-reveal is the primary gate (§6). Selfie pinned to corner.
3. **"Done" confirm** — player-driven, never auto-advance. Conversation sets the pace.
4. **Confirm-tap → handoff → next interstitial as one continuous beat**, not a cut.
5. Repeat. Same pattern in both reveal and discussion phases.

---

## 6. Discussion / Roundabouts

- One roundabout = one full lap, each player giving one spoken clue.
- More laps = more info = easier for crew.
- **Optional soft clue timer, off by default.** Competitors all ship a fixed ~20s timer;
  not having one is deliberate. But it is the standard fix for Large Group pacing, so the
  host can enable a nudging progress ring — no buzzer, no forced advance.

### 6a. Turn order rotation (required)

Speaking last is a structural advantage — you have heard everything and can echo
consensus, which is exactly what an imposter wants.

- **Starting seat rotates every round:** `startingPlayerIndex = roundIndex % playerCount`.
- **Each lap within a round shifts by one** so the same player doesn't close both laps.
- Costs nothing, removes the biggest positional imbalance.

### 6b. Reveal card mechanic

**Hold-to-reveal is primary.** Press-and-hold clears a blur; the word snaps in with a
crew/imposter colour treatment subtle enough not to read across a room. Content is on
screen only while a thumb is down and the player controls the angle.

Tilt-to-reveal is a **secondary flourish only** — a tilted screen is still visible to a
neighbour, so it is weaker privacy than it appears.

---

## 7. Voting & Resolution

Voting is **out loud**. Every player names a suspect; there is no abstain. **A player may
not name themselves** — the grid rejects it. The host records each accusation with a
**two-tap action**: tap the caller's tile, then the accused's tile.

Two-tap is required, not preferred: accuser-pays, Spread the Blame, Near-Unanimous, and
all vote weighting are impossible without knowing who accused whom. The grid shows
"7 of 10 recorded" so the host cannot resolve early. Accuser thumbnails stack under each
tile so the table sees who committed.

**Resolution:**

- Tile with the most votes is the round's target.
- **Target is an imposter** → that imposter **loses 2 lives**. Nobody else loses anything.
- **Target is crew** → **only the players who named that target lose 1 life each.**
  Players who named an actual imposter lose nothing, even in the minority.

**Vote weight affects the tally only, never damage.** A Double Vote or Megaphone player
who backs a wrong target still loses exactly 1 life, not 2. The Mayor's 1.5 likewise.
This must be explicit in `resolveRound()`.

### 7a. Tie handling — the Mayor

At game start the app secretly designates one player as **Mayor** for the whole game,
shown on their round-1 reveal card and reachable thereafter from a private indicator only
they can open.

**The Mayor's weight applies only when a tie exists.** This is the fix for a v3 bug: if
the Mayor's vote always carried 1.5, their chosen tile could never tie with an
integer-valued tile, so the Mayor was mathematically incapable of breaking any tie that
actually occurred. Corrected rule:

1. Tally all votes at weight 1 (or 2 for Double Vote / Megaphone). Integers only.
2. If there is a single highest tile → that's the target. Mayor is irrelevant.
3. **If two or more tiles tie for highest**, and the Mayor named one of them → that tile
   wins.
4. If the Mayor named none of the tied tiles, **or the Mayor is one of the tied
   accused** → the round is a **wash**, nobody loses a life.

The Mayor is private, is a normal player otherwise, and can be an imposter in any round —
an imposter Mayor quietly steering a tie onto a crew member is the best case the role
produces. The table can infer backwards from a resolved tie, which is a real leak the
Mayor has to manage.

### 7b. Damage cap (required)

**No player loses more than 2 lives in a round from all sources combined.** Applied as a
final clamp at the end of RESOLUTION + LIFE_CHECK, not per-effect, so events can stay
written as powerful.

**Sudden Death** (§9c) is the only exception — `bypassesDamageCap: true`, off by default.

**Known consequence, stated so it isn't found as a bug:** a caught imposter takes 2, which
is already the cap. Double Damage Round therefore never doubles imposter damage — it only
ever doubles accuser damage (1 → 2). Double Damage is effectively "accusers pay double."
That asymmetry is accepted.

### 7c. Why accuser-pays

The original rule (wrong vote → all crew lose a life) had three problems, recorded so it
doesn't get reverted casually:

- **Magnitude.** At 10 players / 2 imposters, a correct vote cost 1 life and a wrong vote
  cost 8.
- **Convergence.** Collective punishment drained everyone at the same rate, so who hit 0
  first was mostly a function of how often they were randomly rolled imposter — the
  consequence system, the payoff of the whole game, fired near-randomly.
- **Bandwagoning was free.**

Accuser-pays fixes all three. Doubling the caught-imposter penalty to 2 keeps imposters
at real risk, since they can only be caught once per round.

---

## 8. Lives & Consequences

- Lives persist across rounds.
- At **0 lives** the player picks an **open-ended, self-authored forfeit** (free text,
  not a fixed menu). Prompt categories offered as inspiration only: Truth, Dare, trivia,
  mini-game duel, performance, drawing/charades, accent challenge, random spin.
- **After serving, the player is restored to 1 life.** Parking players at 0 forever gave
  them nothing left to lose and turned the back half of long games into disengaged people
  collecting punishments. Serving clears the debt and puts them one hit from the next.
- **If two forfeits are triggered at once** (High Stakes, §9c): both are served, and the
  player is restored to 1 life **once**, after the second. Restoration is a floor, not a
  per-forfeit reward.
- `consequenceLog` count is the headline stat on the end screen.
- **Early-end threshold:** game may end once N players (host picks 1–3) have each served
  at least one forfeit.
- Host may end the game manually at any point.

---

## 9. Interference Mode

Master toggle (§2) unlocking independently switchable sub-systems. Nothing fires unless
its specific toggle is on.

### 9a. Toggle groups

| Toggle | Fires | Effect |
|---|---|---|
| Player-Pick Events | Each reveal during word distribution, rounds 2+ | Random event on that player |
| Round-Start Events | `ROUND_START`, rounds 2+ | Random modifier on the whole round |
| Item System | Via Player-Pick or Item Drop | Holdable items used later |

Each group exposes a per-event eligibility checklist so a host can allow "+1 life" events
while disabling "steal a life," etc.

### 9b. Player-Pick Events

Rolled at `playerPickProbability` (default 25%, host-adjustable) per reveal.

| Event | Effect | Enforcement |
|---|---|---|
| **Bonus Life** | +1 life, capped at the game max | App |
| **Life Drain** | −1 life immediately | App |
| **Steal a Life** | Steal 1 from a random other player | App |
| **Mystery Item** | Receive a random item (§9d) | App |
| **The Fool** | If this player becomes the vote target this round they **gain** a life instead of losing one. Secret. Acting suspicious becomes strategy | App |
| **Double Vote** | Their accusation carries tally weight 2 (damage still 1) | App |
| **Vote Lock** | Immune from being named this round; grid rejects it | App |
| **Marked** | Visible marker on their tile — the table knows interference touched them, not what | App |
| **Silent Round** | Gestures only, no speaking, next lap | Social — banner |
| **Whisper Only** | Must whisper their clue | Social — banner |
| **One Word Only** | Clue must be exactly one word | Social — banner |
| **Copycat** | Must work a previously spoken clue word into theirs | Social — banner |
| **Liar's Tax** | Must give a deliberately misleading clue, even as crew | Secret |
| **Interrogation** | Must answer one yes/no question truthfully before the vote. Cannot be "are you the imposter?" | Social — banner |
| **Taboo** | 2–3 banned words. Reconciled at end of lap, below | Retroactive |
| **Nothing** | No event — keeps rolls genuinely uncertain | — |

**Taboo reconciliation.** The player sees their banned words privately and gives their
clue. **At the end of that lap** the app shows the banned words to the whole table on the
host's screen: "Did [player] say any of these?" Group answers aloud, host taps **Clean**
or **Slipped**. Slipped → −1 life (subject to §7b). This preserves tension during the clue
(nobody knows what to listen for) while making the penalty adjudicable — the earlier
design gave the words privately and asked the group to catch violations they couldn't see.

**Liar's Tax note.** A crew member forced to mislead is behaviourally identical to an
imposter. Under accuser-pays the blast radius is just the people who fell for it, which is
correct — they did misread the table, even if the game caused it.

> **Consistency rule.** All crew share one real word per round; there is no per-player
> word to swap. Because distribution is sequential, **no event may change a player's role
> mid-round** — someone who already saw the real word cannot be converted to imposter
> since they'd still remember it. Interference modifies behaviour, votes, lives, and
> information *around* the word, never the role assignment.
>
> **Rejected: Role Swap — do not reintroduce.** Prototyped and removed twice. Restricting
> swaps to un-revealed players later in the pass order works but fizzles silently when it
> rolls on the last player. The failure is caused by sequential reveal and doesn't go away
> until v2 (§17), where simultaneous reveal makes it worth reconsidering.

### 9c. Round-Start Events

Rolled at `ROUND_START`, before imposter assignment. One per round.

| Event | Effect |
|---|---|
| **Double Damage** | Accuser damage doubles (see §7b for why imposter damage doesn't) |
| **Mercy Round** | **No life is lost this round from any source** — vote resolution, Life Drain, Taboo, all of it. Explicitly total, resolving an earlier ambiguity |
| **Blind Vote** | Grid hides names/selfies during entry, revealed after the tally locks. **Tiles keep fixed positions and large seat numbers** so the host isn't set up to fail — the interference is that the table can't watch the tally build |
| **Reverse Round** | The core rule inverts: naming an imposter costs **each accuser** 1 life, and naming a crew member costs **the accused** 2. Rewritten from a garbled earlier draft |
| **Double Imposter** | Sets this round's count to `min(imposterCount + 1, 4)` **before assignment**, so the extra imposter gets the vague clue like any other. **Rerolls into a different event if already at 4** |
| **No Roundabouts** | Straight to voting, pure gut-read. Suppresses lap-dependent events (§9f) |
| **Extra Roundabout** | +1 lap this round |
| **Item Drop** | Every player gets a Mystery Item. **Only eligible when the Item System toggle is on** |
| **Fool's Round** | The vote target **gains** a life. Announced in advance, so baiting accusations is the play |
| **One Word Round** | Every clue must be a single word |
| **Reverse Order** | Pass order runs backwards, inverting §6a rotation |
| **Near-Unanimous** | The vote only lands if **75% or more** of players name the same target; otherwise a wash. Deliberately a threshold, not true unanimity — under true unanimity a single imposter simply names someone nobody else did and guaranteed themselves a free round every time |
| **Spread the Blame** | **No more than 2 players may name the same suspect.** A hard "no duplicates" ban was mathematically unresolvable: N voters across N tiles gives every tile exactly one vote and therefore a permanent N-way tie. A cap of 2 preserves the forced-spread feel while still producing a plurality |
| **Sudden Death** | Vote target loses all remaining lives. Bypasses §7b. **Off by default** |
| **The Chain** | Each clue must start with the last letter of the previous clue |
| **Silent Round (all)** | Nobody speaks; the whole lap is gestures |
| **Category Reveal** | Imposters are told the topic. Crew knows this happened |
| **Double Clue** | Every crew player gives two clues per lap — much more info, much harder for imposters |
| **Blackout** | Reveal card auto-hides after a few seconds; memorise fast |
| **High Stakes** | Forfeits triggered this round come in pairs (§8) |
| **Bodyguard** | One random crew player is secretly immune this round; they aren't told |

### 9d. Item System

One item held at a time. Badge shown next to the holder's selfie so the table knows
someone is holding *something*, not what.

> **Role-dependent effects resolve against the holder's role in the round they use it**,
> not the round they picked it up, since roles re-roll. Some items favour one side — that's
> interference luck, not a bug. No item may ever leak the real word to an imposter.

| Item | Class | Effect |
|---|---|---|
| **Shield** | Defence | Cancels the next life loss |
| **Mirror** | Defence | Reflects the next life loss onto whoever caused it |
| **Veto** | Defence | Cancels the round's vote result entirely. Playable after the tally shows |
| **Peek** | Info | **Crew:** confirms whether one chosen player is an imposter. **Imposter:** one small extra hint about the real word |
| **Reword** | Info | **Imposter:** upgrades their clue one tier tighter this round (§14). **Crew:** no effect — wasted, which is part of the luck |
| **Crosscheck** | Info | Reveals whether two chosen *other* players share the same role as each other — not which role. Leaks nothing about the word. Note it's high-variance: "same" is near-noise, "different" identifies one of two as the imposter |
| **Megaphone** | Vote | Tally weight 2 for one round (damage unchanged) |
| **Silencer** | Vote | Forces one player to skip their clue next lap — looks incredibly suspicious |
| **Decoy** | Vote | Visually swaps this player's selfie with another's on the grid for one vote. Pure misdirection |
| **Wild Card** | Wildcard | Rerolls into a different random item on use |

**Second pickup → "use it or lose it"** prompt on the reveal card: play the held item now
or discard, then take the new one. Silent fizzling makes an interference roll feel like
nothing happened, which is the worst outcome for a surprise system.

### 9e. Animation opportunities

Interference is rare and surprising, so it earns big beats — and the **Vibe Pack's accent
colour drives all of them** (§15), so interference looks different every session:

- **Event reveal:** a distinct interference card — glitchy, electric, higher contrast than
  the calm word card, so nobody confuses the two.
- **Round-level events:** brief full-screen flash / shake / colour-wash at round start so
  the whole table registers the round is bent.
- **Item pickup:** loot-get — icon spins in, pulses, settles into the badge slot.
- **Item use:** punchy activation tied to the item (Shield = barrier flash over the tile).
- **Taboo reconciliation:** banned words slam onto the host screen one at a time, like
  evidence laid on a table.

### 9f. Banners, suppression, stacking

**Constraint banner.** Roughly a third of the pool is socially enforced — the app cannot
detect a violation. Acceptable for a party game, but the app must arm the table: any
round-level constraint, and any player-level constraint the table is meant to police
(Copycat, The Chain), shows as a persistent banner on the interstitial and clue screen.
Secret constraints (Taboo, Liar's Tax, The Fool) do not — they're revealed in the round
recap, where the "oh, *that's* what happened" payoff lives.

**Suppression.** If **No Roundabouts** is the modifier, every lap-dependent player-pick
event (Silent, Whisper, One Word, Copycat, Taboo, Liar's Tax) is removed from the eligible
pool and rerolled.

**Stacking precedence:**
1. Player-pick effects (individual, immediate)
2. Round-start modifiers (global, multiplicative)
3. Items (holder chooses timing, so they get last word)
4. §7b damage clamp

Where two effects contradict, **the effect that protects a player wins.** A memorable rule
beats a lookup table nobody recalls at a party.

---

## 10. Game End & Replay

- Ends at the round limit, the early-end threshold (§8), or host command.
- **Summary** with selfie award callouts: **Sharpest Read** (highest % of accusations
  landing on a real imposter), **Best Bluffer** (most rounds as imposter without being
  targeted), **Most Consequences**, **Most Wanted** (most votes received), **Interference
  Magnet**.
- Scoring is **cosmetic** — no hard win condition; adding one would fight the forfeit loop.
  But accuser-pays means Sharpest Read now genuinely correlates with taking fewer
  forfeits, so the summary reflects real play.
- **Replay** carries all parameters, resets lives and the round counter, keeps selfies and
  names. **Vibe Pack rerolls** unless pinned (§15).

---

## 11. Data Model

```
Room
  - id, hostIsPlayer: bool                 // §2b — default false
  - mayorPlayerId                          // fixed for game, private (§7a)
  - vibePackId, vibePinned: bool           // §15
  - status (lobby | onboarding | in_round | voting | resolved | ended)
  - settings: { playerCount, clueDifficulty, imposterCount, livesPerPlayer,
                topicWeights: [ { topicId, weightPercent } ],   // must sum to 100 (§13)
                totalRounds, roundaboutsPerRound,
                earlyEndConsequenceThreshold,   // N players served, or null
                largeGroupMode: bool,           // auto at 13+
                clueTimerSeconds: int | null,   // null = off (default)
                interference: { enabled, playerPickEnabled, roundStartEnabled,
                                itemsEnabled, playerPickProbability, enabledEventIds } }
  - currentRoundIndex

Player
  - id, roomId, name, seatOrder
  - selfieBytes: Uint8List | null          // IN-MEMORY ONLY, never a path (§4b)
  - monogramColor: string | null
  - currentLives, heldItem: itemId | null
  - consequenceLog: [ { roundIndex, description, servedAt } ]
  - stats: { accusationsMade, accusationsCorrect, roundsAsImposter,
             roundsAsImposterUncaught, votesReceived, interferenceEventsReceived }

Round
  - id, roomId, roundIndex, startingPlayerIndex
  - topicId, word, imposterClue, clueTierUsed
  - imposterPlayerIds: [ ]
  - roundaboutsCompleted, roundaboutsRequired
  - roundModifier: eventId | null
  - playerPickEvents: [ { playerId, eventId, payload } ]
  - votes: [ { voterId, accusedId, tallyWeight } ]   // weight = tally only, never damage
  - itemUsages: [ { playerId, itemId, roleAtUse, targetPlayerId, phase } ]
  - resolution: { targetPlayerId, targetWasImposter, wasWash: bool,
                  lifeDeltas: [ { playerId, delta, sources } ],
                  cappedPlayerIds: [ ] }

Topic
  - id, nameEn, nameFil, description, iconRef, defaultWeightPercent

WordBank
  - topicId, word, clues: { tight, standard, loose }, difficultyRating, region

VibePack
  - id, displayName, trackFile, artistName, licenceType, licenceUrl, attributionText
  - theme: { palette, typeScale, motionProfile, cardTexture }   // §15

InterferenceEventDefinition
  - id, category, name, description, effectType
  - enforcement: 'app' | 'social' | 'retroactive'
  - requiresRoundabout: bool               // suppression (§9f)
  - requiresColocation: bool               // v2 audit (§17)
  - requiresItemSystem: bool               // e.g. Item Drop
  - bypassesDamageCap: bool                // Sudden Death only
  - defaultEnabled: bool
```

Removed from earlier revisions: `Room.code` (nothing to join on one device — v2 concern)
and `Round.revote` (the Mayor replaced the revote in §7a).

---

## 12. Open Items

1. **Do imposters know each other** at 2–4? Recommend a host toggle defaulted **off** —
   knowing your partners makes multi-imposter rounds much easier and crew already has the
   harder job.
2. **`playerPickProbability` default** — start at 25%, needs playtest.
3. **Accuser-pays playtest** — does a personal cost make quiet players default to safe
   consensus picks, flattening discussion? If so, consider +1 life for a correct *minority*
   accusation to reward independent reads.
4. **Two-tap ergonomics at 10+** — prototype early; consider a "same accused, tap multiple
   callers" batch mode.
5. **Topic weight UX** — sliders that force a sum of 100 are fiddly. Consider a
   proportional-normalise approach (weights are relative, displayed as %) instead.
6. **Word bank scale** — target 60+ words per topic × 3 tiers. See §13/§14 and 02-CONTENT-PH.md.

---

## 13. Topic System (Philippine-only)

Every topic ships **Philippine-authored**. This is the product's moat: the global
competitors have generic word lists, and a Filipino table playing "Aktor at Aktres" or
"Pagkain sa Karinderya" is not a translation of anything they have.

### 13a. Launch topics

| id | Name | Scope |
|---|---|---|
| `aktor` | Aktor at Aktres | PH film/TV actors, past and present |
| `kpop` | K-Pop | Groups, members, songs — enormous in PH |
| `pagkain` | Pagkain | Filipino dishes, street food, kakanin, merienda |
| `opm` | OPM | Original Pilipino Music — artists, bands, songs |
| `teleserye` | Teleserye at Pelikula | Shows, films, iconic lines |
| `lugar` | Lugar sa Pilipinas | Cities, islands, landmarks, provinces |
| `basketball` | PBA at Basketball | Teams, players, the sport as lived in PH |
| `buhaypinoy` | Buhay Pinoy | Jeepney, sari-sari, tricycle, fiesta, palengke |
| `brands` | Sikat na Brands | Jollibee, Chowking, local household names |
| `internet` | Viral at TikTok PH | PH internet culture, memes, creators |
| `anime` | Anime at Games | Titles popular with PH players |
| `kasaysayan` | Kasaysayan | Historical figures and events |

### 13b. Weighted random selection

The host does not pick a topic per round. They set a **mix**, and the app rolls:

```
Example: Aktor 20% · K-Pop 60% · Pagkain 20%
Round 1 → roll 0.73 → K-Pop
Round 2 → roll 0.11 → Aktor
Round 3 → roll 0.55 → K-Pop
```

- Weights must total 100%. Any topic at 0% is excluded entirely.
- **Presets** so nobody has to fiddle: *Barkada Classic* (even spread), *Stan Mode*
  (K-Pop 60 / OPM 20 / Internet 20), *Tita Mode* (Teleserye 40 / Aktor 30 / OPM 30),
  *Gutom* (Pagkain 60 / Brands 20 / Buhay Pinoy 20), *Sports Night* (Basketball 60 /
  Buhay Pinoy 25 / Brands 15).
- **No-repeat window:** a word cannot repeat within a session, and the same topic cannot
  be drawn more than twice in a row regardless of weight — otherwise a 60% weight produces
  visible streaks that feel broken even though the maths is right.
- **Ceiling.** The window imposes an arithmetic limit the weights cannot exceed: after two
  consecutive draws a topic *must* yield, so **no topic can exceed two draws in three —
  about 66.7%** — however it is weighted. The one exception is a mix with a single eligible
  topic, where there is nothing else to draw and the window cannot apply.

  **The host slider clamps at this ceiling.** It is derived from the no-repeat window and
  the number of enabled topics, never hardcoded — disabling topics changes it, and a
  constant would be silently wrong. A slider that stops communicates the constraint
  wordlessly; a UI that accepts a setting it cannot honour is worse than one that stops,
  and a host mid-lobby with people waiting is not reading explanatory text.

  Engine behaviour and the measurements behind the ceiling:
  `docs/adr/0007-topic-draw-deficit-weighting.md`. Approved from
  `docs/proposals/0001-topic-weight-ceiling.md` on 2026-08-23.
- Rolled with the same seeded RNG as everything else, so games stay reproducible in tests.

### 13c. Regional note

Cebuano/Bisaya players will read some Manila-centric content as foreign. Every word
carries a `region` field (`national` | `luzon` | `visayas` | `mindanao`); v1 ships
national-only content and the field exists so regional packs can land later without a
migration.

---

## 14. Vague Clue Authoring

**Clues are pre-authored per word at three tiers. Nothing is algorithmically derived.**

Algorithmic derivation collapses at the table — "a fruit" for *mangga* is useless once six
clues about sweetness and tropical weather are out, and it produces wildly uneven
difficulty across a bank with no way to tune it.

| Tier | What the imposter gets | Example — word: *Jollibee* |
|---|---|---|
| **Tight** | A near-neighbour sharing most attributes; bluff confidently | "a fast food place kids love, may mascot" |
| **Standard** | Functional description, good for one or two safe clues | "somewhere you eat when nagmamadali" |
| **Loose** | Broad frame; on your own after the first clue | "a place you go with family" |

**Authoring rules:**
- Never contains the word or an unambiguous synonym.
- Must be **true** of the word — misdirection is the players' job, not the author's.
- **Written in natural Taglish**, matching how the table actually talks. A stiffly formal
  English clue reads as a translation and breaks immersion.
- Tight clues should survive three crew clues; loose should fail by lap two. If a tier
  doesn't behave that way in playtest, retune the word, not the tier definition.
- **Scale with player count** — at 12+ there is far more info on the table, so Standard
  behaves like Loose. Auto-nudge one tier tighter in Large Group Mode.

Full topic breakdown and starter content: **02-CONTENT-PH.md**.

---

## 15. Vibe Packs — music-driven theming

A **Vibe Pack** is one licensed instrumental track bundled with a complete visual theme.
One is drawn per session; it plays under the whole game and defines how the game *looks*.

**The point:** the same game feels different every session, and the theme is discovered
rather than configured. It also gives the app a real identity in a genre where every
competitor looks like a default Material template.

- Drawn at `VIBE_ROLL` (§3), before onboarding, so the theme is in place from the first
  screen.
- Host may **pin** a pack instead of rolling.
- Rerolls on Replay unless pinned.
- **Artist watermark** sits bottom-of-screen, small and persistent, naming track and
  artist — required for CC-BY tracks and good practice regardless.
- Each pack drives: palette (background, surface, crew accent, imposter accent,
  interference accent), type scale and display face, motion profile (spring stiffness,
  duration curve), and card texture.
- Audio ducks under interference stingers and the reveal beat; full mute always available.

**Licensing is not optional.** Full specification, licensing rules, the pack list, and the
per-pack theme tokens: **03-VIBE-SYSTEM.md**. Read it before touching audio.

---

## 16. Backend & Operations

v1 is **fully playable offline**. No network call may block starting or finishing a game.
The backend exists for feedback, word-bank delivery, and coarse telemetry, all of which
degrade to bundled or cached fallbacks.

### 16a. What lives where

| Data | Location | Notes |
|---|---|---|
| Selfies | Device memory only | §4b. Not a storage decision to revisit — it's the differentiator |
| Feedback + optional screenshot | Server | User-initiated; a different consent model entirely |
| Word bank | Server, cached on device, **bundled fallback** | Versioned; ships complete so first launch works offline |
| Vibe Pack audio | **Bundled in the app** | Never streamed — offline-first, and licences are per-build |
| Telemetry | Server, aggregate only | Session counts, player-count buckets, topic weights, toggle rates. No names, photos, or device IDs |

A photo taken at onboarding is a party guest's face captured incidentally; a screenshot
attached to a bug report is something the user deliberately chose to send. Do not let the
feedback pipeline become a reason to loosen §4b.

### 16b. Hashing vs encryption

Hashing is one-way; hashing an image destroys it. Two different things are wanted for
feedback attachments and both should be used:
- **Content-addressed storage** — filename is the SHA-256 of the bytes. Gives dedup,
  integrity, no collisions. **Not a security control.**
- **Encryption at rest** — AES-256 at the app layer or LUKS on the host. This is the
  actual protection. Access via short-lived signed URLs.

### 16c. Topology

- **Cloudflare Tunnel** exposes only the public API. No inbound router ports.
- **Tailscale** carries admin console and Postgres, bound to the tailnet, no public DNS.
  **Never Tailscale Funnel for admin** — that publishes it. The goal is unreachable, not
  password-protected.
- **Docker Compose:** Postgres + API + cloudflared.
- **Backups will bite you.** `pg_dump` on cron, encrypted, shipped off-box, **with a
  restore that has actually been tested.** `docker compose down -v` destroys named volumes
  without ceremony.

### 16d. Constraints

- Cloudflare's free plan restricts disproportionate non-HTML content; move blobs to R2 if
  attachments grow.
- A residential connection means uptime = ISP uptime. Fine for feedback. Not acceptable
  for anything the game needs — hence offline-first.
- **Telemetry has a store consequence:** even anonymous counters must be declared in the
  App Store privacy label and covered by a policy URL at submission. Aggregate-only keeps
  the label clean.

---

## 17. v2 Forward Compatibility

v2 removes pass-and-play; everyone uses their own device. **Nothing here is built in v1.**

**Target same-room, not remote.** Same-room keeps discussion verbal, needs no voice layer,
and preserves nearly every mechanic. Remote is a different product — it kills roughly a
third of the interference pool outright (Silent, Whisper, gestures, Interrogation all
assume you can see and hear each other). That's what `requiresColocation` is for: tag each
event as you author it and the v2 audit becomes a query instead of a re-read.

**Ports cleanly:** accuser-pays is *more* natural on own phones (voter identity comes free,
deleting the two-tap problem); private per-player state (Taboo, Fool, Liar's Tax) is
cleaner with private screens; the resolution function moves server-side untouched if kept
pure.

**Does not port:** the pass interstitial, hold-to-reveal, and handoff animation are the
largest v1 animation investments and solve a problem that only exists on one device —
budget a second reveal set. Turn-taking loses physical enforcement, so the optional clue
timer (§6) stops being optional. Simultaneous reveal becomes possible, which is the one
change that would make Role Swap worth reconsidering.

**Cheap now, expensive later:**
1. Keep resolution a pure function `(votes, roles, modifiers, itemUsages) → lifeDeltas`.
2. Write the local loop **as though a host authority exists** — in v2 the server takes it.
3. Word bank on the backend from day one, versioned.
4. Tag every interference event with `requiresColocation` as authored.
5. Keep Vibe Pack theme tokens data-driven, not hardcoded — v2 syncs theme across devices.

**Compliance cliff.** Photos that stay on one device are not user-generated content in any
regulatory sense. Photos transmitted between users are, triggering Apple's UGC
requirements — filtering, reporting, blocking, published terms — plus rules on images of
identifiable people on a server. **Monogram-only in networked play sidesteps all of it**,
which is the recommended v2 position and the reason §4b is scoped rather than absolute.

---

## 19. Revision history

This document is **propose-don't-patch**: changes are raised in `docs/proposals/` and
applied here only once approved. Each approved change is recorded below so a reader can see
what moved and why without reading the git log.

| Date | Change | Approval |
|---|---|---|
| 2026-08-23 | **§13b — topic-weight ceiling.** Documented the arithmetic ceiling the no-repeat window imposes (~66.7%, two draws in three), specified that the host slider **clamps** at it, and required the ceiling be derived from the enabled topic count rather than hardcoded. Corrected the **Sports Night** preset from Basketball 70 / Buhay Pinoy 30 — which was over the ceiling and would have silently delivered ~67% — to Basketball 60 / Buhay Pinoy 25 / Brands 15. The other four presets were checked against the derived ceiling and needed no change. | [proposal 0001](proposals/0001-topic-weight-ceiling.md), approved |
