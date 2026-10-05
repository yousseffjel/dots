# Plan — visual-defaults

## Goal
After the first VM run: (1) a fresh install gets a wallpaper, rendered from the active
static theme's palette (no binary in git); (2) picom does something visible but cheap
and stable (inactive dimming); (3) a VM guest resizes to the viewer window (spice-vdagent).

## Scope
- scripts/theme/*.sh
- scripts/install-session*.sh
- config/picom/picom.conf
- config/theme/templates/always/picom.dcol
- packages/extra.lst
- tests/*.sh
- themes/*/wallpapers/README.md
- docs/*.md
- CLAUDE.md
- *.md
## Allowed
## Forbidden
- HyDE/
- dwm-titus/
## Steps
1. New scripts/theme/wallpaper-default.sh <theme> <palette>: ImageMagick (magick|convert)
   renders a 2560x1440 diagonal gradient (dcol_1xa2 -> dcol_pry1) to the theme cache's
   wallpapers/<theme>.png and writes ~/.fehbg — ONLY when ~/.fehbg is absent or already ours.
2. theme-apply.sh static mode: call it before reload.sh (reload re-runs ~/.fehbg).
3. picom.conf + picom.dcol in lockstep: inactive-dim 0.15, mark-ovredir-focused,
   use-ewmh-active-win; DECISION REVERSAL comment vs 2026-08-07 perf tuning.
4. spice-vdagent: extra.lst; autostart entry guarded by `systemd-detect-virt --vm -q`;
   paired session_report_daemon + DAEMONS entry (rule 6).
5. tests/wallpaper-default.sh: fake magick/convert, sandbox HOME; never overrides a user
   wallpaper; regenerates on theme switch; real render when ImageMagick present.
6. Docs: themes/dark/wallpapers/README.md, docs/THEMING.md, TESTING.md, CHANGELOG.md.
## Out of scope
- Shadows, rounded corners, blur (user: "simple and stable").
- spice-vdagentd system service enablement (udev-activated on Fedora; verify on VM).
## Risks
- inactive-dim may dim the bar/dmenu — mark-ovredir-focused; verify on VM.
- Auto-resize needs a SPICE display + virt-manager "Auto resize" — user-side setting.
