# Context — polish-bundle

## Background
Scope G slot 1 (main: `.claude/tasks/scope-g-release-0.2.0.md`, decision 2).

## Prior Decisions
- dwm-lib-xdg.sh: xdg_dir NAME fallback; $HOME answer = fallback.
- Rule 6: the report may only print; .xinitrc is user-owned.
- Memory: changelog-line-per-slot; installer-test-sandbox-xdg.

## References
- scripts/install-session-report.sh session_xinitrc_report / _session
- scripts/doctor-session.sh daemon_applies / check_daemons
- scripts/theme/wallpaper.sh:23,72; wallpaper-default.sh WALL_DIR (cache)

## Notes
- The MASTER_PLAN queue strike is main-side: do it in the post-merge sync.
