# Plan — theme-change-lock

## Goal
Two wallpaper/theme changes at once (Super+w pressed twice; autorandr's hook
during a manual change) interleave: on the Void VM (2026-10-20) the second
wallpaper stayed on screen with the first one's palette, written last. Only
reload.sh is locked. Serialise each whole change (wallpaper.sh,
theme-apply.sh) under `flock -o`, so the last one started leaves a matching
wallpaper and palette, and no daemon a change starts ever holds the lock.

## Scope
- scripts/theme/theme-lock.sh
- scripts/theme/wallpaper.sh
- scripts/theme/theme-apply.sh
- tests/theme-lock.sh
- CHANGELOG.md
- CLAUDE.md
- docs/THEMING.md

## Allowed

## Forbidden

## Steps
1. scripts/theme/theme-lock.sh: sourced with the caller's path + args; re-runs it under `flock -o -w ${DOTS_THEME_LOCK_WAIT:-60} -E 75`; DOTS_THEME_LOCKED marks the re-run and is unset there; unlocked without flock
2. wallpaper.sh (2 lines, stays <= 250) and theme-apply.sh source it before any work
3. tests/theme-lock.sh: no interleave, exit status passed through, marker not inherited, a detached child does not hold the lock, timeout -> 75 + message, no flock -> runs; both entry points source it
4. CHANGELOG; CLAUDE.md map; THEMING.md if it describes locking
5. VM: two concurrent `dots wallpaper --random` -> palette matches the final wallpaper

## Out of scope
- reload.sh's own lock (kept: reload.sh is also run alone)

## Risks
- Lock fd leaking into dwmblocks (reload.sh's documented failure) — `-o`, tested with a detached child
