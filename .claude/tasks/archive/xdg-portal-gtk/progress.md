# Progress — xdg-portal-gtk

## Status
`done`

## Steps
- [x] 1. extra.lst: xdg-desktop-portal-gtk, dconf, dbus-daemon (dbus-run-session) — names verified on mdapi f43+f44
- [x] 2. config/xdg-desktop-portal/portals.conf ([preferred] default=gtk) + symlinks.sh LINKS entry
- [x] 3. install-restore-apps.sh: apps_color_scheme — write prefer-dark via dconf only when the key is unset; private bus via dbus-run-session when there is no session bus; DCONF manifest row only when we wrote
- [x] 4. uninstall: reset each DCONF key only if it still holds the value we wrote
- [x] 5. tests: new color-scheme test with a file-backed fake dconf; symmetry sandbox gets the same fake so no real dconf is touched
- [x] 6. Docs: UNINSTALL.md, CHANGELOG, CLAUDE.md + ROADMAP portal rows

## Deviations
- Step 3: no "already set by us" branch — redundant with the unset check.
- Docs grew: ROADMAP §3 row + CLAUDE.md now record the decision reversal and correct the old XDG_CURRENT_DESKTOP claim.

## Blockers
