# Plan — xdg-portal-gtk

## Goal
Install xdg-desktop-portal-gtk, select it with a portals.conf (no
XDG_CURRENT_DESKTOP in a dwm session, so nothing else would), and set the
'prefer dark' colour scheme the gtk portal serves to libadwaita/Firefox/
Chromium/Electron. User chose "package + dark pref", uninstall must undo it.

## Scope
- packages/extra.lst, config/xdg-desktop-portal/**, scripts/symlinks.sh
- scripts/install-restore-apps.sh, scripts/uninstall-apps.sh, scripts/uninstall.sh
- tests/**, docs/**, CLAUDE.md, CHANGELOG.md, ROADMAP.md, .claude/tasks/xdg-portal-gtk/**

## Allowed

## Forbidden
- HyDE/
- dwm-titus/

## Steps
1. extra.lst: xdg-desktop-portal-gtk, dconf, dbus-daemon (dbus-run-session) — names verified on mdapi f43+f44
2. config/xdg-desktop-portal/portals.conf ([preferred] default=gtk) + symlinks.sh LINKS entry
3. install-restore-apps.sh: apps_color_scheme — write prefer-dark via dconf only when the key is unset; private bus via dbus-run-session when there is no session bus; DCONF manifest row only when we wrote
4. uninstall: reset each DCONF key only if it still holds the value we wrote
5. tests: new color-scheme test with a file-backed fake dconf; symmetry sandbox gets the same fake so no real dconf is touched
6. Docs: UNINSTALL.md, CHANGELOG, CLAUDE.md + ROADMAP portal rows

## Out of scope
- GTK4 settings.ini (gtk-application-prefer-dark-theme)
- Changing the xfconf pass to use dbus-run-session

## Risks
- dconf write to the REAL session bus from a test — every test path puts a fake dconf first on PATH; symmetry sentinel
- portal start-up delay if no backend matches — portals.conf names gtk explicitly
