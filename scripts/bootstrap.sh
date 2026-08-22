#!/usr/bin/env bash
# DiAkoOi — first-time repo setup.
# Run once from the repository root, then hand Phase 0 to Claude Code.
set -euo pipefail

echo "── DiAkoOi bootstrap ──────────────────────────────────────────"

if [ ! -f CLAUDE.md ]; then
  echo "ERROR: run this from the repository root." >&2
  exit 1
fi

# 1. Git
if [ ! -d .git ]; then
  git init -b main
  echo "✓ git initialised on main"
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin \
    https://github.com/Shaloh69/DiAkoOI---Filipino-Designed-Imposter-Game.git
  echo "✓ remote 'origin' added"
else
  echo "· remote 'origin' already set: $(git remote get-url origin)"
fi

# 2. Environment
if [ ! -f .env ]; then
  cp .env.example .env
  echo "✓ .env created from .env.example — EDIT IT before docker compose up"
else
  echo "· .env already exists, left alone"
fi

# 3. Sanity checks
echo
echo "── Toolchain ──────────────────────────────────────────────────"
for tool in git flutter node pnpm docker; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf "  ✓ %-8s %s\n" "$tool" "$(command -v $tool)"
  else
    printf "  ✗ %-8s NOT FOUND\n" "$tool"
  fi
done

echo
echo "── Next steps ─────────────────────────────────────────────────"
cat <<'NEXT'
  1. Edit .env  (POSTGRES_PASSWORD at minimum)
  2. git add -A && git commit -m "chore: initial specification"
  3. git push -u origin main
  4. Open Claude Code and paste the Phase 0 prompt from docs/08-PROMPTS.md §2

  Still owed by a human before Phase 0 completes:
    · confirm Vivo V60 Lite variant/chipset  (Settings > About)
    · decide 120Hz/8.3ms vs capped 60Hz/16.6ms frame target
    · run docs/10-TRADEMARK-SEARCH.md        (~40 min, blocks Phase 8)
    · decide telemetry yes/no                (blocks Phase 7)
NEXT
