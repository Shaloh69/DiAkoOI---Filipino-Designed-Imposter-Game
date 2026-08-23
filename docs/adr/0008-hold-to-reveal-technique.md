# ADR 0008 — Hold-to-reveal blur: technique, and what the spike could not measure

**Status:** Accepted, with a device measurement outstanding · **Date:** 2026-08-23

## Context

Hold-to-reveal is the core interaction of the entire game (`01-DESIGN.md` §6b): a blur
clearing under a thumb press. `06-TESTING-STRATEGY.md` §8b flags it as the single largest
performance risk on the reference device and says to prototype it **in Phase 3, not Phase
5** — finding a problem in Phase 5 means reworking the interaction the product is built
around.

The reference device is a **Mali-G615 MC2 — a two-core GPU** — driving a 6.77" 1080p panel
on LPDDR4X bandwidth (`06-TESTING-STRATEGY.md` §8). `BackdropFilter` and blurred
`ImageFiltered` are among the most expensive operations available on a mobile GPU and scale
with surface area.

## Decision

**Make the technique a config value, not a hardcoded choice**, and default to the cheapest
one that is visually near-identical.

`RevealSurface` takes a `RevealTechnique`:

| Technique | Mechanism | §8b option |
|---|---|---|
| `liveBackdropFilter` | `BackdropFilter` re-blurring the live subtree every frame | the baseline being de-risked |
| **`prerenderedCrossFade`** (default) | blur rendered once behind a `RepaintBoundary`, animation drives opacity only | **option 1** |
| `downscaledBlur` | blur a half-resolution surface, scale up | option 2 |

Switching is a one-line change at the call site, so an on-device A/B costs minutes rather
than a rework. Rive-driven dissolve (option 3) is deliberately **not** implemented here: it
needs an artefact that does not exist yet, and adding a dependency to de-risk a cost we have
not measured would be premature.

Reduced motion (`03-VIBE-SYSTEM.md` §6) forces `prerenderedCrossFade` regardless of the
configured technique — animating a per-frame filter is the opposite of reduced motion. The
palette still applies; theme and motion are independent.

## What the spike measured, and what it does not prove

**This is the part that matters.** A widget test has no GPU and no raster cache, so it
**cannot** rank these techniques by cost. The mechanism that makes the cross-fade cheap — a
`RepaintBoundary` layer being cached and re-composited rather than re-filtered — does not
exist in the harness to be observed.

### A first attempt produced a misleading result, and is recorded so it is not repeated

The initial spike tried to prove cost by counting how many times the child subtree painted
across a hold. It returned:

```
live backdrop filter    31 paints
prerendered cross-fade  61 paints
```

Read naively that says the cross-fade is twice as expensive. It is not. The cross-fade
paints its child **twice per frame by construction** — once clear, once blurred — while
doing strictly less *filtering*. The number is real; it measures paint calls, and paint
calls are not the cost driver. Filter evaluations are.

That assertion is now kept in the suite **with its meaning attached**, in a group named
"what this harness cannot determine", precisely so nobody rediscovers the number later and
draws the wrong conclusion from it.

### What the spike does establish — true on any GPU

| Fact | Technique | Why it matters |
|---|---|---|
| Reads back the backdrop | `liveBackdropFilter` only | The read-back is the expensive part |
| Blur sigma **changes every frame** | `liveBackdropFilter`, `downscaledBlur` | A filter whose parameters change must be re-evaluated every frame, on any hardware |
| Blur sigma **constant across the hold** | `prerenderedCrossFade` | Constant parameters are what make the layer cacheable at all |
| Filtered copy isolated behind a `RepaintBoundary` | `prerenderedCrossFade` | Necessary for caching. **Necessary, not sufficient** — whether the cache is hit needs a GPU |
| No filter applied at full reveal | all three | Filtering at sigma 0 is pure cost for no visual effect |

These are structural preconditions, and they are the strongest claim available without the
handset. **No millisecond figure is produced anywhere in the spike, deliberately.** A
guessed frame time that later proves wrong is worse than an acknowledged gap, because it
gets treated as evidence.

## What still requires the physical handset

None of the following is determinable from this machine. Each needs the V60 Lite 5G, in
**default** performance mode (not performance mode — players will not change it), with
**Extended RAM enabled**, which is the shipping default (`06-TESTING-STRATEGY.md` §8d).

1. **Frame time for each technique during a sustained hold**, at the real card size on the
   1080p panel. This is the number the 120Hz-vs-60Hz decision hangs on.
2. **Whether `prerenderedCrossFade` holds 8.3ms.** If it does, the 120Hz target stands and
   no fallback is needed.
3. **Whether `liveBackdropFilter` holds 8.3ms.** If it does, the higher-fidelity option is
   available and the default can be reconsidered.
4. **Whether `downscaledBlur` at 0.5 is visually acceptable** at arm's length on a 6.77"
   panel. Blur radius is perceptual and resolution is not — but that has a limit, and where
   it sits is an eye judgement, not a calculation.
5. **Thermal behaviour across ten rounds.** §8c: profile warm, not cold. A technique that
   holds budget for thirty seconds and not for fifteen minutes has not passed.
6. **Whether paging interacts with it.** §8d: a page fault into Extended RAM is a UFS read.
   Resuming a backgrounded game may stutter on the first frames regardless of technique.

**Suggested order:** measure 2 first. If `prerenderedCrossFade` holds 8.3ms, the decision is
made and 3–4 are optional polish. Only if it fails does the ladder in §8b matter.

## Consequences

- **The 120Hz vs 60Hz decision stays open**, and this ADR is the evidence it was waiting
  for — which means it is still waiting, because the decisive measurement needs hardware.
  That is the honest position. `BLOCKED.md` carries it.
- The frame target is a **single config value**, `FrameBudget`, defaulting to 120Hz / 8.3ms
  and flagged provisional. The assumption is never scattered.
- Primitives depend on `RevealSurface`, not on a specific technique, so the Phase 5
  animation pass can switch without touching them.
- If all three techniques fail on device, option 4 (cap to 60Hz) doubles the budget to
  16.6ms and is the escape hatch of last resort — noted in §8a as legitimate but visibly
  less premium on a 120Hz panel.

## Alternatives considered

**Hardcode `BackdropFilter` and measure in Phase 5.** Explicitly what §8b says not to do.

**Ship Rive now as insurance.** Adds a dependency and an art pipeline to hedge a cost that
has not been measured. Rive remains the right answer if the blur genuinely cannot hold
budget — it is in the ladder for that reason — but reaching for it first inverts the order.

**Produce estimated frame times from desktop measurements.** Rejected outright. A desktop
GPU tells you nothing about a Mali-G615 MC2, and a number with a caveat attached is still a
number people will quote without the caveat.
