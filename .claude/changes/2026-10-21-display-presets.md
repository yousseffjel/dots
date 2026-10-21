# display-presets
Date: 2026-10-21
Files: 7 | Lines: +269/-24

## What changed
- `config/dwm/bin/dwm-display` (Super+Shift+d): `outputs()` now reports
  "name active primary" per connected output. `on()` emits `--output X` for
  an active output and `--output X --auto` only for one that is off, so no
  preset resets the mode of a screen in use. Presets are built around the
  output xrandr marks primary (first connected only as a fallback).
  "all on (auto)" is now "all on".
- New last entry "save this layout as a profile" (only with autorandr):
  dmenu name prompt offering existing profiles, name restricted to
  `^[A-Za-z0-9][A-Za-z0-9._-]*$`, an existing name needs "yes" to an
  overwrite prompt (`autorandr --save NAME --force`), Escape saves nothing,
  success is announced with notify-send.
- New `tests/dwm-display-modes.sh` (sealed PATH fakes for xrandr,
  autorandr, a queue-driven dmenu, notify-send); `tests/dwm-display.sh`
  expectations updated.
- KEYBINDINGS.md, docs/HARDWARE.md, CHANGELOG [Unreleased] Added + Fixed.

## Why
The user runs two 1920x1080 screens and asked for multi-monitor work.
On the Void VM laid out the same way, "extend" ran `--auto` on the
already-active screen and reset it to its preferred mode (1920x1080 became
850x1001, twice); on real hardware that undoes a hand-picked mode or
refresh rate. Taking the first connected output as primary moved the
primary flag. Saving a layout was a manual `autorandr --save` documented in
HARDWARE.md; the user picked "Save layout as profile" from the
multi-monitor options.

## Assumptions
- Type B: an active output's mode is the user's choice and must survive
  every preset; only inactive outputs get `--auto`. Alternative: always
  `--auto` (old behaviour) — rejected, it is the bug.
- Type B: profile names limited to letters, digits, `. _ -`, not starting
  with `.`/`-`, since autorandr makes a directory of the name.

## Test coverage
- tests/dwm-display-modes.sh written first, failed, now passes; 9/9 mutants
  caught (active check both ways, primary, --force, regex, confirm prompt,
  save entry, awk geometry column, notify).
- Full suite: 103 OK. Lint passed. Reviewer: READY.
- VM (Void, QXL, 2×1920x1080): extend kept both at 1920x1080; save created
  a profile; with Virtual-2 switched off, `autorandr --change` (what Void's
  udev rule runs) restored the two-screen layout. Test profile removed.

## Follow-ups
- Remaining multi-monitor slots the user chose: this-monitor capture,
  status on every bar, windows return on replug.
