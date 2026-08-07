# Plan — thunar-finalization

## Goal
Epic sub-task 8. Ship Thunar's config (custom actions, preferences, archive/
thumbnail/volman behaviour), name alacritty as the terminal via the Xfce helper
framework, and set xdg mime defaults — all deployed by COPY, never symlink,
since Thunar/exo rewrite these files at runtime.

## Scope
- config/thunar/**, config/xfce4/**, config/applications/**, config/mimeapps.list
- scripts/install-restore*.sh, scripts/uninstall*.sh, packages/extra.lst
- docs/

## Allowed
- config/thunar, config/xfce4, config/applications, config/mimeapps.list
- scripts/install-restore.sh, scripts/install-restore-apps.sh
- scripts/uninstall.sh, scripts/uninstall-apps.sh
- packages/extra.lst, docs/THUNAR.md, README.md

## Forbidden
- scripts/symlinks.sh
- suckless/, config/theme/, config/picom/, config/dunst/, config/sxhkd/

## Steps
1. `config/thunar/{thunarrc,uca.xml}` + `config/xfce4/helpers.rc`.
2. `config/applications/dots-nvim.desktop` + `config/mimeapps.list`.
3. `scripts/install-restore-apps.sh`: copy-deploy, no-clobber, APP manifest rows.
4. Same file: guarded `xfconf-query -c thunar` preferences pass.
5. `scripts/uninstall-apps.sh` + wire into `uninstall.sh`.
6. `packages/extra.lst` += xfce4-settings; wire `restore_apps` into install-restore.sh.
7. `docs/THUNAR.md` + verification.

## Out of scope
- symlinks.sh (these files are runtime-mutable — copy, like dunst/picom)
- Any theming template; gtk.dcol already covers Thunar's GTK appearance.

## Risks
- thunarrc is migration-only — xfconf pass is what works on an existing box.
- uninstall_steps.sh is 230/250 lines — new step goes in its own file.
- Fedora package names unverifiable locally (no dnf) — check upstream.
