#!/usr/bin/env bash
# Publishes the current tunnel URL so installed copies of the app can find the
# API (docs/12-HOSTING.md §2b).
#
# The Quick Tunnel hostname rotates on EVERY cloudflared restart. Without this
# running afterwards, every installed app is stranded until the next release —
# which is why the app never hardcodes a base URL and why this script is wired
# into startup rather than run by hand.
#
# Wire it into the WSL startup task AFTER `docker compose up -d`.
set -euo pipefail

CONTAINER="${TUNNEL_CONTAINER:-diakooi-tunnel}"
OUT="${ENDPOINT_FILE:-endpoint.json}"
# The tunnel takes a few seconds to print its hostname; polling beats a fixed
# sleep that is either too short on a cold boot or wasted on a warm one.
ATTEMPTS="${ATTEMPTS:-30}"

url=""
for _ in $(seq 1 "$ATTEMPTS"); do
  url=$(docker logs "$CONTAINER" 2>&1 \
        | grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' \
        | tail -1 || true)
  [ -n "$url" ] && break
  sleep 2
done

if [ -z "$url" ]; then
  echo "no tunnel URL found in '$CONTAINER' logs after $((ATTEMPTS * 2))s" >&2
  exit 1
fi

# Written atomically: a half-written endpoint.json fetched mid-write is a
# malformed document, and while the app tolerates that (§2c) it would disable
# network features for no reason.
tmp=$(mktemp)
printf '{\n  "apiBaseUrl": "%s",\n  "updatedAt": "%s"\n}\n' \
  "$url" "$(date -u +%FT%TZ)" > "$tmp"
mv "$tmp" "$OUT"

echo "endpoint: $url"

# Publishing step. Committing is the simplest thing that works for a beta;
# a fine-grained PAT against the contents API avoids a git identity on the
# host if that is preferred.
if [ "${PUBLISH:-1}" = "1" ]; then
  git add "$OUT"
  # `git commit` exits non-zero when nothing changed — an unrotated tunnel is
  # the normal case on a plain restart, not an error.
  if git diff --cached --quiet; then
    echo "unchanged; nothing to publish"
  else
    git commit -m "chore: update tunnel endpoint"
    git push
  fi
fi
