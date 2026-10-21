# Plan — palette-missing-keys

## Goal
A palette missing a key a template uses (a hand-made or third-party
themes/<name>/colors.dcol) was rendered anyway: `#<wallbash_pry1>` reached
xresources, dwm's restart died in drw_clr_create ("cannot allocate color"),
.xinitrc ended and ly logged the user out (Void VM, 2026-10-21) — and the
broken cache would kill the next login too. Refuse such a palette before
anything is written, in apply-templates.sh and before theme-apply.sh's
identity/wallpaper steps.

## Scope
- scripts/theme/apply-templates.sh
- scripts/theme/theme-apply.sh
- tests/palette-complete.sh
- docs/THEMING.md
- CHANGELOG.md

## Steps
1. tests/palette-complete.sh (sandboxed copy, post-commands -> markers, reload/wallpaper stubs): shipped palettes pass --check; a palette without pry1/txt1 is refused naming both, nothing written, no post-command, theme-apply writes no identity.
2. apply-templates.sh: --check; every run compares template placeholders with parsed keys first, refuses on a gap.
3. theme-apply.sh: --check before apply_identity.
4. docs/THEMING.md + CHANGELOG.
5. VM: the same incomplete theme is refused and the session survives.

## Out of scope
- dwm/dmenu falling back on a bad colour (vendored drw.c; the engine is the gate).

## Risks
- A template placeholder outside [A-Za-z0-9_] -> regex pinned to the parser's.
- Test run pre-fix touching the host desktop -> copy tree, markers, stubs, no DISPLAY.
