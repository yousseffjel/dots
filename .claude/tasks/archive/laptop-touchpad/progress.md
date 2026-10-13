# Progress — laptop-touchpad

## Status
`in-progress`

## Steps
- [x] 1. snippet
- [x] 2. drivers-laptop.sh
- [x] 3. uninstall-sysfiles
- [x] 4. doctor
- [x] 5. tests
- [x] 6. docs
- [x] 7. VM

## Deviations
- tests/lib/drivers-cases-laptop.sh (new, 250-line split of drivers-cases) and
  tests/lib/doctor-sandbox.sh (DOTS_XORG_CONF_DIR + cmp sealed) — outside plan Scope.
- Preview shown to the user used MatchDriver; built with Driver (told the user why).
- Step 7 VM: Xorg 1.21.1.24 parsed the snippet (no parse error; session up);
  only (EE) lines are fbdev/vesa, identical in the previous session's log.

## Blockers
