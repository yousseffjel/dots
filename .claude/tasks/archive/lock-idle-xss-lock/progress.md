# Progress — lock-idle-xss-lock

## Status
`awaiting-commit` — audit ✅ READY, reviewer READY.

## Steps
- [x] 1. Write `config/dwm/bin/dwm-lock` — `--daemon` + lock-now + `-h`.
- [x] 2. `install-session.sh`: autostart template line + xss-lock report arm.
- [x] 3. `sxhkdrc`: live `super + l` replacing the pending block.
- [x] 4. `dwm-powermenu`: lock entry -> `dwm-lock`.
- [x] 5. `KEYBINDINGS.md`: Lock/idle section; drop "Not yet bound".
- [x] 6. Test: fakes on isolated PATH; sxhkdrc parse; lint/pkglist/build.

## Deviations

## Blockers
