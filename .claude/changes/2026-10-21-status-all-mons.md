# status-all-mons
Date: 2026-10-21
Files: 9 | Lines: +270/-11 (incl. the 71-line .diff record and the new test)

## What changed
- `suckless/dwm/dwm.c`: `drawbar()` draws the status on every monitor
  (the `m == selmon` guard is gone); `updatestatus()` calls `drawbars()`;
  new `traywidth(m)` — the systray width on `systraytomon()`'s monitor, 0
  elsewhere — replaces the unconditional `getsystraywidth()` in status2d's
  `drawstatusbar()` and statuscmd's click mapping in `buttonpress()`.
- `suckless/dwm/patches/dwm-statusallmons-20261021-local.diff` + its
  PATCHES.md entry (rule 5); CLAUDE.md roster 18 → 19.
- New `tests/dwm-multimon.sh`: one 3840x1080 Xvfb screen split by
  `xrandr --setmonitor` into two RandR monitors; asserts a bar per monitor
  and pixel-identical status on both, across a selection change and a
  status update. `tests/lib/dwm-runtime-x.sh` `start_xvfb` takes
  `XVFB_SCREEN` (default unchanged).
- CI `build-suckless`: installs xrandr + xsetroot, runs the new test.
  TESTING.md entry; CHANGELOG [Unreleased] Added.

## Why
Third of the user's multi-monitor picks ("Status on every bar"). The
status (clock, volume, battery, notification button) was drawn only on
the selected monitor and jumped with the pointer.

## Assumptions
- Type B: the tray keeps following the selected monitor (systraypinning
  0 unchanged). Alternative: pin it to the first monitor — a separate
  preference, not asked for.

## Test coverage
- Test failed before the change (status on one bar); passes after.
- Mutants on a rebuilt copy, 3/3 caught: the selmon guard restored,
  updatestatus back to drawbar(selmon), traywidth = getsystraywidth()
  everywhere (the 1 px shift breaks pixel identity).
- tests/dwm-runtime.sh still passes on the patched build; full suite 105
  OK with dwm built; lint passed; reviewer READY.
- Debugged on the way: awk compares a gsub-modified field as a string
  ("22" < "100" is false) — `h + 0`.
- Not yet on the VM: its session is behind the idle lock; rebuild + check
  with the user's next login.

## Follow-ups
- VM check after login (status on both Virtual-1 and Virtual-2 bars).
- Last multi-monitor pick: windows return on replug.
