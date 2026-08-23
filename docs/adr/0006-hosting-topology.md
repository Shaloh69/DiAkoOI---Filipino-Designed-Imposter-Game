# ADR 0006 — Hosting topology

**Status:** Accepted · **Date:** 2026-08-23

Full detail in `docs/12-HOSTING.md`. This records the decisions and why.

## Context

The API, admin console and Postgres are self-hosted on an always-on home machine
(`desktop-gklhcri`, Windows 11 25H2). The public site is static. Nothing the game needs to
play is served from any of it — the app is offline-first, so this is optional
infrastructure (`CLAUDE.md` §Hard rules).

## Decisions

| Surface | Choice |
|---|---|
| Container host | **WSL2 + Docker Engine**, not Docker Desktop |
| Public API | **Cloudflare Quick Tunnel** for beta, with runtime endpoint discovery |
| Admin console | **Tailscale only** — no DNS record at all |
| Postgres | **Tailscale only** |
| Public site | **Cloudflare Pages** |

### WSL2 + Docker Engine, not Docker Desktop

Docker Desktop does not run as a service by default and needs an interactive login, so
after an unattended reboot the whole stack stays down until somebody logs into the desktop.
That defeats the point of an always-on server. Docker Engine inside WSL2 with `systemd=true`
starts without a desktop session.

Project files live **inside** the WSL filesystem, never under `/mnt/c/`: Postgres data on an
NTFS bind mount is dramatically slower and file-watch events are unreliable.

### Quick Tunnel for beta, and the consequence that matters

A Named Tunnel needs a domain, which costs money and is not yet justified. The Quick Tunnel
is free and needs no account — but its `*.trycloudflare.com` hostname **rotates on every
`cloudflared` restart**.

That is only survivable because the app never hardcodes an API URL. It resolves the base URL
at runtime from a stable, free location (`endpoint.json` on `raw.githubusercontent.com` or
Cloudflare Pages), caches it briefly, and **falls back silently to bundled content on any
failure** — offline, 404, timeout, malformed. No error dialog; a rotating endpoint must be
invisible to a player.

Server side, `scripts/publish-endpoint.sh` scrapes the new URL from the cloudflared logs
after startup and publishes it.

**Upgrade trigger** — buy a domain and switch to a Named Tunnel when any of: the app is on
the Play Store proper; feedback volume outgrows GitHub issues; word-bank updates must reach
users who won't reinstall; or more than roughly 20 people are running the app. Switching is
then a one-line `endpoint.json` edit with zero app changes and no forced update — *provided*
the discovery pattern is followed from day one.

### Tailscale for private services, never Funnel

The admin console gets **no DNS record**. It is reachable only by tailnet IP. Tailscale
Funnel publishes a tailnet service to the open internet, which is the exact opposite of what
is wanted — the console must be *unreachable*, not merely password-protected. Auth on it is
defence in depth; the tailnet binding is the real control.

The tunnel's ingress lists the API hostname and nothing else. A wildcard rule there would
silently publish everything.

### Cloudflare Pages for the public site

ISP downtime must never take down the shopfront, which is the release vehicle while there is
no store presence.

## Consequences

- **The API endpoint is unstable by construction during beta.** This turns the offline-first
  rule from a principle into the thing keeping the app usable, and makes A4's airplane-mode
  test load-bearing rather than a formality.
- Verification must be **external**: from mobile data with Tailscale off, not by reading the
  config. A7 gates on this and it needs a human on an outside network.
- The host is Windows, so reboots happen on Windows Update's schedule. Reboot survival is
  tested unattended, not assumed.
- `docker compose down -v` destroys named volumes silently. Backups are encrypted before
  leaving the box, shipped off-box, and **restore-tested** — the admin console surfaces
  `last verified restore`, not `last backup`.

## Alternatives rejected

**Docker Desktop on Windows.** Simpler to install, but the interactive-login requirement is
disqualifying for an always-on host.

**Buying a domain now.** ~$2–5/year is not the obstacle; the endpoint-discovery pattern is
needed regardless for silent offline fallback, and once it exists the domain becomes a
config change. Deferring costs nothing and the trigger conditions are written down.

**Hosting the public site on the home server.** Rejected: ISP downtime would take down the
shopfront and the API together.
