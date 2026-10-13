# Progress — keybind-remap

## Status
`in-progress`

## Steps
- [x] 1. dwm keys[] + patch records + dwm.1
- [x] 2. sxhkdrc
- [x] 3. dwm-apps launcher + test
- [x] 4. tests
- [x] 5. docs + CHANGELOG
- [x] 6. verify

## Deviations
- Added `config/applications/dots-st.desktop` + its deploy line in
  install-restore-apps.sh. Dropping dmenu_run's key left st (the no-GL fallback
  terminal) unreachable, because st ships no .desktop file and dwm-apps lists
  only .desktop entries.
- dmenucmd keeps its name (dwm.c spawn() compares against it for dmenumon)
  and now runs dwm-apps, which forwards its args to dmenu.

## Blockers
