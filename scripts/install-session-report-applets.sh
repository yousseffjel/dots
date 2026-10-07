#!/usr/bin/env bash
# The second half of session_autostart_report's daemon list — the desktop
# applets and the dwm-* services. Split out of install-session-report.sh at the
# 250-line cap (2026-10-07) and sourced by it; nothing else sources this file.
# Same assumptions as its parent: `set -euo pipefail` and the green/yellow
# helpers are the caller's.

# The rest of the list — split off purely for the 60-line function cap, the
# same way session_autostart_template is split into parts. Callers (and
# tests/autostart-daemons.sh) only ever call session_autostart_report.
# shellcheck disable=SC2016,SC2088
session_autostart_report_more() {
    local autostart="$1"

    session_report_daemon "$autostart" lxpolkit \
        'add this line yourself:  command -v lxpolkit >/dev/null && ! pgrep -x lxpolkit >/dev/null && lxpolkit &' \
        'without it no PolicyKit agent runs, so any GUI action needing' \
        'privileges (mounting a system disk, partition or package tools) is' \
        'denied with no password prompt and often no error at all.' \
        'If your autostart.sh still has the old polkit-gnome block, delete it:' \
        'that package is retired on Fedora 43 and 44, so its [ -x ] guards' \
        'never match and the block has been doing nothing.'

    session_report_daemon "$autostart" blueman-applet \
        'add this line yourself:  command -v blueman-applet >/dev/null && [ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ] && ! pgrep -x blueman-applet >/dev/null && blueman-applet &' \
        'without it there is no bluetooth tray icon; pairing still works' \
        'from blueman-manager (left-click the BT block).'

    session_report_daemon "$autostart" nm-applet \
        'add this line yourself:  command -v nm-applet >/dev/null && pgrep -x NetworkManager >/dev/null && ! pgrep -x nm-applet >/dev/null && nm-applet &' \
        'without it there is no network tray icon; Wi-Fi still works from' \
        'nmtui (left-click the NET block).'

    session_report_daemon "$autostart" xdg-user-dirs-update \
        'add this line yourself:  command -v xdg-user-dirs-update >/dev/null && xdg-user-dirs-update &' \
        'without it ~/Pictures, ~/Videos and the rest are never created or named,' \
        'and screenshots and recordings fall back to fixed English paths.'

    session_report_daemon "$autostart" dwm-lock \
        'add this line yourself:  "${XDG_CONFIG_HOME:-$HOME/.config}/dwm/bin/dwm-lock" --daemon &' \
        'without it the screen never locks on idle or on suspend.' \
        'Super+l still works — it falls back to calling slock directly.'

    session_report_daemon "$autostart" dwm-nightlight \
        'add this line yourself:  command -v gammastep >/dev/null && "${XDG_CONFIG_HOME:-$HOME/.config}/dwm/bin/dwm-nightlight" daemon &' \
        'without it there is no night light, and Super+n only applies it once' \
        'until the next brightness key.'
}
