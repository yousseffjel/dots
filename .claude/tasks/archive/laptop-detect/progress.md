# Progress — laptop-detect

## Status
`in-progress`

## Steps
- [x] 1. drivers_chassis
- [x] 2. laptop.lst + gated install
- [x] 3. doctor chassis + list skip
- [x] 4. dwm-brightness backlight
- [x] 5. tests
- [x] 6. docs
- [x] 7. VM

## Deviations
- Slots 1+2 of scope-h merged (RECLASSIFICATION announced in chat).

- Files outside plan Scope: tests/blocks-audio.sh (BL label cases),
  tests/lib/dwm-brightness-backlight.sh (250-line split of dwm-brightness.sh).
- Plan risk said "fall back to gamma" when brightnessctl cannot set; built
  as an explicit error instead, because `get` would keep reading the
  backlight and the two would disagree. Tested.

## Blockers
