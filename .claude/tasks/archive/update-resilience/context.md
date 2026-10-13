# Context — update-resilience

## Background
User, 2026-10-13, after the VM run: "it works, add the download progress fix and the other fixes".
Offered fixes: (1) clone progress, (2) detect interrupted install. Open question from earlier:
(3) `dots update` from a session terminal resets colours to dark. Interpreted as all three (Type B, stated).

## Prior Decisions
- update.sh header: "Each install stage stamps that commit as it starts, so an install that failed partway still reads as current" — reversed here by user request (DECISION REVERSAL to record).
- wallpaper-collection: --initial only on the run that made the clone — kept.

## References
- scripts/install-fedora.sh:69-70 — exec > >(tee ...) 2>&1 (why git shows no progress).
- scripts/theme/theme-apply.sh:176-178 (theme.set), scripts/theme/wallpaper.sh (wall.set).
- VM log 2026-10-13: ^C during install stage twice, then "already up to date".

## Notes
