# Plan — laptop-touchpad (scope-h slot 4)

## Goal
On a laptop, `dots drivers` installs an Xorg InputClass snippet that turns on
tap-to-click, natural scrolling, disable-while-typing and two-finger
right-click for touchpads only (MatchIsTouchpad), as a root-owned file in
/etc/X11/xorg.conf.d tracked by a new SYSFILE manifest row: replaced only
while unedited, removed by uninstall only while unedited. Doctor checks it.

## Scope
- config/xorg/40-dots-touchpad.conf
- scripts/{drivers-laptop,drivers-lib,drivers,doctor-drivers,uninstall,uninstall-sysfiles}.sh
- tests/{drivers,uninstall-sysfiles}.sh, tests/lib/drivers-cases.sh
- docs/{HARDWARE,UNINSTALL}.md, CHANGELOG.md, CLAUDE.md

## Allowed

## Forbidden
- HyDE/**
- dwm-titus/**

## Steps
1. config/xorg/40-dots-touchpad.conf (Driver libinput + MatchIsTouchpad; four options).
2. scripts/drivers-laptop.sh: move drivers_laptop here + drivers_touchpad (DOTS_XORG_CONF_DIR override; SYSFILE row; update-if-unedited via file_matches_history; never overwrite an edited/unclaimed file).
3. scripts/uninstall-sysfiles.sh + uninstall.sh: remove SYSFILE paths only when unedited; edited -> kept + told.
4. Doctor: on a laptop, the snippet present and ours.
5. Tests: drivers cases (install, re-run no-op, unedited update, edited kept, desktop/VM nothing, dry run); tests/uninstall-sysfiles.sh.
6. Docs: HARDWARE.md, UNINSTALL.md step, CHANGELOG, CLAUDE.md map + manifest category.
7. VM: Xorg parses the snippet (user copies it to /etc, re-logs in, Xorg.0.log has no error); then removed.

## Out of scope
- xinput / live reconfiguration; per-user overrides; Wayland

## Risks
- Xorg reads /etc conf.d before /usr/share (40-libinput.conf) — use Driver, not MatchDriver
- A bad snippet can stop X starting — VM parse check before merge (step 7)
