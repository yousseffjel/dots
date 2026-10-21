# Plan — display-presets

## Goal
Super+Shift+d (dwm-display) on two screens (Void VM laid out like the user's
2x1080p host, 2026-10-21): "extend" ran `--auto` on the screen already on,
resetting it to its preferred mode (VM: 1920x1080 -> 850x1001), and took the
first connected output as primary. Keep an active output's mode, honour the
real primary, and add "save this layout as a profile" (autorandr --save) so a
replug restores the arrangement (Void's udev rule runs autorandr --change).

## Scope
- config/dwm/bin/dwm-display
- tests/dwm-display.sh
- tests/dwm-display-modes.sh
- KEYBINDINGS.md
- CHANGELOG.md

## Steps
1. tests/dwm-display-modes.sh (fake xrandr/autorandr/dmenu, sealed PATH): active outputs keep their mode, inactive get --auto, primary = xrandr's primary, save prompts/validates/confirms overwrite. Fails first.
2. dwm-display: output table (name/active/primary), mode_opt, presets rebuilt on it; "all on".
3. Save entry: name prompt, [A-Za-z0-9._-] only, overwrite confirm, notify.
4. tests/dwm-display.sh expectations; KEYBINDINGS + CHANGELOG.
5. VM: extend keeps 1920x1080; save + replug restores.

## Out of scope
- Refresh-rate choice per output; per-output scaling.

## Risks
- xrandr refusing position-only changes on an active output -> VM check.
- A profile name with spaces/slashes -> rejected before autorandr sees it.
