# Plan — ly-theme

## Goal
Theme the ly login screen from the active static theme: fg = txt1,
border_fg = 1xa7 (dwm's text / selected border), bigclock = en,
hide_version_string = true. Written at install and on every static theme
switch (sudo; skipped with a notification when no prompt is possible), and
reverted to the original values by uninstall.

## Scope
- scripts/theme/ly-theme.sh
- scripts/theme/theme-apply.sh
- scripts/install-services.sh
- scripts/uninstall*.sh
- scripts/dots
- tests/*.sh
- docs/THEMING.md
- CHANGELOG.md
- CLAUDE.md

## Allowed

## Forbidden
- HyDE/
- dwm-titus/

## Steps
1. scripts/theme/ly-theme.sh: render keys in place (cp onto the file keeps
   owner, mode, SELinux label); save first originals; --restore; --dry-run.
2. Wire: services stage (install), theme-apply.sh (static switch only).
3. `dots login-theme` subcommand.
4. Uninstall step restoring the originals (before packages).
5. tests/ly-theme.sh against a real ly 1.4.0 config excerpt, sandboxed XDG.
6. Docs: THEMING.md section, CHANGELOG, CLAUDE.md map.
7. Suite + lint; verify on the VM.

## Out of scope
- Wallbash palettes (they change per wallpaper; root write per change).
- Linux VT palette (setvtrgb): truecolor is quantised to 16 colours there.

## Risks
- ly 1.5 renames keys — only keys present are written, missing ones reported.
- sudo prompt from a keybinding hangs — never prompt without a TTY (sudo -n).
