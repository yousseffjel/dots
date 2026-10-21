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
#
# The applets' half of the daemon list (session_autostart_report_more) lives in
# install-session-report-applets.sh, split at the 250-line cap (2026-10-07) —
# sourced here from BASH_SOURCE, so the doctor and the tests that source this
# file still get the whole report.
SESSION_REPORT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install-session-report-applets.sh
source "$SESSION_REPORT_DIR/install-session-report-applets.sh"
# The ~/.xinitrc half: its own file at the 250-line cap, like the applets.
# shellcheck source=install-session-report-xinitrc.sh
source "$SESSION_REPORT_DIR/install-session-report-xinitrc.sh"

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

# Asks whether an existing autostart.sh lets dwm-picom choose picom's backend.
# One written before 2026-10-05 starts picom on the config's glx backend
# unconditionally, which freezes the screen on a GPU without 3D acceleration;
# one written before 2026-10-14 carries its own inline glxinfo probe, which
# misses a VM with 3D passed through and can never be updated (rule 6). Both
# are told to switch to `dwm-picom &`. session_report_daemon only asks whether
# picom is MENTIONED, so it calls such a file fine. Worded without "does not mention" on purpose:
# tests/autostart-daemons.sh reads daemon names out of exactly that phrase.
# shellcheck disable=SC2016
session_report_picom_probe() {
    local autostart="$1"

    grep -q picom "$autostart" || return 0
    grep -q dwm-picom "$autostart" && return 0

    yellow "kept    $autostart (chooses picom's backend itself)"
    if ! grep -q -- '--backend' "$autostart"; then
        yellow '        it starts picom on the glx backend in picom.conf, which freezes'
        yellow '        the screen on a GPU without 3D acceleration (most VMs).'
    fi
    yellow '        dwm-picom now makes that choice (xrender in a VM or without'
    yellow '        hardware 3D, glx on a real GPU) and is updated with dots.'
    yellow '        Replace your picom lines with:'
    yellow '          dwm-picom &'
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
    session_report_picom_probe "$autostart"

    session_report_daemon "$autostart" dwmblocks \
        'add this line yourself:  pgrep -x dwmblocks >/dev/null || dwmblocks &'

    session_report_daemon "$autostart" clipmenud \
        "add this line yourself:  command -v clipmenud >/dev/null && ! pgrep -u \"\$(id -u)\" -f '/clipmenud\$' >/dev/null && clipmenud &"

    session_report_daemon "$autostart" sxhkd \
        'add this line yourself:  command -v sxhkd >/dev/null && ! pgrep -x sxhkd >/dev/null && sxhkd &' \
        'without it every binding in config/sxhkd/sxhkdrc is dead —' \
        'media keys, volume, brightness, theming and app launchers.'

    session_report_daemon "$autostart" xsettingsd \
        'add this line yourself:  command -v xsettingsd >/dev/null && ! pgrep -x xsettingsd >/dev/null && xsettingsd &' \
        'without it GTK apps ignore ~/.config/xsettingsd/xsettingsd.conf —' \
        'Xft antialiasing, hinting and RGBA fall back to toolkit defaults.'

    session_report_daemon "$autostart" udiskie \
        'add this line yourself:  command -v udiskie >/dev/null && ! pgrep -x udiskie >/dev/null && udiskie --automount --notify --smart-tray &' \
        'without it USB sticks and SD cards never auto-mount — thunar-volman' \
        'only does that while Thunar is running, and nothing daemonises it.'

    session_report_daemon "$autostart" autorandr \
        'add this line yourself:  command -v autorandr >/dev/null && autorandr --change &' \
        'without it a saved display profile is never applied at session start.' \
        'Hotplug still works: that is the udev rule the package ships, not this.'

    session_report_daemon "$autostart" spice-vdagent \
        'add this line yourself:  command -v spice-vdagent >/dev/null && grep -qw hypervisor /proc/cpuinfo && ! pgrep -x spice-vdagent >/dev/null && spice-vdagent &' \
        'only matters inside a VM: without it the screen never resizes to' \
        'the viewer window and the host clipboard is not shared.'

    session_autostart_report_more "$autostart"
}
