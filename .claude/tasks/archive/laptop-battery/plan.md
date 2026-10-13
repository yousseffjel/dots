# Plan — laptop-battery (scope-h slot 3)

## Goal
A `BAT` status-bar block that shows the system battery (capacity, charging)
and is empty on a machine without one, plus low (15%) and critical (5%)
notifications while discharging — sent once per crossing, re-armed by
charging. No new daemon: the block's own 60 s timer does the alerting.

## Scope
- suckless/dwmblocks/scripts/dwm-battery, suckless/dwmblocks/blocks.def.h
- tests/blocks-battery.sh, tests/lib/blocks.sh
- KEYBINDINGS.md, docs/HARDWARE.md, CHANGELOG.md, CLAUDE.md

## Allowed

## Forbidden
- HyDE/**
- dwm-titus/**

## Steps
1. dwm-battery: system batteries only (type Battery, scope != Device); energy/charge sums across BAT0+BAT1, else capacity; empty without one.
2. Colour + label: BAT NN% (+ while charging); WARN <= 15, URGENT <= 5 when discharging.
3. Alerts: notify-send once per threshold crossing (state in XDG_STATE_HOME/dots), re-armed on charge or recovery; critical urgency at 5%.
4. Left click: notification with status, percent and time left/to full when power_now/energy_now exist.
5. blocks.def.h row: interval 60, signal 13 (first unused); before the clock.
6. tests/blocks-battery.sh on a fake power_supply tree (DOTS_POWER_SUPPLY_ROOT).
7. Docs: KEYBINDINGS block table (13 blocks), HARDWARE.md, CHANGELOG, CLAUDE.md block count.

## Out of scope
- suspend/hibernate on critical (upower CriticalPowerAction), tuned-ppd

## Risks
- alert spam every 60 s — state file, asserted by a repeat-run test
- desktop bar cost — the block exits after one directory scan, prints nothing
