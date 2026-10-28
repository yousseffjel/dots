#!/usr/bin/env bash
# Part four of the autostart.sh body: the desktop applets and agents a desktop
# environment would start from /etc/xdg/autostart, which nothing in a dwm
# session reads. Split out of install-session-template.sh at the 250-line cap
# (2026-10-07); sourced by it, never by anything else — callers keep using
# session_autostart_template.
#
# Same contract as every other part (CLAUDE.md rule 6): each entry needs a
# session_report_daemon call (install-session-report*.sh) and a name in
# tests/autostart-daemons.sh's DAEMONS.

session_autostart_applets() {
    cat <<'EOF'
# PolicyKit authentication agent — the dialog that asks for a password when a
# GUI program needs privileges: mounting a system disk from thunar, a package
# or partition tool, some NetworkManager operations. With no agent running
# those requests are simply denied, usually with no prompt and no error, so
# the feature looks broken rather than unauthorized.
#
# A desktop environment starts this from /etc/xdg/autostart. dwm has no session
# manager and nothing here reads that directory, so the line below is the only
# thing that ever launches it.
if command -v lxpolkit >/dev/null 2>&1 && ! pgrep -x lxpolkit >/dev/null 2>&1; then
	lxpolkit &
fi

# The XDG user directories (~/Pictures, ~/Videos, ...) and the
# ~/.config/user-dirs.dirs that names them — what `xdg-user-dir PICTURES`
# reads, and so where screenshots and recordings land. Fedora's desktops run
# this at every login from /etc/xdg/autostart. It creates only what is missing
# and follows a locale change, so every login is the intended cadence; it is
# not a daemon and exits at once.
if command -v xdg-user-dirs-update >/dev/null 2>&1; then
	xdg-user-dirs-update &
fi

# Apps that asked to start at login (~/.config/autostart, where an app's own
# "start at login" switch writes). Once per session: dwm re-runs this file on
# every restart, and the script remembers that it already ran (docs/DESKTOP.md).
"${XDG_CONFIG_HOME:-$HOME/.config}/dwm/bin/dwm-xdg-autostart" &

# The login chime, once per session like the line above (`dwm-sound off`
# silences it and every other desktop sound; docs/DESKTOP.md).
"${XDG_CONFIG_HOME:-$HOME/.config}/dwm/bin/dwm-sound" --login &

EOF
}
