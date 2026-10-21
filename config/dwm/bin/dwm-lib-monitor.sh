#!/usr/bin/env bash
# Sourced by dwm-screenshot and dwm-record, never run (no exec bit, so
# dmenu_path never lists it): the "this monitor" rectangle both capture.
# Uses the caller's red.
#
# The monitor under the POINTER, not the one holding the focused window:
# an empty monitor has no window, and dwm focuses by pointer here anyway.
# xrandr --listactivemonitors is the list dwm itself lays out on (RandR
# monitors, the same rectangles Xinerama reports), so a capture lines up
# with dwm's bars exactly.

# monitor_geometry — prints WxH+X+Y for the monitor holding the pointer, or
# returns 1 having said why. Never guesses a monitor: a wrong guess is a
# shot of the other screen, which looks like it worked.
monitor_geometry() {
    local pos px py geom
    if ! command -v xdotool >/dev/null 2>&1; then
        red "${0##*/}: xdotool is not installed — it finds the monitor under the pointer (packages/desktop.lst)"
        return 1
    fi
    pos="$(xdotool getmouselocation --shell 2>/dev/null \
        | awk -F= '$1 == "X" { x = $2 } $1 == "Y" { y = $2 } END { print x, y }' || true)"
    read -r px py _ <<<"$pos" || true
    if [[ ! "${px:-}" =~ ^[0-9]+$ || ! "${py:-}" =~ ^[0-9]+$ ]]; then
        red "${0##*/}: could not read the pointer position from xdotool"
        return 1
    fi
    # " 0: +*Virtual-1 1920/508x1080/286+0+0  Virtual-1" — split on / x +
    # gives width, mm, height, mm, x, y.
    geom="$(xrandr --listactivemonitors 2>/dev/null | awk -v px="$px" -v py="$py" '
        NR > 1 && split($3, f, /[\/x+]/) == 6 && !found {
            if (px >= f[5] && px < f[5] + f[1] && py >= f[6] && py < f[6] + f[3]) {
                printf "%dx%d+%d+%d\n", f[1], f[3], f[5], f[6]
                found = 1
            }
        }' || true)"
    if [[ -z "$geom" ]]; then
        red "${0##*/}: no monitor under the pointer ($px,$py)"
        return 1
    fi
    printf '%s\n' "$geom"
}
