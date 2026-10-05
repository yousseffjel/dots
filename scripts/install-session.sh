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
# (session_autostart_template and its four parts). What is left here is the
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

# The ~/.xinitrc body, on stdout. A function rather than an inline heredoc so
# tests/xinitrc-theme.sh can RUN the shipped file instead of restating it.
#
# The theme block is HERE, not in autostart.sh, and it must stay here. dwm
# reads its colours from the X resource database once, at startup — so the
# merge has to land before `exec dwm` to take effect without a restart. And the
# only way to make a RUNNING dwm re-read them is reload.sh's `kill -HUP`, which
# re-execs dwm (restartsig), which re-runs autostart.sh (runautostart() is
# called on every start): a theme step in autostart.sh would loop the session
# forever.
#
# Two cases. A theme cache exists: merge it and re-apply the wallpaper, which
# nothing else does at login. No cache yet — every headless install, because
# install-restore-theme.sh can only theme a running X session: apply the dark
# theme once, which writes the cache for every later login. Bounded by timeout
# so a wedged theme run delays the session instead of preventing it.
session_xinitrc_template() {
    cat <<'EOF'
#!/bin/sh
# Started by startx, and by ly (its xinitrc session). dwm runs in the
# foreground; when it exits, X exits.

# Merge the distro's xinit fragments (keyboard layout, dbus, ssh-agent, ...).
if [ -d /etc/X11/xinit/xinitrc.d ]; then
	for f in /etc/X11/xinit/xinitrc.d/?*.sh; do
		[ -x "$f" ] && . "$f"
	done
	unset f
fi

# dots theme, before dwm starts so dwm reads the colours at startup. Must not
# move to autostart.sh: re-theming a running dwm restarts it, and every dwm
# start re-runs autostart.sh.
dots_theme_cache="${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme"
if [ -r "$dots_theme_cache/xresources" ]; then
	command -v xrdb >/dev/null 2>&1 && xrdb -merge "$dots_theme_cache/xresources"
	[ -x "$HOME/.fehbg" ] && "$HOME/.fehbg"
elif [ -x "$HOME/.local/bin/dots" ]; then
	# First login after a headless install: nothing has themed this desktop yet.
	if command -v timeout >/dev/null 2>&1; then
		timeout 120 "$HOME/.local/bin/dots" theme dark
	else
		"$HOME/.local/bin/dots" theme dark
	fi
fi
unset dots_theme_cache

exec dwm
EOF
}

install_session_xinitrc() {
    local xinitrc="$HOME/.xinitrc"

    if [[ -e "$xinitrc" ]]; then
        session_xinitrc_report "$xinitrc"
        return 0
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would write ~/.xinitrc (theme restore + exec dwm)"
        return 0
    fi

    session_xinitrc_template >"$xinitrc"
    chmod 755 "$xinitrc"
    green "wrote   ~/.xinitrc (theme restore + exec dwm)"
}

install_session() {
    install_session_autostart
    install_session_xinitrc
}
