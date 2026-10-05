# Plan — wallpaper-follows-display

## Goal
feh paints the root window at the screen size of the moment, so any later resolution change
(login: .xinitrc draws at 1280x800, then autostart's `autorandr --change` switches to 1920x1080;
monitor hotplug; Super+d) leaves the wallpaper in a corner. Re-run ~/.fehbg after every switch.

## Scope
- config/autorandr/postswitch.d/*
- config/dwm/bin/dwm-display
- scripts/install-restore-apps.sh
- tests/*.sh
- docs/*.md
- *.md
## Allowed
## Forbidden
- HyDE/
- dwm-titus/
## Steps
1. config/autorandr/postswitch.d/10-dots-wallpaper (sh, executable): run ~/.fehbg if executable.
2. restore_apps: deploy_app_file it to $XDG_CONFIG_HOME/autorandr/postswitch.d/ (COPIED + APP
   manifest row; never symlinked — `autorandr --save` writes profiles into that directory, and
   config/autorandr must stay out of symlinks.sh).
3. dwm-display: after a layout applies successfully, run ~/.fehbg (covers raw xrandr presets).
4. Tests: tests/autorandr-wallpaper-hook.sh runs the shipped hook under /bin/sh with fake feh
   (fehbg present / absent / non-executable); extend tests/dwm-display.sh for the redraw;
   install-uninstall-symmetry must stay green (new APP row removed on uninstall).
5. Docs: THEMING.md generated-wallpaper section, KEYBINDINGS/dwm-display note if any, CHANGELOG.
## Out of scope
- A hand-typed `xrandr` (no hook point) — documented: run ~/.fehbg or use Super+d.
- spice auto-resize (user chose a fixed autorandr profile).
## Risks
- autorandr skips hooks when the profile is already active — then nothing changed, nothing to fix.
