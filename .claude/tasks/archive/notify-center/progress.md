# Progress — notify-center

## Status
`in-progress`

## Steps
- [x] 1. dmenu: vendor xyw as dmenu-xyw-<date>-local.diff (-x/-y/-z; negative -x
- [x] 2. config/dwm/bin/dwm-notify: `menu` (history list via jq, newest first,
- [x] 3. dwm-dnd block: always visible, bell+history count / moon FOCUS; BUTTON 1 ->
- [x] 4. sxhkdrc: Super+Shift+n via dwm-notify toggle; Super+Ctrl+n -> centre.
- [x] 5. jq: extra.lst -> desktop.lst with consequence text (mdapi-verified).
- [x] 6. Tests: tests/notify-center.sh (fake dunstctl/dmenu on sealed PATH);
- [x] 7. Verify: build dmenu, rm config.h first; full suite + lint.

## Deviations
- 2026-10-15 (step 2): dunst never emits ActionInvoked for a popped history
  notification (probed on a private bus: only NotificationClosed; history JSON has
  no actions). User re-decided: open = re-show + xdg-open its first `urls` link;
  in focus mode, open turns focus off first.
- 2026-10-15 (step 3): the block is polled every 5 s as well as signalled (blocks.def.h
  interval 0 -> 5) — the history count grows when a popup times out, with no signal.
- 2026-10-15 (step 4): Super+Shift+n left as the inline dunstctl+pkill — tests/blocks-info.sh
  requires each signal's pkill to sit in sxhkdrc itself. Only Super+Ctrl+n changed.

## Blockers
