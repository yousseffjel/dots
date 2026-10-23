#!/usr/bin/env bash
# dwm-lib-session.sh — SOURCED (mode 644, so dmenu never lists it) by the
# dwm-* commands that must act once per login although autostart.sh runs
# again after every dwm restart: dwm-xdg-autostart and dwm-sound --login.
#
# DOTS_PROC replaces /proc for the no-bus fallback (tests).

# session_key — what identifies this login; empty when nothing does.
# The session is the D-Bus bus ~/.xinitrc starts (a new address at every
# login, the same one across a restart, which keeps dwm's environment), or
# without one dwm's PID and start time (an exec restart keeps both).
# autostart.sh is started through system("... &"), so its parent is a
# short-lived sh, not dwm.
session_key() {
    local pid stat
    if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        printf 'bus %s\n' "$DBUS_SESSION_BUS_ADDRESS"
        return 0
    fi
    pid="$(pgrep -u "$(id -u)" -x -n dwm 2>/dev/null)" || return 0
    # Field 22 of stat is the start time; the comm field before it may hold
    # spaces, so cut after its closing parenthesis.
    { read -r stat <"${DOTS_PROC:-/proc}/$pid/stat"; } 2>/dev/null || return 0
    stat="${stat##*) }"
    printf 'dwm %s %s\n' "$pid" "$(cut -d' ' -f20 <<<"$stat")"
}

# session_once <marker> — true the first time this session asks, false after.
# Records the session BEFORE the caller acts: an interrupted run must not act
# twice later. With no key at all it is always true (nothing to compare).
session_once() {
    local marker="$1" key
    key="$(session_key)"
    if [[ -n "$key" && -f "$marker" && "$(<"$marker")" == "$key" ]]; then
        return 1
    fi
    mkdir -p "$(dirname "$marker")"
    printf '%s\n' "$key" >"$marker"
}
