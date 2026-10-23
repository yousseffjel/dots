#!/usr/bin/env bash
# The autostart-daemon checks of scripts/doctor.sh — SOURCED by it, never run
# alone. Split out of doctor-session.sh at the 250-line cap (2026-10-12).
# Assumes doctor.sh's report(), DOTS_DIR, and BT_SYSFS from doctor-session.sh.

AUTOSTART="${XDG_DATA_HOME:-$HOME/.local/share}/dwm/autostart.sh"

# Exceptions to "daemon N runs as a process whose command line names N".
# dwm-lock execs xss-lock; autorandr --change runs once at login and exits
# (empty = not a daemon, nothing to look for); so do xdg-user-dirs-update
# and dwm-xdg-autostart. Every key must be a name
# session_autostart_report reports — tests/doctor.sh fails the build if one
# is renamed or dropped there and left stale here.
declare -A DAEMON_PROCESS=(["dwm-lock"]="xss-lock" ["autorandr"]="" ["xdg-user-dirs-update"]="" ["dwm-xdg-autostart"]="")

# daemon_applies <name> — false for a daemon autostart.sh deliberately does
# not start on this machine. Mirrors the conditions in the autostart template
# (install-session-template*.sh); tests/doctor.sh reads these case labels and
# holds each one to the report.
daemon_applies() {
    case "$1" in
        spice-vdagent) drivers_is_vm ;;
        blueman-applet) [[ -n "$(ls -A "$BT_SYSFS" 2>/dev/null)" ]] ;;
        nm-applet) pgrep -x NetworkManager >/dev/null 2>&1 ;;
        dwm-audiowatch) command -v pactl >/dev/null 2>&1 ;;
        dwm-shotkey) command -v xinput >/dev/null 2>&1 ;;
        *) return 0 ;;
    esac
}

# daemon_skip_reason <name> — why daemon_applies said no, for that daemon only.
# One case per daemon_applies case; tests/doctor.sh fails the build when one
# falls through to the default.
daemon_skip_reason() {
    case "$1" in
        spice-vdagent) echo "not a VM" ;;
        blueman-applet) echo "no bluetooth adapter" ;;
        nm-applet) echo "NetworkManager is not running" ;;
        dwm-audiowatch) echo "pactl is not installed" ;;
        dwm-shotkey) echo "xinput is not installed" ;;
        *) echo "not needed on this machine" ;;
    esac
}

# report_names <autostart> — the daemons the installer's own report says that
# file does not mention. Against /dev/null that is every daemon it knows,
# which is how the list is read here without being restated.
report_names() {
    (
        # shellcheck disable=SC2317,SC2329 # called from the sourced report
        green() { :; }
        # shellcheck disable=SC2317,SC2329
        yellow() { printf '%s\n' "$*"; }
        # shellcheck source=install-session-report.sh
        source "$DOTS_DIR/scripts/install-session-report.sh"
        session_autostart_report "$1"
    ) | sed -n 's/.*does not mention \([A-Za-z0-9._-]*\).*/\1/p'
}

contains() {
    local needle="$1" x
    shift
    for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
    return 1
}

check_daemons() {
    local all=() unmentioned=() name proc
    mapfile -t all < <(report_names /dev/null)
    [[ -f "$AUTOSTART" ]] && mapfile -t unmentioned < <(report_names "$AUTOSTART")
    for name in "${all[@]}"; do
        proc="$name"
        [[ -v "DAEMON_PROCESS[$name]" ]] && proc="${DAEMON_PROCESS[$name]}"
        if ! command -v "$name" >/dev/null 2>&1 && [[ ! -x "$HOME/.config/dwm/bin/$name" ]]; then
            report skip session "daemon-$name" "$name: not installed"
        elif [[ -z "$proc" ]] && { [[ ! -f "$AUTOSTART" ]] || contains "$name" "${unmentioned[@]}"; }; then
            # A one-shot leaves no process, so "not mentioned" is the only
            # evidence it never runs — checked before the skip below swallows it.
            report warn session "daemon-$name" "$name never runs: $AUTOSTART does not mention it — run scripts/install-suckless.sh --skip-deps and paste the line it prints"
        elif [[ -z "$proc" ]]; then
            report skip session "daemon-$name" "$name: runs once at login, nothing to check"
        elif pgrep -f "(^|/)$proc( |\$)" >/dev/null 2>&1; then
            report ok session "daemon-$name" "$name is running"
        elif ! daemon_applies "$name"; then
            report skip session "daemon-$name" "$name: not needed here ($(daemon_skip_reason "$name"))"
        elif [[ ! -f "$AUTOSTART" ]] || contains "$name" "${unmentioned[@]}"; then
            report warn session "daemon-$name" "$name is not started: $AUTOSTART does not mention it — run scripts/install-suckless.sh --skip-deps and paste the line it prints"
        else
            report warn session "daemon-$name" "$name is in autostart.sh but not running — it exited or failed to start; run it in a terminal to see why"
        fi
    done
}
