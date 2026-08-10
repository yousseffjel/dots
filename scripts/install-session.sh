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

# One daemon's entry in the report below. Green when $autostart already
# mentions $name; otherwise a yellow "kept" header followed by each remaining
# argument as an indented advice line.
#
# The daemon name is always the SECOND argument, and
# tests/autostart-daemons.sh reads the reported set out of exactly that
# position — so a call added here is seen, and one removed is caught.
session_report_daemon() {
    local autostart="$1" name="$2" line
    shift 2

    if grep -q "$name" "$autostart"; then
        green "ok      $autostart already starts $name"
        return 0
    fi

    yellow "kept    $autostart (exists, does not mention $name)"
    for line in "$@"; do
        yellow "        $line"
    done
}

# Report on an autostart.sh the user already has, one daemon per check. Never
# edits it — CLAUDE.md rule 6 makes that file theirs the moment it exists, so
# the most we do is name the line that is missing.
#
# Advice strings are single-quoted throughout: shell syntax for the user to
# paste, and prose to read — never code this script runs. Hence both literal
# text warnings: SC2016 ($ that must not expand until autostart.sh runs) and
# SC2088 (a ~ that names a path rather than resolving one).
# shellcheck disable=SC2016,SC2088
session_autostart_report() {
    local autostart="$1"

    session_report_daemon "$autostart" picom \
        'add this line yourself:  command -v picom >/dev/null && ! pgrep -x picom >/dev/null && picom &' \
        'without it there is no compositor: no vsync, and the tuned' \
        '~/.config/picom/picom.conf is never read by anything.'

    session_report_daemon "$autostart" dwmblocks \
        'add this line yourself:  pgrep -x dwmblocks >/dev/null || dwmblocks &'

    session_report_daemon "$autostart" clipmenud \
        'add this line yourself:  command -v clipmenud >/dev/null && ! pgrep -x clipmenud >/dev/null && clipmenud &'

    session_report_daemon "$autostart" sxhkd \
        'add this line yourself:  command -v sxhkd >/dev/null && ! pgrep -x sxhkd >/dev/null && sxhkd &' \
        'without it every binding in config/sxhkd/sxhkdrc is dead —' \
        'media keys, volume, brightness, theming and app launchers.'

    session_report_daemon "$autostart" polkit-gnome \
        'add these lines yourself:' \
        '  if ! pgrep -f polkit-gnome-authentication-agent >/dev/null 2>&1; then' \
        '    if [ -x /usr/libexec/polkit-gnome-authentication-agent-1 ]; then' \
        '      /usr/libexec/polkit-gnome-authentication-agent-1 &' \
        '    elif [ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]; then' \
        '      /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &' \
        '    fi' \
        '  fi' \
        'without it no PolicyKit agent runs, so any GUI action needing' \
        'privileges (mounting a system disk, partition or package tools) is' \
        'denied with no password prompt and often no error at all.'

    session_report_daemon "$autostart" dwm-lock \
        'add this line yourself:  "${XDG_CONFIG_HOME:-$HOME/.config}/dwm/bin/dwm-lock" --daemon &' \
        'without it the screen never locks on idle or on suspend.' \
        'Super+l still works — it falls back to calling slock directly.'
}

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
        blue "  (dry-run) would write $autostart (picom + dwmblocks + clipmenud + sxhkd + polkit-gnome + dwm-lock autostart)"
        return 0
    fi

    session_autostart_template >"$autostart"
    chmod 755 "$autostart"
    green "wrote   $autostart (picom + dwmblocks + clipmenud + sxhkd + polkit-gnome + dwm-lock)"
}

# The autostart.sh body, on stdout — two halves so neither exceeds the
# 60-line function cap. The seam is the one the file's own comments already
# draw: daemons found on PATH, then services named by absolute path.
#
# Every daemon added here needs a matching session_report_daemon call above,
# or existing installs are never told about it. tests/autostart-daemons.sh
# enforces that pairing by RUNNING this function rather than parsing it, so
# splitting it again later costs the test nothing.
session_autostart_template() {
    session_autostart_daemons
    session_autostart_services
}

