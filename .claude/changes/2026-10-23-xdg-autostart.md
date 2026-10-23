# xdg-autostart
Date: 2026-10-23
Files: 15 | Lines: +412/-7 (code, docs, tests, task folder and state; plus this log)

## What changed
- `config/dwm/bin/dwm-xdg-autostart` (new): runs every `~/.config/autostart`
  entry through dex (`dex -a -s <a dir holding that one entry>`), once per
  session, and skips `X-GNOME-Autostart-enabled=false` (only in
  `[Desktop Entry]`). `--list` (dex `-d`) and `--force`. The session key is
  `DBUS_SESSION_BUS_ADDRESS`, falling back to dwm's PID + stat start time,
  stored in `$XDG_RUNTIME_DIR/dots/xdg-autostart.session`.
- `packages/desktop.lst`: `dex`, with its consequence text.
- Rule 6, all three places: the launch line in
  `install-session-template-applets.sh`, the paste line in
  `install-session-report-applets.sh`, and the name in
  `tests/autostart-daemons.sh`. `scripts/doctor-daemons.sh` treats it as a
  one-shot (`DAEMON_PROCESS` ""), like xdg-user-dirs-update.
- `tests/xdg-autostart.sh` (new, 19 checks). Docs: `docs/DESKTOP.md`
  § Autostart apps, a CHANGELOG line, and the CLAUDE.md bin list.

## Why
Scope K item 3. An app's "start at login" switch writes
`~/.config/autostart`, and nothing in a dwm session read it. Probing the Void
`dex-0.10.1_1` package (python3, run on the dev host) changed the design from
"`dex -a` at login" (assumption A1) to what is above:
- dex ignores `X-GNOME-Autostart-enabled=false`, so an app the user had
  turned off started anyway;
- one non-boolean `Hidden=` raises ValueError and ends the whole `-a` run;
- dwm runs autostart.sh as `system("autostart.sh &")` (dwm.c
  runautostart), so `$PPID` is a short-lived sh; and a restart is execvp,
  which keeps the PID, the start time and the environment. Without a guard,
  every wallpaper change (reload.sh SIGHUPs dwm) would relaunch every app.
A1's rule itself (user directory only) stands.

## Assumptions
- Type B, refining A1: dex per entry plus the two additions above. The
  alternative was a shell `.desktop` runner of our own, which would have to
  reimplement Exec unquoting and field codes. Rejected.
- Type B: a user entry duplicating a daemon autostart.sh already starts
  is not deduplicated; DESKTOP.md says so.

## Test coverage
- `tests/xdg-autostart.sh`: isolation, the GNOME key and its group scope, the
  session guard (same bus / new bus / no bus with a PID+start-time key and
  a recycled PID), `--force`, `--list`, no dex, no directory, and a bad
  argument. A real-dex leg runs where dex is installed (not here, not CI).
- The real dex 0.10.1 end to end (the Void `.xbps` through a throwaway
  wrapper, not committed): `alpha` and `zulu` started, `broken` was reported
  by name, the GNOME-off and GNOME-only entries were skipped, and a second run
  started nothing.
- Five mutations on a copy, each caught by its own checks (whole-dir dex, GNOME
  key ignored, no guard, PID without start time, key read from any group).
- `tests/dwm-help.sh` caught the first `--help` (no usage line): fixed. Full
  suite exit 0, lint passed, audit ✅ READY, reviewer READY.

## Follow-ups
- On a real session: enable an app's "start at login", log in again, and
  check it starts once (and not again after `dots wallpaper --random`).
- Next: scope K slot 4 `desktop-sounds`, stacked on `slot/xdg-autostart`. It
  may lift `session_key` into a shared dwm-lib for the login sound.
