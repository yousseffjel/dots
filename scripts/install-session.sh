#!/usr/bin/env bash
# Session wiring for the dwm desktop: the autostart hook and ~/.xinitrc.
#
# Sourced by install-suckless.sh, which owns building the suckless programs.
# The split is the same one install-restore.sh makes with
# install-restore-theme.sh: building and session wiring are separate concerns,
# and keeping them in one file put it over the repo's 250-line cap.
#
# Sourced by install-suckless.sh only, never standalone: every function here
# assumes the caller has already `set -euo pipefail` and defined DRY_RUN and
# the red/green/yellow/blue helpers. Everything else it derives itself.
#
# usage: source "$SCRIPT_DIR/install-session.sh"; install_session
#
# Both files it writes are USER-OWNED once they exist (CLAUDE.md rule 6). When
# one is already present it is never rewritten, patched or backed up; the
# missing line is printed for the user to paste instead.

# Two siblings, both split off at the 250-line cap: the reporting half
# (session_autostart_report and its helper) and the autostart.sh body itself
# (session_autostart_template and its three parts). What is left here is the
# orchestration — decide whether to write, write it, or report what is missing.
#
# Resolved from BASH_SOURCE rather than the caller's $SCRIPT_DIR (rule 3, and
# unlike install-restore.sh, which sources its sibling from a variable it set
# itself): this file is SOURCED, by install-suckless.sh and independently by
# tests/autostart-daemons.sh, and the latter sets no SCRIPT_DIR at all.
SESSION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install-session-report.sh
source "$SESSION_DIR/install-session-report.sh"
# shellcheck source=install-session-template.sh
source "$SESSION_DIR/install-session-template.sh"

install_session_autostart() {
    # dwm's autostart patch runs $XDG_DATA_HOME/dwm/autostart.sh (falling back
    # to ~/.local/share/dwm) at startup. Without this, dwmblocks is built and
    # installed but never actually launched, and the bar stays empty.
    local autostart_dir autostart
    autostart_dir="${XDG_DATA_HOME:-$HOME/.local/share}/dwm"
    autostart="$autostart_dir/autostart.sh"
    [[ $DRY_RUN -eq 1 ]] || mkdir -p "$autostart_dir"

    if [[ -e "$autostart" ]]; then
        session_autostart_report "$autostart"
        return 0
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would write $autostart (autostart daemons + session services)"
        return 0
    fi

    # Deliberately not an enumeration of the daemons: this used to list them by
    # name and had already gone stale once (xsettingsd was added without it).
    # The authoritative lists are session_autostart_* and their paired
    # session_report_daemon calls, which tests/autostart-daemons.sh holds in
    # step. A third copy here is a drift site with nothing checking it.
    session_autostart_template >"$autostart"
    chmod 755 "$autostart"
    green "wrote   $autostart (autostart daemons + session services)"
}

install_session_xinitrc() {
    local xinitrc="$HOME/.xinitrc"

    if [[ -e "$xinitrc" ]]; then
        green "ok      ~/.xinitrc exists (left untouched)"
        return 0
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would write ~/.xinitrc (exec dwm)"
        return 0
    fi

    cat >"$xinitrc" <<'EOF'
#!/bin/sh
# Started by startx. dwm runs in the foreground; when it exits, X exits.

# Merge the distro's xinit fragments (keyboard layout, dbus, ssh-agent, ...).
if [ -d /etc/X11/xinit/xinitrc.d ]; then
	for f in /etc/X11/xinit/xinitrc.d/?*.sh; do
		[ -x "$f" ] && . "$f"
	done
	unset f
fi

exec dwm
EOF
    chmod 755 "$xinitrc"
    green "wrote   ~/.xinitrc (exec dwm)"
}

install_session() {
    install_session_autostart
    install_session_xinitrc
}
