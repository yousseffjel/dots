# Plan — laptop-power (scope-h slot 5, last)

## Goal
On a laptop: tuned-ppd (Fedora's default profile daemon, pulls tuned) from
laptop.lst, tuned.service enabled so the chosen profile survives reboot
(SERVICE row only when this run enabled it), and `dwm-power` — a dmenu menu
(Super+Shift+p, and a "profile" entry in the power menu) that reads and sets
power-saver / balanced / performance over the PPD D-Bus API with gdbus.
Desktop: the key explains profiles are laptop-only; nothing installed.

## Scope
- packages/{laptop,extra}.lst, scripts/{drivers-laptop,doctor-drivers}.sh
- config/dwm/bin/{dwm-power,dwm-powermenu}, config/sxhkd/sxhkdrc
- tests/{dwm-power,doctor,drivers}.sh, tests/lib/{drivers-cases-laptop,doctor-sandbox}.sh
- KEYBINDINGS.md, docs/HARDWARE.md, CHANGELOG.md, CLAUDE.md

## Allowed

## Forbidden
- HyDE/**
- dwm-titus/**

## Steps
1. laptop.lst += tuned-ppd; extra.lst rejected-note for power-profiles-daemon updated.
2. drivers_power: enable tuned.service (+ tuned-ppd.service) only if not already enabled; SERVICE rows; dry-run.
3. config/dwm/bin/dwm-power: get | set <p> | menu (current marked); gdbus org.freedesktop.UPower.PowerProfiles; notify result; clear message without the service.
4. sxhkd Super+Shift+p; dwm-powermenu "profile" entry only when the service answers.
5. Doctor (laptop): tuned-ppd installed, tuned enabled, active profile readable.
6. Tests: fake gdbus (real `(<'balanced'>,)` shape), drivers + doctor cases, key-collisions passes.
7. Docs + VM (desktop path: key says laptop-only; powermenu has no entry).

## Out of scope
- a status-bar block for the profile; editing /etc/tuned/ppd.conf mappings

## Risks
- gdbus text format — copy the GVariant print shape; doctor-portal.sh already parses gdbus
- polkit: switch-profile is allow_active yes (tuned-ppd.policy) — over ssh it is refused; said, not silent
