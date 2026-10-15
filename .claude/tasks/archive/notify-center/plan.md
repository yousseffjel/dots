# Plan — notify-center

## Goal
macOS-style notification centre: dmenu list of dunst history at the top-right
(open / delete / clear all) + always-visible bar button (left: centre, right: focus).

## Scope
- suckless/dmenu/**
- suckless/dwmblocks/scripts/dwm-dnd
- config/dwm/bin/dwm-notify
- config/sxhkd/sxhkdrc
- packages/*.lst
- tests/*.sh
- *.md
- docs/**
- scripts/doctor-notify.sh
- .claude/**

## Forbidden
- HyDE/**

## Steps
1. dmenu: vendor xyw as a -local.diff (-x/-y/-z; negative -x from the RIGHT edge).
2. config/dwm/bin/dwm-notify: `menu` (history list via jq, newest first,
   top-right) -> per-item open|delete; `clear all`; `toggle`; `--help`.
3. dwm-dnd block: always visible (bell+count / moon FOCUS); 1=centre, 3=focus.
4. sxhkdrc: Super+Shift+n via dwm-notify toggle; Super+Ctrl+n -> centre.
5. jq: extra.lst -> desktop.lst with consequence text (mdapi-verified).
6. Tests: tests/notify-center.sh (fake dunstctl/dmenu on sealed PATH);
   update tests/blocks-info.sh DND cases; doctor text; docs + CHANGELOG.
7. Verify: build dmenu, rm config.h first; full suite + lint.

## Out of scope
- Grouping by app, per-app mute rules, history across dunst restarts.

## Risks
- dmenu geometry heavily patched (center/border) — local diff, test -x/-y live under Xvfb.
- Theming tests pkill live dunst — fakes on sealed PATH only, never real dunstctl.
- history-pop then `action` targets the right notification — verify on dev host dunst.
