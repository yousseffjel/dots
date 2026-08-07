# Progress — statusbar-blocks

## Status
`awaiting-commit` — audit ✅ READY, reviewer READY.

## Steps
- [x] 1. `dwm-updates` (dnf -C, 3600) + `dwm-disk` (df on /, 300).
- [x] 2. `dwm-temp` (hwmon walk, 5) + `dwm-bluetooth` (bluetoothctl, 30).
- [x] 3. `dwm-brightness-block` + `dwm-mic` + `dwm-vol` — interval 0.
- [x] 4. `blocks.def.h`: ten rows; renumber cpu 1->4, ram 2->5, clock 3->10.
- [x] 5. `Makefile`: install-scripts / uninstall-scripts name lists.
- [x] 6. `KEYBINDINGS.md`: block order + click actions.
- [x] 7. Test: fakes + synthetic hwmon; build; lint.

## Deviations

**Step 3 — `suckless/dwm/config.def.h` moved from Forbidden into Scope.**
Surfaced before writing `dwm-vol`, resolved by the user in-session.

The scope file's locked block table gives block 8 "scroll -> +/-5%", but dwm
binds `ClkStatusText` for Button1/2/3 only — Button4/Button5 never reach
`sigstatusbar`, so a scroll on the bar is discarded before any block sees it.
Two rows in `buttons[]` fix it for every block, not just vol.

Offered as (a) drop scroll and leave volume on the XF86Audio keys, or (b)
expand scope. The user chose (b), accepting the consequence: **this now
requires a dwm rebuild**, not just a dwmblocks one, so existing installs need
the `rm -f config.h` staleness handling that sub-task 3 established. Recorded
here rather than absorbed silently, since it changes what the task ships.

## Blockers
