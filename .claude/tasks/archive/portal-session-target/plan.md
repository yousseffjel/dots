# Plan — portal-session-target

## Goal
Make xdg-desktop-portal start in a dwm session. Its unit (1.22.1) has
`Requisite=graphical-session.target`, which startx/ly + dwm never activates,
so every portal (Settings/color-scheme, FileChooser, ...) fails with "startup
job failed". Ship a user unit `dots-session.target` that BindsTo
graphical-session.target, started from ~/.xinitrc before dwm and stopped when
the session ends; tell existing installs what to paste (rule 6); make
`dots doctor` check that the portal actually ANSWERS.

## Scope
- config/systemd/**, scripts/install-session*.sh, scripts/install-restore-apps.sh
- scripts/doctor*.sh, tests/**, docs/**
- CLAUDE.md, CHANGELOG.md, ROADMAP.md, TESTING.md, .claude/tasks/**

## Allowed

## Forbidden
- HyDE/
- dwm-titus/

## Steps
1. config/systemd/user/dots-session.target (BindsTo=graphical-session.target, Wants/After graphical-session-pre.target); deployed by restore_apps via deploy_app_file (copied: linking ~/.config/systemd would swallow the user's own units)
2. session_xinitrc_template: after xinitrc.d (which imports DISPLAY into the user manager), daemon-reload + start dots-session.target, stop it on exit (trap), run dwm; no systemctl or a failed start -> plain `exec dwm` as today
3. session_xinitrc_report: an existing ~/.xinitrc without dots-session.target gets the paste-this lines
4. dots doctor: graphical-session.target active, and the portal answers color-scheme (gdbus ReadOne); a fix line naming the xinitrc change; skip without X / gdbus / systemctl
5. Tests: the generated xinitrc run with fake systemctl/dwm (start before dwm, stop after, fallback), the report, the unit's content; doctor cases; symmetry covers the APP row
6. Docs: CLAUDE.md (rule 6 xinitrc note, map), ROADMAP portal row, UNINSTALL.md, THEMING/portal notes, CHANGELOG, TESTING.md

## Out of scope
- Editing an existing ~/.xinitrc (rule 6); the flatpak PATH Micro

## Risks
- A killed X skips the stop -> graphical-session.target outlives the login; next start is a no-op, trap covers HUP/TERM
- doctor-session.sh at 220/250 — the new check goes in a new doctor-portal.sh
- CHANGELOG.md also edited in slot/dunst-clear-bar — trivial merge conflict
