#!/usr/bin/env bash
# The autostart.sh BODY, on stdout — split out of install-session.sh when that
# file crossed the 250-line cap (file-architecture.md) on the addition of the
# udiskie and autorandr entries. Exactly the seam the reporting half took at the
# same cap: install-session.sh keeps the orchestration (decide whether to write,
# write it, report if it already exists), this file is the content it writes.
#
# Three parts purely for the 60-line function cap — "what paints the screen",
# "interaction and devices", then "services not on PATH". Callers use
# session_autostart_template; tests/autostart-daemons.sh calls only that and
# session_autostart_report, never the parts, so re-splitting costs it nothing.
#
# Every entry needs a paired session_report_daemon call in
# install-session-report.sh AND a name in that test's DAEMONS roster — see
# CLAUDE.md rule 6. The test fails the build if either is missing.
#
# Sourced by install-session.sh only. Assumes the caller has already
# `set -euo pipefail`.

# The autostart.sh body, on stdout — three parts so none exceeds the 60-line
# function cap. The original seam was "daemons on PATH, then services named by
# absolute path"; the PATH half then reached 57 of 60 and was split again on a
# second seam: what paints the screen, then what serves interaction and devices.
#
# Every daemon added here needs a matching session_report_daemon call in
# install-session-report.sh, or existing installs are never told about it.
# tests/autostart-daemons.sh enforces that pairing by RUNNING both sides
# rather than parsing them — and it calls only these two entry points, never
# the parts, which is why splitting again has cost that test nothing twice now.
session_autostart_template() {
    session_autostart_display
    session_autostart_daemons
    session_autostart_services
}

# Part one: everything that decides how the screen looks. Ordered deliberately
# — compositor first so windows are composited from the moment they appear,
# then the settings daemon, then the display layout.
session_autostart_display() {
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

# XSETTINGS daemon. Serves the GTK theme identity and the Xft font-rendering
# keys (antialias, hinting, RGBA) from ~/.config/xsettingsd/xsettingsd.conf,
# written by the installer from themes/dark/theme.conf. Without it GTK apps
# fall back to their own per-toolkit rendering defaults.
#
# No -c flag: xsettingsd 1.0.2 reads $XDG_CONFIG_HOME/xsettingsd/xsettingsd.conf
# on its own (its --help text still claims ~/.xsettingsd and is stale —
# verified against the binary). Passing the path here would duplicate the
# installer's choice of it in a second place.
if command -v xsettingsd >/dev/null 2>&1 && ! pgrep -x xsettingsd >/dev/null 2>&1; then
	xsettingsd &
fi

# Display layout. autorandr fingerprints the connected monitors by EDID and
# re-applies the matching profile saved with `autorandr --save <name>`; --change
# picks the profile whose fingerprint matches right now.
#
# The package ships an XDG autostart file for exactly this, but nothing on this
# setup reads /etc/xdg/autostart — dwm has no session manager. Same reason the
# polkit agent is spelled out below. The udev rule the package ships is
# unaffected and still handles hotplug; this line covers session start.
#
# Unlike every other entry here this is a ONE-SHOT, not a daemon: it exits as
# soon as the layout is applied. It is still backgrounded so autostart.sh never
# blocks on an xrandr round-trip, and so it stays inside the launch/report
# pairing that tests/autostart-daemons.sh enforces. It carries no `pgrep` guard
# for the same reason — there is never a process to find, and re-running it
# after a dwm restart is idempotent.
if command -v autorandr >/dev/null 2>&1; then
	autorandr --change &
fi
EOF
}

# Part two: interaction and devices. Every entry is a plain binary on PATH, so
# each is guarded with `command -v` — except dwmblocks, which the suckless
# build installs unconditionally alongside dwm itself.
session_autostart_daemons() {
    cat <<'EOF'

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

# Removable media: auto-mounts USB sticks and SD cards and reports them through
# dunst. thunar-volman does this too, but only while Thunar is running, and
# nothing here daemonises Thunar — so without this line removable media has to
# be mounted by hand.
#
# --automount and --notify are udiskie's defaults; they are named anyway so the
# behaviour is stated in the file the user actually reads, and so a future
# change of defaults cannot silently disable either. --smart-tray shows a tray
# icon only while something is mounted, which suits a bar that is otherwise
# empty; dwm's systray patch provides the host for it.
if command -v udiskie >/dev/null 2>&1 && ! pgrep -x udiskie >/dev/null 2>&1; then
	udiskie --automount --notify --smart-tray &
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
