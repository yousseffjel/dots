# Plan — cursor-theme-x11

## Goal
The cursor theme in theme.conf reaches only GTK (settings.ini, xsettingsd), so the
root window, dwm bar and non-GTK clients show the default X cursor while Firefox
shows Bibata. Render cursor_theme/cursor_size into (A) the XDG "default" cursor
theme ~/.local/share/icons/default/index.theme and (B) Xcursor.theme/Xcursor.size
X resources, on install and on every theme switch, manifest-claimed, no-clobber.

## Scope
- scripts/install-restore-theme-identity.sh
- scripts/install-restore-theme.sh
- scripts/theme/theme-apply.sh
- scripts/theme/reload.sh
- scripts/install-session.sh
- scripts/install-session-report.sh
- scripts/doctor-session.sh
- docs/THEMING.md
- tests/*.sh

## Allowed
## Forbidden
- HyDE/
- dwm-titus/

## Steps
1. Writers: theme_write_cursor_index (A) + theme_write_xcursor_resources (B, ~/.cache/dots/theme/xcursor) in the identity file, same no-clobber/manifest contract
2. Call both from install-restore-theme.sh and theme-apply.sh apply_identity
3. Merge the xcursor file: reload.sh (before dwm HUP), .xinitrc template, existing-.xinitrc report lines + THEMING.md
4. dots doctor: X resource Xcursor.theme matches theme.conf (asks X, not the file)
5. Tests: new tests/cursor-x11.sh (writers, clobber, uninstall); update xinitrc-theme.sh expectations
6. Verify: bash -n, shellcheck, tests/run-tests.sh; then audit + reviewer

## Out of scope
- dwm source changes; Xcursor for Wayland; a dpi= key

## Risks
- uninstall leaves icons/default/ dir — check uninstall-theme removes only the file, rmdir empty parent
- reload.sh at 235 lines — keep the addition small or split
- xrdb cpp quirks (no apostrophes / slash-star) in the generated file
