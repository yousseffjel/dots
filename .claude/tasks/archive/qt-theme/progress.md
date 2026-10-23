# Progress — qt-theme

## Status
`done`

## Steps
- [x] 1. desktop.lst qt5ct + qt6ct; .zshenv `QT_QPA_PLATFORMTHEME:-qt5ct`
- [x] 2. always/qt.dcol -> ${cacheDir}/qt-colors.conf (21 QPalette roles x 3 groups) + post-command; README table
- [x] 3. install-restore-theme-qt.sh: theme_write_qt_conf (identity contract); restore_theme + apply_identity call it
- [x] 4. doctor-desktop.sh: check_qt from dwm's /proc environ + the conf chain; doctor.sh wiring
- [x] 5. tests/qt-theme.sh: writer cases, template render, post-command, doctor; real Qt cross-check (compiled probe, skip if no Qt dev)
- [x] 6. Docs (DESKTOP.md § Qt apps, THEMING.md, CLAUDE.md template list), CHANGELOG
- [x] 7. Full suite + lint

## Deviations

## Blockers
