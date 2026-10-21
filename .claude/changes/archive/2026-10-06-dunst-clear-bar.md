# dunst-clear-bar
Date: 2026-10-06
Files: 3 | Lines: +9/-2

## What changed
- `offset = (12, 12)` -> `(12, 36)` in config/dunst/dunstrc and config/theme/templates/always/dunst.dcol (kept in lockstep), with a comment tying y to dwm's bar height.
- CHANGELOG Unreleased/Fixed entry.

## Why
The Fedora 44 VM screenshot showed notifications ("Theme applied") drawn over the dwm top bar's status text. dwm's bar is `drw->fonts->h + 2` (~21px with the size=10 font in config.def.h); the old y offset of 12 sat inside it. 36 = bar + the existing 12px gap.

## Assumptions
- Type B: a fixed offset rather than runtime detection — dunst has no X11 workarea/bar avoidance. If the bar font grows, the comment says to raise y.

## Test coverage
- tests/run-tests.sh: 0 failures; tests/lint.sh passed. Visual check on the VM pending (user-run sed + notify-send).
- Reviewer: READY.

## Follow-ups
- Confirm placement on the VM.
