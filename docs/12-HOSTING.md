# Hosting & Infrastructure

Self-hosted on an always-on home server, reached through Cloudflare Tunnel for the public
API and Tailscale for everything private.

**Nothing in this document is needed before Phase 7.** Phases 1–6 build a fully offline
game; the app must start and finish a game with no network at all. Set this up when you
reach Phase 7, or earlier as a learning exercise — but it blocks nothing.

---

## 1. The server

| | |
|---|---|
| Host | `desktop-gklhcri` |
| OS | **Windows 11 25H2** |
| Tailscale IP | `100.122.239.125` |
| Tailscale account | `ecocharge123@gmail.com` |
| Role | Postgres · API · admin console · cloudflared |

### 1a. Windows is the complication

Every hosting instruction elsewhere in these docs assumes a Linux Docker host. Windows
works, but three things bite:

**Docker Desktop needs an interactive login.** It does not run as a service by default, so
after an unattended reboot the stack stays down until someone logs into the desktop. That
defeats the entire point of an always-on server.

**Windows Update reboots on its own schedule.** "This PC will never turn off" is an
intention, not a configuration. Updates will restart it, usually at the worst time.

**Filesystem performance across the WSL boundary is poor.** Postgres data on an NTFS bind
mount through `/mnt/c/` is dramatically slower than a native Linux volume, and file-watch
events are unreliable.

### 1b. Recommended: Docker Engine inside WSL2, not Docker Desktop

```powershell
wsl --install -d Ubuntu
wsl --set-default-version 2
```

Inside the Ubuntu shell:

```bash
# Docker Engine directly — no Docker Desktop dependency
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER

# systemd so containers restart without a desktop session
sudo tee /etc/wsl.conf > /dev/null <<'EOF'
[boot]
systemd=true
EOF
```

Then from PowerShell, `wsl --shutdown` and reopen. Verify `systemctl status docker` shows
active-enabled.

**Keep all project files inside the WSL filesystem** (`~/diakooi`), never under `/mnt/c/`.
Clone the repo there. Named Docker volumes then live on ext4 and Postgres behaves.

### 1c. Surviving reboots

Three layers, all required:

**WSL auto-start.** Task Scheduler → new task → trigger *At startup*, run whether user is
logged on or not, action `wsl.exe -d Ubuntu -u root -e /bin/bash -c "service docker start"`.
Without this, WSL sits idle until someone opens a terminal.

**Container restart policy.** Every service already carries `restart: unless-stopped` in
`docker-compose.yml`. That covers container crashes, not host reboots — the WSL task above
is what covers those.

**Windows Update.** Set active hours to your whole waking day, and set the target release
to defer feature updates. You cannot stop updates entirely on Win 11 Home, so **assume
reboots happen** and verify the whole stack returns unattended. Test it: reboot the machine
and walk away, then check from your phone an hour later.

---

## 2. Domains — what's actually free

Cloudflare gives away a great deal. **Domains are not among them.**

| Surface | Hosting | Domain | Cost |
|---|---|---|---|
| Public site | Cloudflare Pages | `diakooi.pages.dev` | **Free** |
| Public API | Home server + Tunnel | Quick Tunnel for beta (§2a) | **Free**, URL rotates |
| Admin console | Home server, Tailscale only | none needed | Free |
| Postgres | Home server, Tailscale only | none needed | Free |

**Why the API needs a domain.** Cloudflare Tunnel has two modes:

- **Quick Tunnel** — zero config, no account, no domain. Gives a random
  `*.trycloudflare.com` hostname that **changes on every restart**, and Cloudflare
  documents it as unsuitable for production. Fine for showing someone a demo. Useless as
  an endpoint a shipped app calls.
- **Named Tunnel** — stable hostname on a zone you control. Survives restarts. Requires a
  domain on Cloudflare DNS.

An app that hardcodes an API URL cannot use a URL that rotates. So: buy a domain.

**Cheapest viable options**
- `.xyz`, `.stream`, `.top` — roughly $2–5/year at registration
- Cloudflare Registrar sells at wholesale with no markup, but **only for domains already
  transferred in** — you register elsewhere first, then transfer
- A `.ph` domain is more expensive but reads better for a Filipino product

**Suggested layout** (assuming `diakooi.xyz`):

