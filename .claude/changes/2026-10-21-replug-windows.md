# replug-windows
Date: 2026-10-21
Files: 8 | Lines: +443/-9 (incl. the 200-line .diff record)

## What changed
- `suckless/dwm/dwm.c`:
  - Client gains a home (`hashome`, home geometry, `homeview`, floating
    `homefx/homefy`); Monitor gains `fresh` and `homeview`.
  - `sethomes()` runs from `updategeom()` only when the monitor COUNT
    changes, and gives every client not already away its monitor's
    geometry, view and position.
  - `restorehomes()` runs from `configurenotify()` after `updatebars()`. It
    moves each client whose home geometry is a monitor again back to it,
    keeping its tags (and a floating one's spot), clears the home, and
    views the returning windows' tag on a monitor the hotplug created.
  - `sendmon()` clears the home.
  - preserveonrestart's `_DWM_CLIENT_INFO` is 15 values (home appended);
    7 still read.
- `suckless/dwm/patches/dwm-replug-20261021-local.diff` + PATCHES.md
  entry, appended note on the preserveonrestart entry; roster 19 → 20.
- `tests/dwm-multimon.sh`: unplug/replug of the right monitor (Xvfb screen
  shrunk via an added RandR mode = the root ConfigureNotify of a real
  unplug). Covers a tiled window on tag 2, a floating one (shown and
  clamped while away), the left window staying, and a second cycle on
  tag 3 with a `restart_dwm` in the middle.
- TESTING.md, ci.yml comment, CHANGELOG [Unreleased] Added.

## Why
Last of the user's multi-monitor picks ("Windows return on replug"). Seen
on the VM earlier today: unplugging Virtual-2 moved its windows to
Virtual-1, and replugging left Virtual-2 empty.

## Assumptions
- Type B: identity by geometry, because dwm reuses Monitor structs by
  index (unplugging the LEFT screen gives struct 0 the right's geometry).
  Alternative: per-struct identity — wrong in exactly that case.
- Type B: homes recorded only on a count change, so a resolution change
  never strands a home.
- Type B: a window moved by hand while away loses its home.

## Test coverage
- The test failed on stock dwm (the window stayed at x=0 after replug).
- Mutants on a rebuilt copy, all caught after the test was strengthened
  (initial survivors: floating position, clear-on-match): no
  restorehomes, no sethomes, no floating restore, no view restore, no
  clear-on-match, no home load after restart. Not testable here: the
  sendmon clear (no third monitor in Xvfb).
- 3/3 stable reruns; dwm-runtime.sh (preserveonrestart record format)
  passes; full suite 105 OK; lint; reviewer READY.
- Debugged on the way: dwm's configurerequest adds the monitor origin to
  a floating window's requested x; focus-follows-mouse decides which
  window a key acts on.
- Not yet on the VM (idle lock up); rebuild + check with the next login.

## Follow-ups
- VM check after login: status on both bars; unplug/replug Virtual-2 via
  virt-viewer (Display 2 off/on) returns its windows.
