## What & why

<!-- One or two sentences. Link the issue if there is one. -->

## Phase

<!-- e.g. Phase 3 — Vibe Packs. Or "content" / "fix" / "docs" -->

## Audit results

<!-- Paste the actual audit output from docs/05-IMPLEMENTATION-PLAN.md.
     A phase is done when its audit passes, not when its code exists.
     Delete this section for content or docs PRs. -->

```
```

## Checklist

- [ ] `flutter analyze` clean / lint clean
- [ ] Tests added or updated; full suite green
- [ ] No selfie touches disk or network
- [ ] No hardcoded colour, duration, radius, or spacing
- [ ] No Flutter import in `app/lib/engine/`
- [ ] Golden diffs reviewed individually, not bulk-approved
- [ ] Any bundled audio has a complete `licence.json`
- [ ] Non-obvious decisions recorded as an ADR in `docs/adr/`
- [ ] `docs/01-DESIGN.md` unchanged (or the rule change was agreed in an issue first)