| Hostname | Points to | Exposure |
|---|---|---|
| `diakooi.xyz` | Cloudflare Pages | Public |
| *(beta)* `*.trycloudflare.com` | Quick Tunnel → server `:3000` | Public, rotates on restart |
| *(later)* `api.diakooi.xyz` | Named Tunnel → server `:3000` | Public, stable |
| `admin` | **Tailscale only** — `http://100.122.239.125:3001` | Private |
| Postgres | **Tailscale only** — `100.122.239.125:5432` | Private |

Note the admin console gets **no DNS record at all.** Not a subdomain, not a wildcard. It
is reachable only by tailnet IP.

### 2a. Decision: Quick Tunnel for beta

**v1 beta runs on a Quick Tunnel. No domain purchased yet.** The caveats are understood and
accepted: the `*.trycloudflare.com` hostname rotates on every `cloudflared` restart, and
Cloudflare documents it as unsuitable for production.

This is workable *only* because of §2b. Read it before writing any networking code.

Upgrade trigger — buy a domain and switch to a Named Tunnel when **any** of these is true:
- The app is on the Play Store (not internal testing)
- Feedback volume makes GitHub issues impractical
- Word-bank updates need to reach users who won't reinstall
- More than about 20 people are running the app

Switching later is a config change, not a rewrite, provided §2b is followed from day one.

### 2b. Endpoint discovery — the pattern that makes this survivable

**The app must never hardcode an API URL.** A rotating hostname is fine; a rotating
hostname baked into a shipped APK is a dead app.

Instead, the app resolves its endpoint at runtime from a **stable, free location**:

```
1. App starts
2. Fetches  https://raw.githubusercontent.com/Shaloh69/<repo>/main/endpoint.json
3. Reads    { "apiBaseUrl": "https://random-words-here.trycloudflare.com",
              "updatedAt": "2026-08-22T10:14:00Z" }
4. Caches it locally with a short TTL
5. On ANY failure — offline, 404, timeout, malformed — falls back to bundled
   content and disables network features silently
```

`raw.githubusercontent.com` is free, permanent, and already yours. Cloudflare Pages
(`diakooi.pages.dev/endpoint.json`) works equally well and is closer to the eventual
production shape.

**Server side**, whenever `cloudflared` starts, publish the new URL:

```bash
#!/usr/bin/env bash
# scripts/publish-endpoint.sh — run after cloudflared starts
set -euo pipefail

URL=$(docker logs diakooi-tunnel 2>&1       | grep -oE 'https://[a-z-]+\.trycloudflare\.com' | tail -1)

[ -z "$URL" ] && { echo "no tunnel URL found" >&2; exit 1; }

jq -n --arg url "$URL" --arg ts "$(date -u +%FT%TZ)"    '{apiBaseUrl:$url, updatedAt:$ts}' > endpoint.json

# Commit and push, or PUT via the GitHub contents API with a fine-grained PAT
git add endpoint.json
git commit -m "chore: update tunnel endpoint" && git push
```

Wire it into the WSL startup task so it runs after `docker compose up -d`.

**Why this is worth doing now rather than later:** it is roughly thirty lines, and it makes
the eventual domain purchase a one-line edit to `endpoint.json` with zero app changes and
no forced update. Without it, every URL rotation strands every installed copy.

### 2c. What the app must tolerate

The offline-first rule (`01-DESIGN.md` §16) already covers this, but a rotating endpoint
makes it load-bearing rather than theoretical:

| Situation | Required behaviour |
|---|---|
| `endpoint.json` unreachable | Use bundled word bank, disable feedback. **No error dialog** |
| Endpoint resolves but API is down | Same. Queue feedback locally, retry later |
| Tunnel rotated mid-session | Session unaffected — nothing mid-game touches the network |
| First launch, no network ever | Full game playable. This is the A4 airplane-mode test |

**No network call may block starting or finishing a game.** With a Quick Tunnel the API is
genuinely unreliable by construction, so this stops being a nice principle and becomes the
thing keeping the app usable.

---

## 3. Topology

