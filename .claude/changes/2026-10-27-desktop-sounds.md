# desktop-sounds
Date: 2026-10-27 (code 2026-10-23, WIP handoff 0b4c283; finished on a Void dev host)
Files: 33 | Lines: +770/-49 (code, docs, tests, scope K planning files, task folder; plus this log)

## What changed
- `config/dwm/bin/dwm-sound` (new): `<event>` plays one freedesktop sound-theme
  file through pw-play, looked up under `$XDG_DATA_HOME` then `$XDG_DATA_DIRS`
  (a user file replaces a stock one). `--login` is the login chime, once per
  session, retrying while PipeWire starts. `off`/`on`/`status` is the one switch,
  and `--file` serves dots doctor. One sound per event at a time (`flock -n`).
  Off, no pw-play or no audio server all exit 0.
- `config/dwm/bin/dwm-sound-notify` (new): the script of dunst's `[dots_sound]`
  rule. CRITICAL plays dialog-warning, NORMAL message-new-instant, LOW nothing.
- `config/dwm/bin/dwm-lib-session.sh` (new, sourced): `session_key` lifted
  out of dwm-xdg-autostart, plus `session_once`. dwm-xdg-autostart sources it.
- dunst: `always_run_script = false` and the `[dots_sound]` rule, in both
  `config/dunst/dunstrc` and `always/dunst.dcol` (tests/dunst-reload.sh holds
  them identical).
- Hooks: the sxhkd raise/lower keys tick; dwm-screenshot plays a shutter, and
  its confirmations are now `-u low`, so a shot makes one sound.
- Rule 6, all three places, for `dwm-sound --login`. doctor-daemons treats it
  as a one-shot. `check_sounds` in doctor-desktop.sh covers off, no pw-play,
  no theme and a dunstrc that predates the rule.
- `packages/desktop.lst`: `sound-theme-freedesktop`, with its consequence text.
- Docs: `docs/DESKTOP.md` § Sounds, KEYBINDINGS (the tick), CHANGELOG, and
  CLAUDE.md's bin list.
- Review fixes (2026-10-27): `--file` takes only event names, and the
  `--delay` countdown notification is low, so a delayed shot makes one sound.
- Unrelated test fixes, found because this dev host is Void, not Arch:
  `tests/gtk3-adwaita-dark-shim.sh` ran `gresource list | grep -q` under
  pipefail, so the SIGPIPE (141) read as "not in libgtk-3". The resource is
  there (gtk+3-3.24.52_1). `tests/doctor.sh`'s "not Void" case set
  `RELEASE=""`, which falls back to the real /etc/os-release (Void here). It
  now points at an `ID=arch` file.

## Why
Scope K slot 4. The user chose pw-play plus sound-theme-freedesktop. The
dunst 1.13.2 probes are in the task's context.md: a rule script runs only when
a notification is SHOWN, and the shipped `set-paused true` holds critical ones
too, so focus mode is silent for free. `always_run_script = true` re-ran the
script for a notification already on screen when the pause lifted, giving a
duplicate sound.

## Assumptions
- Type B: no logout sound, since the audio server dies with the session. No
  per-event switches and no GUI toggle (plan, out of scope).
- Type B: the tick plays at the volume limit too (100% or 0%), as on other desktops.

## Test coverage
- `tests/desktop-sounds.sh` (new, 32 checks; pw-play always a fake, sealed
  PATH), doctor cases in `tests/lib/doctor-cases-desktop.sh`, plus additions to
  dunst-reload, dwm-screenshot and autostart-daemons.
- Full suite on the Void host: everything passes after the two test fixes
  above and a local `make -C suckless/dwm` (the checkout left dwm.c newer
  than the built binary). shellcheck 0.11.0 clean. shfmt 3.13.0 (no 3.13.1 on
  PyPI) flags only wallpaper.sh and uninstall_steps.sh, both untouched here
  and both version skew. markdownlint not run (no node on this host), so CI
  runs it.
- Audit ✅ READY; reviewer READY (two findings fixed, one rejected with
  reasons, in review.md). Both new checks were mutation-checked.

## Follow-ups
- VM proof for scope K slots 1-4: hear the chime once (not again after
  `dots wallpaper --random`), a notification, the tick, the shutter, and
  silence in focus mode.
- CLAUDE.md still calls the dev host Arch; this machine is Void.
- Next: scope K slot 5 `idle-dim`.
