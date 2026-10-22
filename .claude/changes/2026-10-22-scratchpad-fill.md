# scratchpad-fill
Date: 2026-10-22
Files: 11 | Lines: +116/-12 (before this log; one new patch record)

## What changed
- `scratchpad_show_client()` (dynamicscratchpads, `Super` + `s`) now
  `resize()`s the shown window to the selected monitor's window area
  (`wx`/`wy`/`ww`/`wh`, borders inside) before `arrange()`, on every show.
  It stays floating. The dropterm and a fullscreen window are skipped.
- Record: `dwm-scratchpadfill-20261022-local.diff` + its `PATCHES.md` entry;
  `CLAUDE.md` roster 25 → 26 dwm diffs.
- `check_scratchpad_fill` in `tests/lib/dwm-runtime-floating.sh` (tag 9),
  called after `check_mouse` in `tests/dwm-runtime.sh`.
- `KEYBINDINGS.md` `Super` + `s` row; `CHANGELOG.md` [Unreleased] → Added.

## Why
Right after installing the dwm-hyprland-mouse build, the user showed a
scratchpad Alacritty stopping ~65 px short of the right edge of a 1920x1080
monitor. Read from the live session (`xwininfo`, DISPLAY=:0, read-only): the
window was floating at 1851x1043. `scratchpad_hide()` floats a window at
whatever size it has, and nothing re-placed it on show (only the dropterm
has `droptermgeom()`).

## Assumptions Made
- Type A, asked and answered: the user chose "Fill the screen, floating"
  over "join the tiling" and "centred at 90%".
- Type B: refill on every show (not only the first), like the dropterm's
  re-placement; a scratchpad dragged smaller fills again next time.

## Test coverage
- `tests/run-tests.sh` 107/107 OK; `lint.sh` passes.
- New check fails on the pre-change build (in a scratch copy): the window
  came back at 404x294 at 300,300.
- The dropterm checks and preserveonrestart's stash checks still pass.
- Reviewer: READY.

## Trade-offs
- `resize()` keeps size hints, so a terminal with size increments (xterm)
  can stop up to one cell short; Alacritty sets none, so it fills exactly.

## Next Steps
- On main after merge: rebuild dwm and `pkill -HUP -x dwm`.
- Not done: a scratchpad stashed on another monitor still cannot be shown
  from this one (`scratchpad_show()` scans `selmon->clients` only).