# First half: the compositor, status feeder, clipboard and hotkey daemons.
# All four are plain binaries on PATH, so each is guarded with `command -v`
# (except dwmblocks, which the build installs unconditionally).
session_autostart_daemons() {
    cat <<'EOF'
#!/bin/sh
# Run by dwm's autostart patch at startup — see runautostart() in dwm.c.
# dwm backgrounds this whole script, so anything long-running below must be
# backgrounded individually and the script must exit.

# Compositor, first so windows are composited from the moment they appear
# rather than popping in unredirected. Reads ~/.config/picom/picom.conf, which
# the installer copies and the theming engine rewrites on every wallpaper
# change — without this line that whole config is dead weight and picom never
# runs at all.
#
# Backgrounded with & rather than picom's own -b: it keeps picom a child of
# this script, matching the three daemons below, and dwm already backgrounds
# autostart.sh as a whole.
if command -v picom >/dev/null 2>&1 && ! pgrep -x picom >/dev/null 2>&1; then
	picom &
fi

# Exactly one status feeder: dwm locates it by name (`pidof -s dwmblocks`, see
# STATUSBAR in config.def.h), so a second copy would make click routing
# ambiguous.
if ! pgrep -x dwmblocks >/dev/null 2>&1; then
	dwmblocks &
fi

# Clipboard history for dwm-clipmenu (Super+v) — only present if clipmenu's
# COPR was enabled (Fedora, via install-fedora.sh). Silently skipped
# elsewhere so this line is harmless on distros without it wired up yet.
if command -v clipmenud >/dev/null 2>&1 && ! pgrep -x clipmenud >/dev/null 2>&1; then
	clipmenud &
fi

# Hotkey daemon for everything dwm does not bind itself: media keys, volume,
# mic, brightness, theming and app launchers (~/.config/sxhkd/sxhkdrc). dwm
# keeps its own window-management bindings compiled in, and the two key sets
# are disjoint — see the ownership note at the top of sxhkdrc.
if command -v sxhkd >/dev/null 2>&1 && ! pgrep -x sxhkd >/dev/null 2>&1; then
	sxhkd &
fi

EOF
}

# Second half: services NOT on PATH, spelled out in full. Grouped for that
# reason as much as for the line cap — an absolute path is a portability
# liability, so the ones to re-check on a new distro are all in one place.
session_autostart_services() {
    cat <<'EOF'

# PolicyKit authentication agent — the dialog that asks for a password when a
# GUI program needs privileges: mounting a system disk from thunar, a package
# or partition tool, some NetworkManager operations. With no agent running
# those requests are simply denied, usually with no prompt and no error, so
# the feature looks broken rather than unauthorized.
#
# A desktop environment starts this from /etc/xdg/autostart. dwm has no
# session manager and nothing here reads that directory, so on this setup the
# line below is the only thing that ever launches it.
#
# Not guarded with `command -v` like the daemons above: the binary is not on
# PATH. It lives under libexec, and distributions disagree about where —
# Fedora uses /usr/libexec, Arch uses /usr/lib/polkit-gnome. Both are tried
# rather than one being guessed at.
if ! pgrep -f polkit-gnome-authentication-agent >/dev/null 2>&1; then
	if [ -x /usr/libexec/polkit-gnome-authentication-agent-1 ]; then
		/usr/libexec/polkit-gnome-authentication-agent-1 &
	elif [ -x /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 ]; then
		/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
	fi
fi

# Screen locking: arms X's idle timers, then execs `xss-lock -- slock` so the
# screen locks on inactivity AND on suspend. One line rather than the xset
# calls inline, deliberately — this file is yours the moment it exists and the
# installer will never edit it again, so the policy (timings, locker, logind
# routing) lives in the repo where it can still be changed. dwm-lock degrades
# on its own if xss-lock or xset is missing.
#
# Spelled out in full rather than relying on PATH: ~/.config/dwm/bin is added
# by config/zsh/.zshenv, which only runs if the display manager happens to
# start this session through a login zsh. The three daemons above are system
# binaries and need no such luck.
"${XDG_CONFIG_HOME:-$HOME/.config}/dwm/bin/dwm-lock" --daemon &
EOF
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
