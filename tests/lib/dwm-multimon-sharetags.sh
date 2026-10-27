#!/usr/bin/env bash
# Shared tags on two monitors, for tests/dwm-multimon.sh. SOURCED, never run
# on its own (tests/lib/ is outside run-tests.sh's depth-1 glob). Uses the
# caller's check, on_left/on_right, and shown_left/shown_right from
# dwm-multimon-scratchpad.sh.

not_shown() { ! is_shown "$1"; }
pointer_left() { (($(xdotool getmouselocation --shell | sed -n 's/^X=//p') < 1920)); }
pointer_right() { ! pointer_left; }

# sharetags: one set of nine tags for every monitor, each shown on one
# monitor at a time. A tag belongs to the monitor showing it or holding its
# windows: Super+N views it THERE and takes focus and the pointer along. An
# empty tag nobody shows opens on the focused monitor.
check_multimon_sharetags() {
    local wa wb wc
    blue "==> nine tags shared by both monitors"
    xdotool mousemove 300 500 sleep 0.3 key super+5 sleep 0.3
    wa="$(spawn_win)"
    xdotool mousemove 2500 500 sleep 0.3 key super+6 sleep 0.3
    wb="$(spawn_win)"
    sleep 0.3
    check "a window on tag 5 on the left" shown_left "$wa"
    check "...and one on tag 6 on the right" shown_right "$wb"
    xdotool key super+5
    sleep 0.5
    check "Super+5 on the right goes to the left, which shows tag 5" pointer_left
    check "...nothing swapped: tag 5 still on the left" shown_left "$wa"
    check "...tag 6 still on the right" shown_right "$wb"
    # The left moves on to an empty tag; tag 5 still belongs to it.
    xdotool key super+4
    sleep 0.3
    check "an empty tag opens on the focused monitor" not_shown "$wa"
    xdotool mousemove 2500 500 sleep 0.3 key super+5 sleep 0.5
    check "Super+5 on the right: the left views tag 5 again" shown_left "$wa"
    check "...focus and the pointer went with it" pointer_left
    check "...the right kept its view" shown_right "$wb"
    # Super+Shift+N sends a window to the monitor tag N belongs to.
    xdotool mousemove 2500 500 sleep 0.3 key super+7 sleep 0.3
    xdotool mousemove 300 500 sleep 0.3
    wc="$(spawn_win)"
    xdotool key super+shift+6
    sleep 0.3
    xdotool key super+6
    sleep 0.5
    check "Super+Shift+6 sent the window to the right, where tag 6 lives" shown_right "$wc"
    check "...beside tag 6's window" shown_right "$wb"
    check "...and the pointer followed Super+6 there" pointer_right
    xdotool windowkill "$wa" windowkill "$wb" windowkill "$wc"
}
