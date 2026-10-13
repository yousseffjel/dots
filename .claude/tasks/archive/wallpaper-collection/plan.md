# Plan — wallpaper-collection

## Goal
Ship the user's wallpaper collection (github.com/yousseffjel/wallpaper) with dots without
committing any image: the restore stage shallow-clones it into the wallpaper dir, re-runs
(so `dots update`) fast-forward it, uninstall removes it only while untouched, and a fresh
install opens on a random wallpaper from it instead of the generated gradient; optionally a new random one at every login.

## Scope
- scripts/*.sh
- scripts/theme/wallpaper.sh
- tests/*.sh
- docs/*.md
- themes/dark/wallpapers/README.md
- CHANGELOG.md
- CLAUDE.md
- .claude/tasks/wallpaper-collection/*

## Allowed
## Forbidden
- HyDE/
- dwm-titus/

## Steps
1. install-restore-wallpapers.sh: clone `$DOTS_WALLPAPER_REPO` (default the GitHub URL, empty = off) --depth=1 into `<pictures>/wallpapers/dots`; ff-pull our own clone on re-run; leave a foreign dir alone; WALLPAPERS manifest row; --dry-run; never aborts. Source it from install-restore.sh.
2. uninstall-wallpapers.sh: remove the clone only if it is ours (row + origin URL), clean (no untracked/modified) and has no local commits; rmdir parent only if we created it. Wire into uninstall.sh.
3. wallpaper.sh `--initial` (random from the collection; quiet exit 0 when absent) and `--login-random on|off|status` (flag file ~/.config/dots/random-wallpaper; default off).
4. .xinitrc: first login runs `dots wallpaper --initial` after `dots theme dark`; every login with the flag set runs `dots wallpaper --random` (timeout) instead of ~/.fehbg. Same for install-restore-theme.sh's initial apply; existing .xinitrc files get paste lines via session_xinitrc_report + THEMING.md.
5. Tests: new tests/wallpaper-collection.sh (local fixture repo: clone, idempotent pull, foreign dir, dirty/clean uninstall, dry-run); update install-uninstall-symmetry.sh + xinitrc-theme.sh (and any test that runs restore) to use a fixture, never the network.
6. Docs: THEMING.md, UNINSTALL.md, themes/dark/wallpapers/README.md, CHANGELOG [Unreleased], CLAUDE.md map.
7. Verify (DEVIATION: + colorgen.sh shrinks before -kmeans, user-approved — see progress.md): full suite, shellcheck/shfmt via tests/lint.sh, a sandboxed real-network dry-run + one real clone in a sandbox HOME.

## Out of scope
- Committing images to dots; a submodule; the wallpaper repo itself; `dots doctor` checks.

## Risks
- ~410 MB download at install — documented; DOTS_WALLPAPER_REPO= disables it.
- Tests hitting GitHub — every restore-running test pins DOTS_WALLPAPER_REPO to a local fixture.
- Uninstall deleting user-added images — clean-tree check counts untracked files.
- Login delay: colour extraction on 8K-16K images — measure colorgen.sh on the largest file in step 7.
