# Progress — laptop-power

## Status
`in-progress`

## Steps
- [x] 1. laptop.lst
- [x] 2. drivers_power
- [x] 3. dwm-power
- [x] 4. key + powermenu
- [x] 5. doctor
- [x] 6. tests
- [x] 7. docs + VM

## Deviations
- scripts/uninstall_steps.sh + new tests/uninstall-services.sh (outside Scope):
  the slot's SERVICE rows exposed that uninstall_services red-fails on a unit
  removed with its package.
- KEYBINDINGS.md section placed under "### Lock and idle"'s sibling level after
  dwm-keys.sh failed on the first placement.
- VM: real gdbus prints the same ServiceUnknown error the fake copies;
  dwm-power available/get rc 1, menu notifies and opens no dmenu.

## Blockers
