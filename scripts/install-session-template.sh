#!/usr/bin/env bash
# The autostart.sh BODY, on stdout — split out of install-session.sh when that
# file crossed the 250-line cap (file-architecture.md) on the addition of the
# udiskie and autorandr entries. Exactly the seam the reporting half took at the
# same cap: install-session.sh keeps the orchestration (decide whether to write,
# write it, report if it already exists), this file is the content it writes.
#
# Five parts purely for the 60-line function cap — the compositor, the rest of
# "what paints the screen", "interaction and devices", the desktop applets
# (their own file), then "services not on PATH". Callers use
# session_autostart_template; tests/autostart-daemons.sh calls only that and
# session_autostart_report, never the parts, so re-splitting costs it nothing.
#
# Every entry needs a paired session_report_daemon call in
# install-session-report.sh AND a name in that test's DAEMONS roster — see
# CLAUDE.md rule 6. The test fails the build if either is missing.
#
# Sourced by install-session.sh and by tests. Assumes the caller has already
# `set -euo pipefail`.
#
# The desktop applets (part four) live in install-session-template-applets.sh,
# split at the 250-line cap (2026-10-07). Sourced here, resolved from
# BASH_SOURCE like install-restore-theme.sh's sibling, so every caller of this
# file gets the whole template without knowing about the split.
SESSION_TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install-session-template-applets.sh
source "$SESSION_TEMPLATE_DIR/install-session-template-applets.sh"

# The autostart.sh body, on stdout — five parts so none exceeds the 60-line
# function cap. The original seam was "daemons on PATH, then services named by
# absolute path"; the PATH half then reached 57 of 60 and was split again on a
# second seam: what paints the screen, then what serves interaction and devices.
# The compositor took a part of its own when it grew a GL probe (2026-10-05).
#
# Every daemon added here needs a matching session_report_daemon call in
# install-session-report.sh, or existing installs are never told about it.
# tests/autostart-daemons.sh enforces that pairing by RUNNING both sides
# rather than parsing them — and it calls only these two entry points, never
# the parts, which is why splitting again has cost that test nothing twice now.
session_autostart_template() {
    session_autostart_compositor
    session_autostart_display
    session_autostart_daemons
    session_autostart_applets
    session_autostart_services
}

# Part one: the file header and the compositor, first so windows are composited
# from the moment they appear. Its own part because of the GL probe below.
session_autostart_compositor() {
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
# The backend is chosen by dwm-picom (~/.config/dwm/bin, linked from the
# repo), overriding the config's `backend = "glx"`: xrender in a virtual
# machine or without hardware 3D, glx only on a real GPU. A VM's glx froze
# the screen on the first real install (2026-10-05). Keeping that decision in
# a linked script, not in this file, means a fix to it reaches this install
# too — this file is yours once it exists. Without dwm-picom on PATH, plain
# xrender: a slower compositor beats a frozen one.
#
# Backgrounded with & rather than picom's own -b: dwm-picom execs picom, so
# picom stays a child of this script, matching the daemons below.
if command -v dwm-picom >/dev/null 2>&1; then
	dwm-picom &
elif command -v picom >/dev/null 2>&1 && ! pgrep -x picom >/dev/null 2>&1; then
	picom --backend xrender &
fi
EOF
}

# Part two: the rest of what decides how the screen looks — the settings
# daemon, then the display layout.
session_autostart_display() {
    cat <<'EOF'

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
# setup reads /etc/xdg/autostart — dwm has no session manager. The polkit agent
# below is launched for the same reason. The udev rule the package ships is
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

# SPICE guest agent, inside a VM only: resizes the screen to the viewer window
# (virt-manager: View > Scale Display > Auto resize VM with window) and shares
# the clipboard with the host. A desktop environment starts it from
# /etc/xdg/autostart, which nothing reads here — same as autorandr above. The
# system half, spice-vdagentd, is a runit service the services stage enables
# in a VM (if resizing does nothing, `sudo sv status spice-vdagentd` is the
# first check). "Inside a VM" is the kernel's hypervisor CPU flag, the same
# test scripts/drivers-detect.sh starts from (no systemd-detect-virt on Void).
if command -v spice-vdagent >/dev/null 2>&1 && grep -qw hypervisor /proc/cpuinfo 2>/dev/null \
	&& ! pgrep -x spice-vdagent >/dev/null 2>&1; then
	spice-vdagent &
fi
EOF
}

