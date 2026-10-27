#!/usr/bin/env bash
# The Super+s scratchpad set on two monitors, for tests/dwm-multimon.sh.
# SOURCED, never run on its own (tests/lib/ is outside run-tests.sh's
# depth-1 glob). Split out at the 250-line cap; uses the caller's check,
# on_left/on_right and the helpers in dwm-runtime-x.sh.

# is_shown too: a hidden window's negative x passes on_left alone.
shown_left() { is_shown "$1" && on_left "$1"; }
shown_right() { is_shown "$1" && on_right "$1"; }

# scratchpadgroup: Super+s gathers the set to the focused monitor. Via the
# left: a move inside the window under the pointer selects nothing.
check_multimon_scratchpad() {
    local ws wp wt
    blue "==> scratchpad set gathers to the focused monitor"
    xdotool mousemove 300 500
    sleep 0.3
    xdotool mousemove 2500 500
    sleep 0.3
    xdotool key super+9
    sleep 0.3
    ws="$(spawn_win)"
    sleep 0.3
    check "...the test window opened on the right monitor" on_right "$ws"
    xdotool key super+shift+s sleep 0.3 mousemove 300 500 sleep 0.3 key super+s sleep 0.5
    check "a scratchpad stashed on the right shows on the left" shown_left "$ws"
    # Shown on the left, Super+s on the right brings it over, not hides it.
    xdotool mousemove 2500 500 sleep 0.3 key super+s sleep 0.5
    check "a scratchpad shown on the left follows Super+s to the right" shown_right "$ws"
    xdotool key super+s
    sleep 0.3
    xdotool windowkill "$ws"

    # The X stack: restack() puts each monitor's tiled windows just below ITS
    # bar, and the right bar was made after the left one, so anything tiled on
    # the right is above anything tiled on the left. A scratchpad stashed from
    # the left and shown on the right sat under the right's tiled windows until
    # Super+s raised it: arrange(NULL) alone never restacks.
    # Tag 8, not 9: the right shows 9, and Super+9 here would go there
    # (sharetags).
    xdotool mousemove 300 500 sleep 0.3 key super+8 sleep 0.3
    wp="$(spawn_win)"
    xdotool key super+shift+s sleep 0.3 mousemove 2500 500 sleep 0.3
    wt="$(spawn_win)"
    xdotool mousemove 2500 5 sleep 0.3 key super+s sleep 0.5
    check "a scratchpad stashed on the left shows on the right" shown_right "$wp"
    check "...above the window already tiled there" stacked_above "$wp" "$wt"
    xdotool key super+s sleep 0.3 windowkill "$wp" windowkill "$wt"
}
