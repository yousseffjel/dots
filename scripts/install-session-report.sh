#!/usr/bin/env bash
# What to tell someone who ALREADY has an autostart.sh — the reporting half
# of install-session.sh.
#
# Split out when install-session.sh reached the 250-line cap
# (file-architecture.md), the same split install-restore.sh makes with
# install-restore-theme.sh. The seam is the one install-session.sh's own
# comments already drew: generating the file for a fresh machine versus
# reporting on one that exists. CLAUDE.md rule 6 makes that file the user's
# the moment it exists, so those are genuinely different jobs — one writes,
# the other may only ever print.
#
# Sourced by install-session.sh, never standalone: every function here
# assumes the caller has already `set -euo pipefail` and defined the
# green/yellow helpers.
#
# usage: source "$SCRIPT_DIR/install-session-report.sh"

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
# Every daemon named here needs a matching launch in
# session_autostart_template() (install-session.sh), or fresh installs get
# nagged about a line they already have. tests/autostart-daemons.sh enforces
# that pairing by RUNNING both sides rather than parsing them, so this file
# being separate from the template costs the test nothing.
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
