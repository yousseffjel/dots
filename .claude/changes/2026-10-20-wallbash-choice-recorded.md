# wallbash-choice-recorded
Date: 2026-10-20
Files: 4 | Lines: +37/-1

## What changed
- `scripts/theme/theme-apply.sh`: `--wallbash` now touches `wall.set` once it has applied, so the choice is recorded where `theme_active` looks.
- `scripts/install-restore-theme-active.sh`: header notes the second writer of `wall.set`.
- `tests/theme-active.sh`: new section runs the REAL `theme-apply.sh` (engine steps stubbed, HOME/XDG/ly sandboxed, no display or bus): nord, then `--wallbash` (theme_active → `--wallbash`), then nord again (→ `nord`).
- CHANGELOG `[Unreleased]` line.

## Why
Found on the Void VM: `dots theme nord`, then `dots theme --wallbash` (Super+Shift+t → wallbash). `--wallbash` re-derived the palette from the existing wallpaper but never touched `wall.set`, so `theme.set` (nord) stayed newer and the next restore-stage re-run (`dots update`) re-applied nord, throwing away the user's choice. `theme_active` compares the two mtimes; only `wallpaper.sh` wrote `wall.set`.

## Assumptions
- Touching (not rewriting) `wall.set` is enough: its content is the current wallpaper path, which `--wallbash` did not change. Type C.

## Test coverage
- tests/theme-active.sh new section; full suite `bash tests/run-tests.sh` rc=0 (98 OK).
- Void VM: copy of ~/dots with the change overlaid — `nord rc=0 -> nord`, `--wallbash rc=0 -> --wallbash`.
- Reviewer: READY (twice).

## Follow-ups
- `scripts/theme/wallpaper.sh` sits at exactly 250 lines; split before its next edit.
