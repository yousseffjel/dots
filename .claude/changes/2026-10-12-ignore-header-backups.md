# ignore-header-backups
Date: 2026-10-12
Files: 6 | Lines: +5 (plus this log)

## What changed
- `suckless/{dwm,st,dmenu,slock}/.gitignore` now ignore `config.h.pre-*`, and
  `suckless/dwmblocks/.gitignore` ignores `blocks.h.pre-*`.

## Why
Found while merging super-modkey + ly-theme. The full suite on main ran
`dwm-runtime.sh` against a stale in-tree dwm (binary 2026-09-28, `config.h`
2026-08, still Mod1). Running the new build-time refresh on that tree worked:
both unedited headers were set aside and regenerated, and dwm-runtime passed
again after the rebuild. But the `.pre-<timestamp>` backups showed up as
untracked files, and the 0.1.0 -> 0.2.0 migration's `.pre-0.2.0` backups
always had. `dots update` is not blocked by them (it checks with
`--untracked-files=no`); they only cluttered `git status`.

## Assumptions
- Type C: per-program .gitignore files, matching where `config.h` itself is ignored.

## Test coverage
- `git status` is clean with both live backups in the tree; `git check-ignore` matches them.
- Merged tree: run-tests 53/53 after rebuilding the stale dwm; lint clean.

## Follow-ups
- none
