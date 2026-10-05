# Progress — wallpaper-follows-display

## Status
`complete`

## Steps
- [x] 1. hook script
- [x] 2. restore_apps deploy
- [x] 3. dwm-display redraw
- [x] 4. tests
- [x] 5. docs

## Deviations
- Step 4: the redraw cases first went into tests/dwm-display.sh, which hit 273 lines (cap 250, hard stop).
  Moved them into the new hook test, renamed tests/autorandr-wallpaper-hook.sh -> tests/wallpaper-follows-display.sh
  (it now covers both halves). tests/dwm-display.sh keeps only the sandbox-HOME fix (231 lines).

## Blockers
