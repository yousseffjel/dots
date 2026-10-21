# Context — theme-lock-scope

## Background
Host edge-case pass 2026-10-21: with the lock held, `dots theme --list` exited
75 after DOTS_THEME_LOCK_WAIT. config/dwm/bin/dwm-theme runs `theme-apply.sh
--list` to build its dmenu. wallpaper.sh --select runs dmenu after the lock is
taken (theme-lock.sh is sourced before the case on $1).

## Prior Decisions
- theme-change-lock (2026-10-20): flock -o re-run, exit 75, DOTS_THEME_LOCK_WAIT.

## References
- scripts/theme/theme-lock.sh, tests/theme-lock.sh, config/dwm/bin/dwm-theme

## Notes
- wallpaper.sh was exactly 250 lines (cap) — split first.
