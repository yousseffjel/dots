# Progress — suite-host-hermetic

## Status
`in-progress`

## Steps
- [x] 1. dwm-display + wallpaper-follows-display: sealed PATH
- [x] 2. doctor-sandbox: XDG_DATA_DIRS sandboxed
- [x] 3. --help prints the whole header
- [x] 4. tests/help-header.sh
- [x] 5. Mutants + full suite on this host
- [x] 6. CHANGELOG line

## Deviations

## Blockers
- Step 1: wallpaper-follows-display.sh's `chmod 755 "$TMP/bin"/*` would chmod the REAL tools through the sealed links (stopped only by permissions) — removed; the line above it already chmods both fakes.
- Step 3: install-void.sh handles -h/--help BEFORE the install.log tee (it logged a "run" for a help request, and help-header.sh would have written into the repo's install.log). The branch in the main arg loop is gone.
- Step 4: the four other fixed-range help printers (update.sh, wallpaper.sh, theme-apply.sh, ly-theme.sh) are deliberate usage excerpts that end at a paragraph; kept, and help-header.sh now holds every fixed range to a paragraph end instead of forbidding them.
