# Plan — xsettingsd-theming

## Goal
Run an XSETTINGS daemon so GTK apps read Xft DPI/antialias/hinting and the
theme.conf identity from one place, and a future second theme needs no rework.
Scope C sub-task 2 — read its locked decision 2 before starting.

## Scope
- packages/desktop.lst
- scripts/install-restore-theme.sh
- scripts/install-session*.sh
- scripts/theme/reload.sh
- tests/autostart-daemons.sh
- docs/THEMING.md
- CLAUDE.md

## Allowed

## Forbidden
- config/theme/templates/
- scripts/global_fn.sh

## Steps
1. Declare `xsettingsd` in `desktop.lst` with its consequence comment.
2. Verify the xsettingsd.conf key/quoting format against the shipped man page.
3. `theme_write_xsettingsd_conf` in install-restore-theme.sh — sibling of
   `theme_write_gtk_ini`, same no-clobber + manifest rules; wire into restore.
4. Re-measure the 250-line cap; split at the predicates/writers seam if over.
5. `reload_xsettingsd` (SIGHUP) in reload.sh + add to the parallel step list.
6. Autostart line in install-session.sh + its paired report branch; bump
   tests/autostart-daemons.sh 6 -> 7 and confirm it still RUNS both sides.
7. docs/THEMING.md + CLAUDE.md; full suite + `tests/lint.sh --strict`.

## Out of scope
- A `.dcol` template (locked decision 2); sub-tasks 3 and 4.

## Risks
- install-restore-theme.sh is 223 and the gtk_ini sibling is ~35 lines, so it
  likely crosses 250 — step 4 exists for that; split per old queue item 1.
- `pkill -HUP xsettingsd` matches system-wide; any test must shim pkill on PATH.
