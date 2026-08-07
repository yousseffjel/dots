# Context — thunar-finalization

## Background

Epic sub-task 8 of `.claude/tasks/scope-b-app-roster-finalization.md`. Every
package it needs is already in `packages/extra.lst` from sub-task 2 (thunar,
thunar-archive-plugin, thunar-volman, tumbler, ffmpegthumbnailer, file-roller,
unar, catfish, gvfs). Nothing under `config/` targets Thunar today — this is a
from-scratch config, not an edit.

## Prior Decisions

- Locked decision 1 — alacritty is the terminal Thunar names.
- Locked decision 3 — GTK only, no Qt. `file-roller`/`catfish` keep that true.
- Locked decision 8 — RAR via `unar`, not `unrar` (RPM Fusion nonfree).
- CLAUDE.md rule 7 — `symlinks.sh` links **directories**, backing up conflicts.
  Does not apply here: these files are runtime-mutable, so they are copied.

## Research findings (verified this session, not assumed)

1. **`thunarrc` is a one-time migration source, not the live config.** Thunar
   4.20 stores preferences in the xfconf `thunar` channel. Upstream
   `thunar-preferences.c` guards the import on `!xfconf_channel_has_property
   (channel, "/last-view")` and additionally skips any property xfconf already
   holds. This host proves it: `thunar.xml` has `/last-view`, and no
   `thunarrc` exists at all. **Consequence: a shipped thunarrc only ever
   applies to a box where Thunar has never run.** Hence step 4's xfconf pass.
2. **`exo-open --launch TerminalEmulator` is a thin wrapper around
   `xfce4-mime-helper`.** Proved by putting a fake `xfce4-mime-helper` first on
   `PATH`: exo-open invoked it with `--launch TerminalEmulator echo hi` and
   consulted nothing else. `libexo-2.so.0` contains only the strings
   `xfce4-mime-helper`, `/xfce4/helpers.rc`, `[Default]` and a hardcoded
   `xfce4-terminal.desktop` fallback.
3. **The helper framework moved out of exo in 4.15.1.** exo NEWS: *"Removed
   binaries: exo-compose-mail, exo-helper-2"*; xfce4-settings NEWS: *"exo-helper
   -> xfce4-mime-helper"*. Fedora 43/44 ship exo 4.20.0 and xfce4-settings
   4.20.2 — both past that cut. So `helpers.rc` without `xfce4-settings` is a
   file nothing acts on. User chose to add the package (see Deviation log).
4. **`alacritty.desktop`, `firefox.desktop` and `thunar.desktop` all ship
   upstream** in `xfce4-settings`'s `/usr/share/xfce4/helpers/` (confirmed via
   the Arch files DB, `pacman -Fl xfce4-settings`). No custom helper `.desktop`
   is needed — `helpers.rc` names them directly.
5. **`xfconf-query` costs nothing new.** `thunar` -> `libxfce4ui` -> `xfconf`,
   so it is present wherever Thunar is. It does need a D-Bus session, so the
   pass must be guarded and skipped with a warning on a headless install —
   same shape as `theme_initial_apply`.
6. **Thunar hardcodes `exo-open --launch TerminalEmulator `** for its built-in
   "Open Terminal Here" (string present in `/usr/bin/thunar`). A `uca.xml`
   custom action is a separate, independent path that needs no exo at all.

## References

- `scripts/install-restore-theme.sh` — the copy-deploy + no-clobber + manifest
  pattern to mirror (`deploy_theme_file`, `theme_is_ours`).
- `scripts/uninstall_steps.sh:106` — `uninstall_theme`, the model for
  `uninstall_apps`. That file is 230/250 lines, so the new step needs its own.
- `config/dwm/bin/dwm-wallpaper` — target of the "Set as Wallpaper" action.
- Host versions used for verification: thunar 4.20.8, exo 4.20.0 (Arch).

## Notes

Dev host is Arch, target is Fedora. `xfce4-settings` must be verified against
packages.fedoraproject.org per CLAUDE.md rule 8 before the list edit lands.
