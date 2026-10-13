# Plan — laptop-detect (scope-h slots 1+2, merged)

## Goal
PC/laptop checker (`drivers_chassis`) + the first laptop feature: a gated
`packages/laptop.lst` (brightnessctl) installed by `dots drivers` only on a
laptop, and `dwm-brightness` driving the real backlight when one exists
(xrandr gamma stays the desktop path). Doctor reports the chassis and skips a
list whose `# chassis:` header does not match. Merged: an empty laptop.lst
fails tests/pkglist.sh.

## Scope
- scripts/{drivers-detect,drivers-lib,drivers,doctor-checks,doctor-drivers,install-pkg-tiers}.sh
- packages/{laptop,extra}.lst, config/dwm/bin/dwm-brightness, suckless/dwmblocks/scripts/dwm-brightness-block
- tests/{drivers,dwm-brightness,doctor,pkg-repos}.sh, tests/lib/{drivers-cases,doctor-sandbox}.sh
- docs/HARDWARE.md, CHANGELOG.md, CLAUDE.md, KEYBINDINGS.md

## Allowed

## Forbidden
- HyDE/**
- dwm-titus/**

## Steps
1. drivers_chassis: dmi chassis_type 8,9,10,14,31,32 OR a power_supply Battery without scope=Device -> laptop; reason string.
2. packages/laptop.lst (`# chassis: laptop`, brightnessctl); pkg_list_chassis in install-pkg-tiers.sh; drivers_laptop installs it on a laptop.
3. Doctor: chassis row; check_packages skips a list whose chassis != this machine.
4. dwm-brightness: brightnessctl --class=backlight when a device answers; `mode` prints backlight|gamma; block label BL vs GAMMA.
5. Tests: chassis fixtures (dmi, battery, mouse battery, QEMU type 1), gated install, doctor skip, fake brightnessctl in dwm-brightness.sh.
6. Docs: HARDWARE.md laptop section, CLAUDE.md rule 10 row + decisions 9/12 note, extra.lst rejected notes, CHANGELOG.
7. VM: QEMU chassis 1 -> "unknown, treated as desktop"; doctor clean.

## Out of scope
- battery block, touchpad, tuned-ppd (scope-h slots 3-5)

## Risks
- drivers.sh standalone lacks read_pkg_list — source install-pkg-tiers.sh in drivers.sh (CLI), NOT in drivers-lib (would reset installer arrays)
- brightnessctl needs a logind session (Fedora builds ENABLE_SYSTEMD) — over ssh it may fail; fall back to gamma, never error
