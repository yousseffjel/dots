# scratchpad-follow
Date: 2026-10-22
Files: 8 | Lines: +81/-40 (code + docs; plus this log and state)

## What changed
- `scratchpad_show()` (dwm.c): "showing" now means visible on the FOCUSED
  monitor. A member visible there → every member is stashed. Otherwise every
  member, stashed or left shown on another monitor or an unviewed tag, is
  gathered to this monitor's view and laid out as before.
- `dwm-scratchpadgroup-20261022-local.diff` regenerated against the same
  base; dated note appended to its PATCHES.md entry (also correcting that
  entry's test-file name: `dwm-runtime-scratchpad.sh`, not `-floating.sh`).
- KEYBINDINGS.md's two show/hide bullets and the [Unreleased] CHANGELOG
  line (same unreleased feature) say "on this monitor".
- Tests: `check_scratchpad_group` shows the set on tag 9, views tag 8, and
  expects Super+s to bring all three; `tests/dwm-multimon.sh` shows one on
  the left and expects Super+s on the right to bring it there.

## Why
User report right after installing scratchpad-group: a scratchpad shown on
tag 8 of monitor 1 did not appear when Super+s was pressed on tag 3 of
monitor 2 — the press hid it, because it was still visible on monitor 1.
Reading the code found the second case: a member shown, then left behind
on an unviewed tag, was in neither branch (not visible, not stashed).

## Assumptions Made
- Type B: a press on a monitor where the set is not showing MOVES members
  shown elsewhere here (gather, the user's earlier choice), rather than
  hiding them there or mirroring.
- Type B: hiding stashes every member everywhere, so the next press always
  brings the full set.

## Test coverage
- `tests/run-tests.sh` all OK; lint passes; reviewer READY.
- Old `scratchpad_show` built in a scratch copy: both new checks FAIL (tag 8
  showed 0 of 3; the left-shown window did not follow to the right).

## Next Steps
- Merge, rebuild, `pkill -HUP -x dwm`, and try the reported case.