# Part three: interaction and devices. Every entry is a plain binary on PATH, so
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

# Clipboard history for dwm-clipmenu (Super+v) — clipmenu is in
# packages/desktop.lst. Silently skipped when it is not installed, so this
# line is harmless if that package failed. Matched by -f: clipmenud is an
# env-bash script, so its process is named "bash" and -x never finds it.
if command -v clipmenud >/dev/null 2>&1 && ! pgrep -u "$(id -u)" -f '/clipmenud$' >/dev/null 2>&1; then
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

# Hides the mouse pointer after 5 idle seconds; the next move brings it back.
# unclutter-xfixes (packages/extra.lst) — it hides the pointer through XFixes,
# so no window is created and focus never moves. An X client: it dies with the
# server and needs no line at logout.
if command -v unclutter >/dev/null 2>&1 && ! pgrep -x unclutter >/dev/null 2>&1; then
	unclutter --timeout 5 &
fi

EOF
}

# Part five: services NOT on PATH, spelled out in full. Grouped for that
# reason as much as for the line cap — an absolute path is a portability
# liability, so the ones to re-check on a new distro are all in one place.
#
# The polkit agent lived here until 2026-08-13, when polkit-gnome (whose binary
# sat under libexec, in a location Fedora and Arch disagreed about) was replaced
# by lxpolkit. That binary IS on PATH, so it moved up to the guarded daemons and
# the two-branch absolute-path fallback went with it.
session_autostart_services() {
    cat <<'EOF'

# Screen locking: arms X's idle timers, then execs `xss-lock -- slock` so the
# screen locks on inactivity AND on suspend. One line rather than the xset
# calls inline, deliberately — this file is yours the moment it exists and the
# installer will never edit it again, so the policy (timings, locker, logind
# routing) lives in the repo where it can still be changed. dwm-lock degrades
# on its own if xss-lock or xset is missing.
#
# Spelled out in full rather than relying on PATH: ~/.config/dwm/bin is added
# by config/zsh/.zshenv, which only runs if the display manager happens to
# start this session through a login zsh. Everything launched above is a system
# binary in /usr/bin and needs no such luck — which is why this one is the
# odd case, not a count of the others that would go stale the next time one is
# added.
"${XDG_CONFIG_HOME:-$HOME/.config}/dwm/bin/dwm-lock" --daemon &

# Night light: warmer colours from dusk to dawn (Super+n toggles). It is also
# what the brightness keys go through while it runs — both set the same gamma
# ramps, so one program must own them. A second launch after a dwm restart
# exits by itself.
if command -v gammastep >/dev/null 2>&1; then
	"${XDG_CONFIG_HOME:-$HOME/.config}/dwm/bin/dwm-nightlight" daemon &
fi

# Volume and mic blocks: the bar draws them only when signalled, and the level
# WirePlumber restores at login lands after the first draw. This follows
# PipeWire's events and redraws them. It ends with PipeWire at logout, and a
# second launch after a dwm restart exits by itself.
"${XDG_CONFIG_HOME:-$HOME/.config}/dwm/bin/dwm-audiowatch" &

# Super+a, the region screenshot, read WITHOUT a key grab so an open browser
# dropdown survives into the shot (sxhkd's grab would close it). It ends with
# the X server, and a second launch after a dwm restart exits by itself.
"${XDG_CONFIG_HOME:-$HOME/.config}/dwm/bin/dwm-shotkey" &
EOF
}
