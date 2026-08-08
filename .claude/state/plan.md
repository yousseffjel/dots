# Plan — picom-autostart

## Goal
Nothing launches picom. It is packaged, configured, themed and tuned by the
roster Epic's sub-task 10, but appears in no autostart path, so that tuning
has never run. Add it to the `autostart.sh` template and to the missing-line
report for user-owned files, and lock the two together with a test.

## Scope
- scripts/install-session.sh
- KEYBINDINGS.md, docs/THEMING.md
- tests/**

## Allowed
- scripts/install-session.sh
- KEYBINDINGS.md, docs/THEMING.md
- tests/

## Forbidden
- config/picom/picom.conf and config/theme/templates/always/picom.dcol —
  the compositor's settings are sub-task 10's and are not in question here
- scripts/install-suckless.sh, packages/*.lst, suckless/**

## Steps
1. Add a guarded picom launch to the `autostart.sh` heredoc, first, so the
   compositor is up before anything draws.
2. Add the matching picom branch to `session_autostart_report`, and update
   the dry-run summary line to name it.
3. Add `tests/autostart-daemons.sh`: every daemon launched by the heredoc
   must also have a report branch, and vice versa.
4. Document it — the user-owned `autostart.sh` caveat in KEYBINDINGS.md and
   a THEMING.md note that the tuned config only applies once picom runs.

## Out of scope
- Changing any picom setting; `unredir-if-possible`, shadows and vsync were
  settled in sub-task 10.
- dunst, which needs no line — D-Bus activates it on the first notification.

## Risks
- picom cannot be launched here to prove it: this host is Wayland, and
  starting it would composite over the live session. Verify by construction.
- `autostart.sh` is user-owned once it exists (CLAUDE.md rule 6) — the
  installer must never edit it, only report the missing line.
