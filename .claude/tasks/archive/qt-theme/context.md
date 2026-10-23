# Context — qt-theme

## Background
Scope K decision 2 (qt5ct + qt6ct, colours from the wallpaper).

## Prior Decisions
- always/ README: three target styles; cache + app-reads-it is the alacritty style.
- Identity writers: no-clobber (theme_identity_may_write); only a switch replaces ours.

## References
- Probed on the dev host (qt5ct 1.9, qt6ct 0.11, compiled Qt5/Qt6 probes, offscreen):
  both plugins answer QT_QPA_PLATFORMTHEME=qt5ct AND qt6ct; one colour-scheme file
  format (21 QPalette roles, #aarrggbb) for both; color_scheme_path expands ~ and $VAR;
  a running app re-reads on a RENAME in the conf dir (QFileSystemWatcher directory),
  not on an in-place edit or touch (~2 s); fonts: Qt5 10-field, Qt6 16-field strings;
  a # header comment in the colour file is ignored.
- Void qt5ct-1.9_1 / qt6ct-0.11_4 .xbps: libqt{5,6}ct.so, same colour files.
