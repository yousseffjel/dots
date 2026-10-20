# help-render-aligned
Date: 2026-10-20
Files: 4 | Lines: +19/-6

## What changed
- `scripts/theme/theme-apply.sh`: the `--wallbash` usage line is one line, not two; the header range `usage()` prints is 4-6 (was 3-7, which included a bare `#`).
- `scripts/theme/wallpaper.sh`: header range 4-8 (was 3-9). Edited in place; still 250 lines.
- `tests/dots-dispatch.sh`: for every subcommand in the SUBCOMMANDS table, `dots <sub> --help` must not open on a blank line, and no indented line may lack `dots <sub>` (a wrapped usage line).
- CHANGELOG `[Unreleased]` line.

## Why
Void VM edge-case pass: `dots theme --bogus` printed help whose wrapped `--wallbash` half sat four columns off. The DOTS_CMD swap renames `theme-apply.sh` to `dots theme` (4 chars shorter) but cannot move a continuation line that carries no name. Both theme and wallpaper help also began with an empty line.

## Assumptions
- Unwrapping (an 84-char header line) beats padding the swap: no rendering logic, and the test forbids wrapped usage lines for every target. Type B.

## Test coverage
- New check failed on theme + wallpaper before the fix, passes after.
- Mutants on a scratch copy (re-include the blank line in each range; re-wrap the line): 3/3 caught by the new check.
- Full suite rc=0 (98 OK); lint passed; reviewer READY.

## Follow-ups
- Same VM pass, no finding: bad theme name and `../../etc` refused; missing and non-image wallpaper refused by feh with rc=1; a wallpaper path with spaces and an apostrophe works; `dots update` with no network refuses cleanly.
