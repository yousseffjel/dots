# Progress — wallpaper-collection

## Status
`review-passed`

## Steps
- [x] 1. install-restore-wallpapers.sh + wiring
- [x] 2. uninstall-wallpapers.sh + wiring
- [x] 3. wallpaper.sh --initial
- [x] 4. first wallpaper at install / first login
- [x] 5. tests
- [x] 6. docs
- [x] 7. verify

## Deviations
- Step 4: the initial random pick in install-restore-theme.sh runs only when this run made a fresh clone (WALLPAPERS_CLONED) — theme_initial_apply runs on every restore with a DISPLAY, `dots update` included, and must not swap the wallpaper on an update.
- Step 4: the existing-.xinitrc paste lines live in wallpaper.sh (`--login-random on` prints them), not session_xinitrc_report — install-session-report.sh is at 244 lines, and the hint matters only once the option is turned on.
- Step 5: tests/lib/install-symmetry.sh (outside the tests/*.sh glob) gained the wallpaper fixture; the shared in_sandbox covers symmetry + wallpaper-follows-display.

- Step 7: colorgen.sh took 58-62 s on the 16K image (17 s on the 8K WebP) — login time with --login-random on. User chose (AskUserQuestion) to shrink inside colorgen: analyse a <=1920x1080 copy. Measured 61.7 s -> 3.7 s, palettes within 1-7 points per channel. Adds scripts/theme/colorgen.sh to scope.

## Blockers
