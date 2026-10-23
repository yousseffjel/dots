#!/usr/bin/env bash
# `dots doctor`: can an app store a secret without a prompt? Sourced by
# doctor.sh after doctor-portal.sh; same report() contract and the same
# "session" section as doctor-notify.sh.
#
# Nothing in autostart.sh starts the keyring, so the daemon checks cannot see
# it. ly's PAM file unlocks it at login (pam_gnome_keyring.so, ly's stock
# /etc/pam.d/ly) and the session bus activates the secrets component on first
# use (docs/DESKTOP.md). Whether the package is installed is check_packages'
# job; this asks the Secret Service itself whether the default collection is
# unlocked (checks-must-test-the-effect), so it holds for KeePassXC or any
# other provider too.
#
# Read-only as the rest of the doctor is: the property read writes nothing,
# though it may make the bus ACTIVATE the daemon, which the first app needing
# a secret would have done anyway. Reading a property never prompts.
#
# The reply texts matched below were captured from gnome-keyring 51.1 on a
# private bus (2026-10-23), the same ones tests/doctor-keyring.sh fakes.

KEYRING_DEST=org.freedesktop.secrets
KEYRING_PATH=/org/freedesktop/secrets/aliases/default

check_keyring() {
    local s=session reply to=()
    # check_session reported the skip for this section; check_portal the bus.
    [[ -n "${DISPLAY:-}" ]] && pgrep -x dwm >/dev/null 2>&1 || return 0
    [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] || return 0
    if ! command -v gdbus >/dev/null 2>&1; then
        report skip "$s" keyring "gdbus not installed — cannot ask the Secret Service"
        return 0
    fi
    command -v timeout >/dev/null 2>&1 && to=(timeout 10)
    reply="$("${to[@]}" gdbus call --session --dest "$KEYRING_DEST" --object-path "$KEYRING_PATH" \
        --method org.freedesktop.DBus.Properties.Get org.freedesktop.Secret.Collection Locked 2>&1 || true)"
    case "$reply" in
        *"<false>"*) report ok "$s" keyring "the keyring answers and is unlocked: apps store secrets without a prompt" ;;
        *"<true>"*) report warn "$s" keyring "the keyring is LOCKED, so the first app that needs a secret asks for its password — ly unlocks it only while it has your login password (docs/DESKTOP.md, Keyring)" ;;
        *"Object does not exist"*) report warn "$s" keyring "the Secret Service answers but has no login keyring yet — ly creates it at the next login with your password: log out and back in" ;;
        *ServiceUnknown* | *NameHasNoOwner*) report warn "$s" keyring "no Secret Service on the bus, so apps keep passwords and tokens in plain text — gnome-keyring is in packages/desktop.lst: sudo xbps-install gnome-keyring, then log out and back in" ;;
        *) report warn "$s" keyring "the Secret Service does not answer: ${reply%%$'\n'*}" ;;
    esac
}
