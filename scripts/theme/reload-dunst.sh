#!/usr/bin/env bash
# reload_dunst — the dunst step of scripts/theme/reload.sh.
#
# Sourced by reload.sh only, never standalone: it relies on the caller's
# `set -euo pipefail` and its say/run_bounded/red/yellow/green helpers. Split
# out when the pause-level handling put reload.sh over the 250-line cap.
# tests/dunst-reload.sh runs reload.sh itself, so it covers this file.
#
# usage: source "$SCRIPT_DIR/reload-dunst.sh"

reload_dunst() {
    # `dunstctl reload` makes the running dunst re-read the regenerated
    # dunstrc: same process, so the notification history survives. This step
    # used to kill dunst and let D-Bus start a fresh one, which emptied the
    # notification centre and silently ended focus mode (a new dunst starts
    # unpaused) on every wallpaper change. reload itself also drops the pause
    # level to 0 (dunst 1.13.2), so the level is read first and put back.
    #
    # A dunst that is not running needs nothing: D-Bus starts it on the next
    # notification, against the new file. Starting it here would race that.
    if ! command -v dunst >/dev/null 2>&1; then
        say yellow "dunst   not installed — skipped"
        return 0
    fi
    if ! pgrep -x dunst >/dev/null 2>&1; then
        say yellow "dunst   not running — skipped"
        return 0
    fi
    local level
    level="$(run_bounded dunstctl get-pause-level 2>/dev/null || true)"
    [[ "$level" =~ ^[0-9]+$ ]] || level=0
    if run_bounded dunstctl reload >/dev/null 2>&1; then
        if ((level > 0)) && ! run_bounded dunstctl set-pause-level "$level" >/dev/null 2>&1; then
            red "dunst   reloaded, but focus mode could not be restored — Super+Shift+n turns it back on"
            return 0
        fi
        say green "dunst   reloaded (history and focus mode kept)"
    # It did not answer: the old way, so the new colours still apply.
    elif pkill -x dunst 2>/dev/null; then
        yellow "dunst   reload failed — restarted instead (history and focus mode lost)"
    else
        yellow "dunst   reload failed — colours apply when dunst next starts"
    fi
}
