#!/usr/bin/env bash
# The desktop-portal checks of scripts/doctor.sh — SOURCED by it, never run
# alone. Assumes doctor.sh's report(), `set -euo pipefail`, and global_fn.sh
# (via doctor-checks.sh). Its own file because doctor-session.sh is near the
# 250-line cap.
#
# Why this exists: until 2026-10-06 the doctor only checked that the dark-mode
# preference was STORED (dconf), and reported "ok" while xdg-desktop-portal
# could not start at all — its unit has Requisite=graphical-session.target,
# which a dwm session never activated. These checks ask the portal itself.

PORTAL_DEST=org.freedesktop.portal.Desktop
PORTAL_PATH=/org/freedesktop/portal/desktop

# graphical-session.target first: without it the portal refuses to start, and
# the D-Bus call would only repeat that as "startup job failed". The fix is
# told apart by whether ~/.xinitrc already starts dots-session.target (then a
# re-login is all it takes) or not (rule 6: the file is the user's, so the
# lines to add are documented rather than written).
# shellcheck disable=SC2088 # "~/.xinitrc" is text for the user, not a path
check_portal() {
    local s=theme state
    if [[ -z "${DISPLAY:-}" ]] || ! command -v systemctl >/dev/null 2>&1; then
        report skip "$s" portal "desktop portal: run dots doctor inside the dwm session to check it"
        return 0
    fi
    state="$(systemctl --user is-active graphical-session.target 2>/dev/null || true)"
    if [[ "$state" != active ]]; then
        if grep -qs 'dots-session.target' "$HOME/.xinitrc"; then
            report warn "$s" session-target "graphical-session.target is ${state:-unknown}, so no desktop portal can start — log out and back in"
        else
            report warn "$s" session-target "~/.xinitrc does not start dots-session.target, so no desktop portal can start — add the lines in docs/THEMING.md (Desktop portal), then log out and back in"
        fi
        return 0
    fi
    report ok "$s" session-target "graphical-session.target is active (dots-session.target)"
    check_portal_answers
}

# Asks the Settings portal for the colour scheme — the value GTK4/libadwaita
# apps, Firefox and Electron read. 1 is "prefer dark".
check_portal_answers() {
    local s=theme reply to=()
    if ! command -v gdbus >/dev/null 2>&1; then
        report skip "$s" portal "gdbus not installed — cannot ask the desktop portal"
        return 0
    fi
    command -v timeout >/dev/null 2>&1 && to=(timeout 10)
    reply="$("${to[@]}" gdbus call --session --dest "$PORTAL_DEST" --object-path "$PORTAL_PATH" \
        --method org.freedesktop.portal.Settings.ReadOne org.freedesktop.appearance color-scheme 2>&1 || true)"
    case "$reply" in
        *"uint32 1"*) report ok "$s" portal "the desktop portal answers: apps get dark mode" ;;
        *"uint32 "*) report warn "$s" portal "the desktop portal answers, but not with dark mode (${reply//[$'\n']/ }) — see the dconf colour-scheme line above" ;;
        *) report warn "$s" portal "the desktop portal does not answer: ${reply%%$'\n'*}" ;;
    esac
}