```
                    Internet
                       │
         ┌─────────────┴─────────────┐
         │                           │
   Cloudflare Pages          Cloudflare Tunnel
   diakooi.pages.dev         api.diakooi.xyz
   (static site)                     │
                                     │ outbound-only
                                     │ no inbound ports
                    ┌────────────────┴────────────────┐
                    │   desktop-gklhcri (Win 11)      │
                    │   └── WSL2 Ubuntu               │
                    │       └── Docker                │
                    │           ├── cloudflared       │
                    │           ├── api      :3000 ───┘
                    │           ├── admin    :3001  ── Tailscale only
                    │           └── postgres :5432  ── Tailscale only
                    └─────────────────────────────────┘
                                     │
                              Tailscale (100.122.239.125)
                                     │
                          your laptop / phone / teammates
```

**The tunnel makes no inbound connection.** `cloudflared` dials out to Cloudflare's edge
and holds the connection open, so no router port is forwarded and your home IP is never
published. That is the entire security argument for this design.

---

## 4. Security rules

**Never Tailscale Funnel the admin console.** Funnel publishes a tailnet service to the
open internet — the exact opposite of what's wanted. The console must be *unreachable*, not
password-protected. Auth on it is defence in depth; the tailnet binding is the real control.

**Never route the admin console or Postgres through the tunnel.** `cloudflared` config
lists the API hostname and nothing else. A wildcard ingress rule here would silently
publish everything.

**Bind private services to the Tailscale interface only**, not `0.0.0.0`:

```yaml
ports:
  - "127.0.0.1:3000:3000"          # API — tunnel reaches it locally
  - "100.122.239.125:3001:3001"    # admin — tailnet only
  - "100.122.239.125:5432:5432"    # postgres — tailnet only
```

**Verify from outside, not by inspection.** From mobile data with Tailscale off:
```bash
curl -m 5 https://<current-tunnel>/v1/health    # expect 200
curl -m 5 http://<your-public-ip>:3001          # expect timeout
curl -m 5 http://<your-public-ip>:5432          # expect timeout
nmap -Pn <your-public-ip>                       # expect nothing open
```
A7's audit gates on this. Reading the config file is not the same as proving it.

---

## 5. Backups

Every backup story is fiction until a restore has been performed. `docker compose down -v`
destroys named volumes with no confirmation.

```bash
# In WSL. Cron via systemd timer, or Windows Task Scheduler calling wsl.exe
docker exec diakooi-postgres pg_dump -U diakooi diakooi \
  | gzip \
  | age -r <your-age-public-key> \
  > ~/backups/diakooi-$(date +%F).sql.gz.age
```

- **Encrypt before it leaves the box.**
- **Ship it off-box.** A backup on the same disk as the database is not a backup. Sync to
  a cheap object store or a second machine on the tailnet.
- **Test the restore quarterly**: rebuild into a clean container and diff row counts. The
  admin console's Settings page surfaces `last verified restore`, not `last backup`,
  precisely because the second number is misleading on its own.
- Retain 7 daily, 4 weekly, 6 monthly.

---

## 6. What this host does NOT do

| | Why |
|---|---|
| Serve the public site | Cloudflare Pages. ISP downtime must never take down the shopfront |
| Store selfies | They never leave the device. Not a hosting decision — see `01-DESIGN.md` §4b |
| Serve Vibe Pack audio | Bundled in the APK. Offline-first, and licences are per-build |
| Anything the game needs to play | The app is fully offline. This server is optional infrastructure |

That last row is the one to keep in mind. If this PC dies, nobody's game stops.

---

## 7. Setup order

Do this at Phase 7, not now.

```
[ ] WSL2 + Ubuntu installed, systemd enabled
[ ] Docker Engine in WSL (not Docker Desktop)
[ ] Repo cloned INSIDE the WSL filesystem, not /mnt/c/
[ ] Task Scheduler auto-start verified across a real reboot
[ ] Windows Update active hours configured; reboot survival tested unattended
[ ] Quick Tunnel running (no domain needed for beta — §2a)
[ ] scripts/publish-endpoint.sh wired into WSL startup, AFTER docker compose up
[ ] endpoint.json published and fetchable from a clean device
[ ] App verified to fall back silently when endpoint.json is unreachable
[ ] LATER: domain purchased, Named Tunnel created, ingress lists API hostname ONLY
[ ] Tailscale installed in WSL, or host Tailscale IP bound explicitly
[ ] docker compose up -d; all services healthy
[ ] pg_dump timer + off-box sync + one tested restore
[ ] External verification from mobile data with Tailscale OFF (§4)
[ ] ADR recording the WSL2 decision and the domain choice
```
