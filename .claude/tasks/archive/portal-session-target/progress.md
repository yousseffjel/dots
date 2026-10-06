# Progress — portal-session-target

## Status
`in-progress`

## Steps
- [x] 1. config/systemd/user/dots-session.target (BindsTo=graphical-session.target, Wants/After graphical-session-pre.target); deployed by restore_apps via deploy_app_file (copied: linking ~/.config/systemd would swallow the user's own units)
- [x] 2. session_xinitrc_template: after xinitrc.d (which imports DISPLAY into the user manager), daemon-reload + start dots-session.target, stop it on exit (trap), run dwm; no systemctl or a failed start -> plain `exec dwm` as today
- [x] 3. session_xinitrc_report: an existing ~/.xinitrc without dots-session.target gets the paste-this lines
- [x] 4. dots doctor: graphical-session.target active, and the portal answers color-scheme (gdbus ReadOne); a fix line naming the xinitrc change; skip without X / gdbus / systemctl
- [x] 5. Tests: the generated xinitrc run with fake systemctl/dwm (start before dwm, stop after, fallback), the report, the unit's content; doctor cases; symmetry covers the APP row
- [x] 6. Docs: CLAUDE.md (rule 6 xinitrc note, map), ROADMAP portal row, UNINSTALL.md, THEMING/portal notes, CHANGELOG, TESTING.md

## Deviations
- Audit: session_autostart_report (install-session-report.sh) was already 64 lines at HEAD (pre-existing 60-line-cap violation in a touched file); split mechanically at the lxpolkit boundary into session_autostart_report_more. tests/autostart-daemons.sh unchanged and green.
- Added (not in plan): docs/THEMING.md carries the paste block, held equal to session_xinitrc_report_session by tests/xinitrc-theme.sh.

## Blockers
