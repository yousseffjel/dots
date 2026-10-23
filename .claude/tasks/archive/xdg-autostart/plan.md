# Plan — xdg-autostart

## Goal
Scope K slot 3: apps that asked to start at login (~/.config/autostart, the
"start at login" toggles) start in a dwm session. `dwm-xdg-autostart` runs dex
once per session (dwm re-runs autostart.sh on every restart, i.e. every
wallpaper change), per entry (one malformed file aborts a whole `dex -a`),
skipping X-GNOME-Autostart-enabled=false (dex ignores it). User dir only (A1).

## Scope
- config/dwm/bin/*, packages/desktop.lst
- scripts/install-session-template-applets.sh, scripts/install-session-report-applets.sh
- scripts/doctor-daemons.sh
- tests/**
- docs/*.md, CHANGELOG.md, CLAUDE.md, KEYBINDINGS.md

## Allowed

## Forbidden
- scripts/install-session-template.sh

## Steps
1. desktop.lst `dex` + consequence
2. config/dwm/bin/dwm-xdg-autostart: session guard (bus address, else dwm pid+starttime), per-entry dex, --list, --force
3. Rule 6 three places: template-applets launch line, report-applets paste line, DAEMONS in tests/autostart-daemons.sh; doctor one-shot
4. tests/xdg-autostart.sh: fake dex (guard, per-entry isolation, disabled, --list/--force, no dex/dir) + real dex leg
5. Docs: DESKTOP.md § Autostart apps; CHANGELOG; CLAUDE.md bin list
6. Full suite + lint

## Out of scope
- /etc/xdg/autostart (A1); deduplicating a user entry for a daemon autostart.sh already starts (documented)

## Risks
- relaunch on every wallpaper change — the session guard, tested with a dwm restart (same key)
- a dwm-* name shadowed by ~/.local/bin (memory) — check the name is free
