# Plan — idle-dim

## Goal
Scope K slot 5 (A2): the screen fades to a dim level DIM_SECS before the idle
lock, and any input cancels it. It restores the gamma that was there before
(night light's tint and dwm-brightness's level), never 1.0.

## Design (probed 2026-10-27; see context.md)
- `dwm-lock --daemon`: `xset s noblank noexpose` (X draws nothing at screensaver
  activation, so the fade is visible) and `xset s LOCK-DIM DIM`, then
  `xss-lock -n dwm-idle-dim -- slock`. The lock time stays LOCK_SECS (600):
  the notifier runs at activation, and the locker at the first cycle.
- `dwm-idle-dim` (new), the notifier. It fades in steps to DIM_LEVEL, then waits;
  on TERM/INT/EXIT it restores.
  - While dwm-nightlight's daemon runs, it is the ONE gamma writer: the dimmer
    writes `<state>/nightlight/dim` ("<factor> <pid>") and calls
    `dwm-nightlight apply`, which multiplies the brightness by the factor while
    that pid lives (a crashed dimmer never leaves the screen dim). Restore:
    remove the file, then apply.
  - Otherwise: capture each on-output's Gamma and Brightness from
    `xrandr --verbose` (Gamma reads back INVERTED, and `--brightness` alone
    resets gamma to 1.0), then fade with `--gamma 1/g --brightness b*f`, and
    restore with the factor 1.

## Scope
- config/dwm/bin/dwm-lock, config/dwm/bin/dwm-idle-dim (new), config/dwm/bin/dwm-nightlight
- tests/dwm-lock.sh, tests/dwm-idle-dim.sh (new), tests/dwm-nightlight.sh
- KEYBINDINGS.md (§ lock), docs, CHANGELOG.md, CLAUDE.md (bin list)

## Forbidden
- autostart.sh template (the launch line `dwm-lock --daemon` is unchanged)

## Steps
1. dwm-nightlight: the dim factor in brightness(), honoured only while its pid lives
2. dwm-idle-dim
3. dwm-lock: noblank/noexpose, s LOCK-DIM DIM, -n
4. tests (fake xrandr/gammastep/xset/xss-lock; never the live screen)
5. docs, full suite, lint

## Out of scope
- backlight fade (rejected in A2); a user-facing switch (set DIM_SECS=0 to turn it off)

## Risks
- the X blanking path is read from the xserver source, not seen: VM proof
- an existing session's xss-lock keeps running without -n until the next login;
  the re-armed timers make it lock at LOCK-DIM until then
