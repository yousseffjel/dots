# Plan — statusbar-blocks

## Goal
Epic sub-task 7/11. Build out dwmblocks to the locked Layout A roster: seven
new block scripts, the three existing ones renumbered, and `blocks.def.h`
rewritten to the ten-row order with the systray still furthest right. New
blocks colour themselves from the `STATUS_*` names `statusbar.dcol` already
generates, so the theming engine is untouched.

## Scope
- suckless/dwmblocks/{scripts/*, blocks.def.h, Makefile}
- suckless/dwm/config.def.h — buttons[] only (approved scope expansion)
- KEYBINDINGS.md

## Allowed
- suckless/dwmblocks/, suckless/dwm/config.def.h, KEYBINDINGS.md

## Forbidden
- config/theme/, packages/, config/sxhkd/, scripts/

## Steps
1. `dwm-updates` (dnf -C, interval 3600) + `dwm-disk` (df on /, 300).
2. `dwm-temp` (/sys/class/hwmon walk, 5) + `dwm-bluetooth` (bluetoothctl, 30).
3. `dwm-brightness-block` + `dwm-mic` + `dwm-vol` — interval 0, signal-driven,
   matching sxhkdrc's RTMIN+6/7/8. + Button4/5 in dwm's buttons[] (deviation).
4. `blocks.def.h`: ten rows in the locked order; renumber cpu 1->4, ram 2->5,
   clock 3->10.
5. `Makefile`: install-scripts / uninstall-scripts name lists.
6. `KEYBINDINGS.md`: block order + per-block click actions.
7. Test: fakes for df/dnf/pamixer/bluetoothctl + a synthetic hwmon tree;
   build; lint.

## Out of scope
- Renaming the 3 existing scripts, retiring COL_*, or any `config/theme/` edit;
  battery/network/weather blocks; the queued extra.lst promotion.

## Risks
- `dwm-brightness` in ~/.local/bin would shadow the control script on PATH —
  hence `dwm-brightness-block`. Mitigate: verify no new name collides.
- Signals must move with blocks.def.h or clicks route to the wrong block.
