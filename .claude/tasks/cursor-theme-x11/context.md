# Context — cursor-theme-x11

## Background
User report 2026-10-07: cursor changes between Firefox and the dwm wallpaper.
Root cause: install-restore-theme-identity.sh writes cursor only to GTK formats.
libXcursor (dwm, st, alacritty, root window) reads Xcursor.theme, XCURSOR_THEME
or icons/default/index.theme — none set. User chose A+B.

## Prior Decisions
- rule 6: .xinitrc is user-owned once it exists — report paste lines instead.
- theme identity writers: no-clobber, manifest THEME rows, CLOBBER=1 on switch.
