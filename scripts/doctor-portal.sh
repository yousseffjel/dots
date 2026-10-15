#!/usr/bin/env bash
# The desktop-portal checks of scripts/doctor.sh — SOURCED by it, never run
# alone. Assumes doctor.sh's report(), `set -euo pipefail`, and global_fn.sh
# (via doctor-checks.sh). Its own file because doctor-session.sh is near the
# 250-line cap.
#
# Why this exists: until 2026-10-06 the doctor only checked that the dark-mode
# preference was STORED (dconf), and reported "ok" while xdg-desktop-portal
# could not start at all. These checks ask the portal itself.
#
# On Void the portal is started on demand by the SESSION D-Bus bus (no systemd
# user manager), which ~/.xinitrc starts with dbus-run-session. No bus in the
# session's environment means no portal, no PipeWire and no notifications.

PORTAL_DEST=org.freedesktop.portal.Desktop
PORTAL_PATH=/org/freedesktop/portal/desktop

# The session bus first: without one the D-Bus call can only fail. The fix is
# told apart by whether ~/.xinitrc already starts one (then a re-login is all
# it takes) or not (rule 6: the file is the user's, so the lines to add are
# documented rather than written).
# shellcheck disable=SC2088 # "~/.xinitrc" is text for the user, not a path
check_portal() {
    local s=theme
    if [[ -z "${DISPLAY:-}" ]]; then
        report skip "$s" portal "desktop portal: run dots doctor inside the dwm session to check it"
        return 0
    fi
    if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
        if grep -qs 'dbus-run-session' "$HOME/.xinitrc"; then
            report warn "$s" session-bus "this session has no D-Bus bus, though ~/.xinitrc starts one — log out and back in"
        else
            report warn "$s" session-bus "~/.xinitrc starts no D-Bus session, so no desktop portal, sound or notifications — add the lines in docs/THEMING.md (Desktop portal), then log out and back in"
        fi
        return 0
    fi
    report ok "$s" session-bus "a session D-Bus bus is running"
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
