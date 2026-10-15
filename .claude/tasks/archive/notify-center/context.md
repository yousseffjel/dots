# Context — notify-center

## Background
User request 2026-10-15: focus-mode switch button + macOS-like notification list
(dmenu, top-right) with open / delete / clear all.

## Prior Decisions
- User answers 2026-10-15: xyw patch for top-right; left=centre right=focus;
  open = re-show + run default action; jq moves to desktop.lst.
- DND = `dunstctl set-paused` (existing Super+Shift+n, block signal 12).

## References
- https://tools.suckless.org/dmenu/patches/xyw/ (dmenu-xyw-5.2.diff)
- suckless/dwmblocks/scripts/dwm-dnd, scripts/doctor-notify.sh, tests/blocks-info.sh

## Notes
- dunst 1.13.2 on dev host; `dunstctl history` is JSON aa{sv}.
- Upstream xyw does not apply over center+border; negative -x upstream means off-screen left.
