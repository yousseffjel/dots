# Plan — update-resilience

## Goal
Three follow-ups from the first VM run of wallpaper-collection: the 400 MB clone shows
git's progress instead of looking frozen; `dots update` no longer calls an install that
was interrupted (Ctrl-C) "up to date"; and a re-run of the restore stage re-applies the
theme actually in use instead of resetting it to `dark`.

## Scope
- scripts/*.sh
- scripts/theme/*.sh
- tests/*.sh
- tests/lib/*.sh
- docs/*.md
- CHANGELOG.md
- CLAUDE.md
- .claude/tasks/update-resilience/*

## Allowed
## Forbidden
- HyDE/
- dwm-titus/

## Steps
1. install-restore-wallpapers.sh: `git clone --progress` with progress to /dev/tty when a terminal is writable (install.log never sees it); quiet clone otherwise.
2. install-fedora.sh: after a full run (no --only-*, no --dry-run) finishes, `manifest_set_meta complete <commit>`; update.sh's install_is_current reads `complete` (missing = stale). Header comments of both.
3. install-restore-theme.sh: theme_initial_apply re-applies the active theme — `--wallbash` when wall.set is newer than theme.set and its image exists, else theme.set's theme, else `dark` — via a small pure helper.
4. Tests: dots-update.sh (complete meta: interrupted run is stale; --only run does not count); new test for the reapply helper (all branches, incl. missing image, missing files); clone progress path via a fake tty-less run.
5. Docs: THEMING.md (first wallpaper / re-run), README or TESTING mentions of `dots update` semantics, CHANGELOG [Unreleased] Fixed.
6. Verify: full suite, lint, mutation pass on copies.

## Out of scope
- Downscaling images in the wallpaper repo.

## Risks
- /dev/tty in CI containers is absent — probe writability first; fall back to quiet.
- Old installs have no `complete` key — treated as stale, so their next update re-runs once (intended).
- mtime ties between theme.set and wall.set — tie counts as static; documented.
