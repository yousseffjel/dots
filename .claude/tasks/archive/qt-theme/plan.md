# Plan — qt-theme

## Goal
Scope K slot 2: Qt5 and Qt6 apps follow the wallpaper like GTK does. qt5ct +
qt6ct; one QT_QPA_PLATFORMTHEME=qt5ct (each plugin answers both keys, probed);
an always/ template renders the colour scheme into the cache; an identity
writer points both confs at it (icons + font from theme.conf); open Qt apps
re-theme on a wallpaper change (the post-command re-places each conf).

## Scope
- packages/desktop.lst
- config/zsh/.zshenv
- config/theme/templates/always/*
- scripts/install-restore-theme*.sh, scripts/theme/theme-apply.sh, scripts/doctor*.sh
- tests/**
- docs/*.md, CHANGELOG.md, CLAUDE.md

## Allowed

## Forbidden
- scripts/install-session*.sh

## Steps
1. desktop.lst qt5ct + qt6ct; .zshenv `QT_QPA_PLATFORMTHEME:-qt5ct`
2. always/qt.dcol -> ${cacheDir}/qt-colors.conf (21 QPalette roles x 3 groups) + post-command; README table
3. install-restore-theme-qt.sh: theme_write_qt_conf (identity contract); restore_theme + apply_identity call it
4. doctor-desktop.sh: check_qt from dwm's /proc environ + the conf chain; doctor.sh wiring
5. tests/qt-theme.sh: writer cases, template render, post-command, doctor; real Qt cross-check (compiled probe, skip if no Qt dev)
6. Docs (DESKTOP.md § Qt apps, THEMING.md, CLAUDE.md template list), CHANGELOG
7. Full suite + lint

## Out of scope
- Kvantum; qt5ct `standard_dialogs=xdgdesktopportal`; fixed font (fontconfig monospace already = Cascadia)

## Risks
- the post-command touches confs the user owns — only a same-content rename of a regular file, never a symlink
- a test running apply-templates against the real HOME — sandbox all four XDG vars (memory)
- Qt5 vs Qt6 font string formats differ (10 vs 16 fields) — write each its own, probed
