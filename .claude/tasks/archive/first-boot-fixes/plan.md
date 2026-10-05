# Plan — first-boot-fixes

## Goal
Fix the three bugs the first real install (Fedora 44 Server VM, virtio GPU, ly, 2026-10-05) exposed:
(1) picom's glx backend freezes the screen without 3D accel; (2) a headless install never themes
the desktop and nothing restores the theme at login; (3) `chsh` fails non-interactively, so the
login shell stays bash (uninstall's revert has the same bug).

## Scope
- scripts/install-session*.sh
- scripts/install-services.sh
- scripts/uninstall_steps.sh
- scripts/install-restore-theme.sh
- packages/desktop.lst
- tests/*.sh
- tests/lib/*.sh
- CLAUDE.md
- docs/*.md

## Allowed
## Forbidden
- HyDE/
- dwm-titus/

## Steps
1. picom probe in session_autostart_display: `timeout 5 glxinfo -B`; llvmpipe/softpipe/swrast, `direct rendering: No`, or glxinfo absent -> `picom --backend xrender &`, else `picom &`. Report: warn when an existing autostart.sh starts picom without the probe.
2. Add `glx-utils` to desktop.lst with consequence text (verified packages.fedoraproject.org: f43/f44/rawhide).
3. Theme at session start goes in ~/.xinitrc BEFORE `exec dwm` (not autostart.sh: reload.sh HUPs dwm, restartsig re-execs, runautostart re-runs -> loop). No theme cache -> `dots theme dark`; else `xrdb -merge` cache + `~/.fehbg` if executable. Add session_xinitrc_report for an existing ~/.xinitrc.
4. Reword install-restore-theme.sh skip line: the theme now applies on first login.
5. install-services.sh: `"${SUDO[@]}" usermod -s` replacing chsh; uninstall_shell the same; add usermod to symmetry-test sentinels.
6. Tests: extend autostart-daemons.sh for the picom probe branches (run generated sh with fake glxinfo on PATH) and a new tests/xinitrc-theme.sh running the generated xinitrc with shims.
7. Docs: CLAUDE.md (xinitrc theme restore, picom probe), docs/THEMING.md first-login note.

## Out of scope
- Shipping a default wallpaper (themes/*/wallpapers has only a README).
- dwm.desktop xsession file; ly uses ~/.xinitrc today.

## Risks
- glxinfo hang on broken GL — bounded by `timeout 5`; absent timeout -> xrender.
- Existing installs keep old user-owned files — report lines name exactly what to paste.
