#!/usr/bin/env bash
# `dots doctor`: is anything going to show a notification? Sourced by
# doctor.sh after doctor-session.sh, whose 250-line cap it would have crossed;
# same report() contract and the same "session" section.
#
# The daemon checks cannot cover dunst: it is not in autostart.sh at all, it is
# D-Bus activated the first time anything sends a notification. So this asks
# dunst itself (checks-must-test-the-effect: a process list proves nothing
# about delivery). `dunstctl is-paused` both proves it answers and catches the
# one state that silently swallows every notification — do-not-disturb left
# on (Super+Shift+n).

check_notifications() {
    local s=session reply to=()
    # check_session already reported the skip for this whole section.
    [[ -n "${DISPLAY:-}" ]] && pgrep -x dwm >/dev/null 2>&1 || return 0
    if ! command -v dunstctl >/dev/null 2>&1; then
        report warn "$s" notifications "dunstctl not found — dunst is not installed, so no notification is ever shown"
        return 0
    fi
    command -v timeout >/dev/null 2>&1 && to=(timeout 5)
    reply="$("${to[@]}" dunstctl is-paused 2>/dev/null || true)"
    case "$reply" in
        false) report ok "$s" notifications "dunst answers and is showing notifications" ;;
        true) report warn "$s" notifications "do not disturb is ON: dunst is holding every notification — Super+Shift+n, or a click on the DND block, resumes them" ;;
        *) report warn "$s" notifications "dunst does not answer over D-Bus, so no notification will show — run dunst in a terminal to see why" ;;
    esac
}
