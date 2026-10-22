# scratchpad-group
Date: 2026-10-22
Files: 13 | Lines: +596/-197 (before this log; one new test lib, one new record, one retired)

## What changed
- `Super` + `s` toggles the whole scratchpad set (Hyprland special-workspace
  style). `Client.isscratchpad` marks members: set by `Super` + `Shift` + `s`
  (never for the dropterm), cleared by `Super` + `=`. Any member showing on
  any monitor → every showing member is stashed. Otherwise every stashed
  member, from every monitor, moves to the focused monitor's view and is
  laid out master + stack by `scratchpad_layout()`: one fills the area under
  the bar, the first of several takes the left half, the rest share the
  right half top to bottom. Floating; the first is focused.
- The one-at-a-time cycle (`scratchpad_last_showed` and three helpers,
  `unmanage()`'s pointer clear) is removed.
- preserveonrestart's record: value 17 = membership; a 7/15/16-value record
  infers it from `SCRATCHPAD_MASK` (not the dropterm).
- Records: `dwm-scratchpadgroup-20261022-local.diff` + PATCHES.md entry;
  `dwm-scratchpadfill-20261022-local.diff` retired (its fill is the n = 1
  case); dated notes appended to the dropterm and dynamicscratchpads
  entries. KEYBINDINGS.md scratchpad section rewritten, CHANGELOG
  [Unreleased] entry replaced (fill → group, both unreleased), CLAUDE.md
  roster, TESTING.md multimon entry appended.
- Tests: new `tests/lib/dwm-runtime-scratchpad.sh` (`check_scratchpad_group`
  replaces `check_scratchpad_fill`); gather check at the end of
  `tests/dwm-multimon.sh`.

## Why
After scratchpad-fill the user found `Super` + `s` showed one stashed window
per press, cycling; they wanted every scratchpad shown together side by side.

## Assumptions Made
- Type A, asked and answered: layout "Master + stack, like tiling" (over
  columns-then-grid, all columns); "gather to this monitor" (over per
  monitor).
- Type B: master width is half the area, not the tag's mfact.
- Type B: hiding stashes every showing member on every monitor; the next
  press shows them all on the focused one.
- Type B: the dropterm is out of the set (it has `Super` + `grave`).

## Test coverage
- `tests/run-tests.sh` 107/107 OK; lint passes; reviewer READY.
- Mutants built in fresh temp dirs: the pre-change build fails the group,
  dropterm and restart checks; no value 17 fails the restart check; no
  cross-monitor gather fails the multimon check.
- The gather check passed that mutant twice before it was fixed: the pointer
  never selected the right monitor (a move inside the window under it sends
  dwm nothing), and a hidden window (negative x) read as on the left.

## Next Steps
- On main after merge: rebuild, `pkill -HUP -x dwm`. Windows stashed by the
  running build stay members across that restart (inferred from the mask).
