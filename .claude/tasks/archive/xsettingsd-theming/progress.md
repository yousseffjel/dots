# Progress — xsettingsd-theming

## Status
`complete` — audit ✅ READY, reviewer READY. Awaiting /test + /commit.

## Steps
- [x] 1. Declare `xsettingsd` in `desktop.lst` with its consequence comment.
- [x] 2. Verify the xsettingsd.conf key/quoting format against the shipped man page.
- [x] 3. `theme_write_xsettingsd_conf` in install-restore-theme.sh — sibling of `theme_write_gtk_ini`, same no-clobber + manifest rules; wire into restore.
- [x] 4. Re-measure the 250-line cap; split at the predicates/writers seam if over.
- [x] 5. `reload_xsettingsd` (SIGHUP) in reload.sh + add to the parallel step list.
- [x] 6. Autostart line in install-session.sh + its paired report branch; bump tests/autostart-daemons.sh 6 -> 7 and confirm it still RUNS both sides.
- [x] 7. docs/THEMING.md + CLAUDE.md; full suite + `tests/lint.sh --strict`.

## Deviations

## Blockers
