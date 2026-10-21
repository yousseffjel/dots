# dwm-runtime-home
Date: 2026-10-21
Files: 2 | Lines: +27/-2

## What changed
- `tests/lib/dwm-runtime-x.sh` `start_dwm`: dwm runs with `HOME` and
  `XDG_DATA_HOME` in the test's sandbox, which holds a stand-in
  `autostart.sh` that only touches `$TMP/autostart.ran`; start fails if the
  marker never appears. Restarts (execvp) keep that environment.
- CHANGELOG [Unreleased] Fixed.

## Why
Found while preparing the multi-monitor dwm patches: the autostart patch
runs `$XDG_DATA_HOME/dwm/autostart.sh` (else `~/.local/share/dwm/`), and the
test ran dwm with the tester's HOME. This host has a real autostart.sh
(dots desktop since 2026-10-19), which starts dwm-picom, sxhkd, dwmblocks,
dwm-lock, dwm-nightlight, dwm-audiowatch … against the Xvfb display;
dwm-audiowatch talks to the real PipeWire. Today's suite runs were safe
only because slot worktrees have no built dwm and the test skipped; no
stray process with a test DISPLAY was found on the host.

## Assumptions
- none

## Test coverage
- Full suite 104 OK with dwm built in the slot, so dwm-runtime.sh really
  ran (all sections pass).
- Mutant (overrides removed) run with HOME pointed at a scratch home whose
  autostart writes REAL-AUTOSTART-RAN: the marker appeared (hazard
  reproduced) and the test failed on the missing sandbox marker. No stray
  Xvfb afterwards. Lint passed; reviewer READY.

## Follow-ups
- none
