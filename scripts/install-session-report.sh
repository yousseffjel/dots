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

# An autostart.sh written before 2026-10-05 starts picom on the config's glx
# backend unconditionally, which freezes the screen on a GPU without 3D
# acceleration (see session_autostart_compositor). session_report_daemon only
# asks whether picom is MENTIONED, so it calls such a file fine; this asks
# whether the backend is chosen. Worded without "does not mention" on purpose:
# tests/autostart-daemons.sh reads daemon names out of exactly that phrase.
# shellcheck disable=SC2016
session_report_picom_probe() {
    local autostart="$1"

    grep -q picom "$autostart" || return 0
    grep -q -- '--backend' "$autostart" && return 0

    yellow "kept    $autostart (starts picom without choosing a backend)"
    yellow '        on a GPU without 3D acceleration (most VMs) the glx backend in'
    yellow '        picom.conf freezes the screen. Either start it as:'
    yellow '          picom --backend xrender &'
    yellow '        or copy the glxinfo probe from a freshly generated autostart.sh:'
    yellow '          rm the file, re-run scripts/install-fedora.sh --only-install'
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
        'add this line yourself:  command -v clipmenud >/dev/null && ! pgrep -x clipmenud >/dev/null && clipmenud &'

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
        'add this line yourself:  command -v spice-vdagent >/dev/null && systemd-detect-virt --vm -q && ! pgrep -x spice-vdagent >/dev/null && spice-vdagent &' \
        'only matters inside a VM: without it the screen never resizes to' \
        'the viewer window and the host clipboard is not shared.'

    session_autostart_report_more "$autostart"
}

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

    session_report_daemon "$autostart" dwm-lock \
        'add this line yourself:  "${XDG_CONFIG_HOME:-$HOME/.config}/dwm/bin/dwm-lock" --daemon &' \
        'without it the screen never locks on idle or on suspend.' \
        'Super+l still works — it falls back to calling slock directly.'

    session_report_daemon "$autostart" dwm-nightlight \
        'add this line yourself:  command -v gammastep >/dev/null && "${XDG_CONFIG_HOME:-$HOME/.config}/dwm/bin/dwm-nightlight" daemon &' \
        'without it there is no night light, and Super+n only applies it once' \
        'until the next brightness key.'
}

# Report on a ~/.xinitrc the user already has. Never edits it, for the same
# reason as autostart.sh above. Three markers, checked independently, because
# files generated by earlier installers carry only a prefix of them:
#   * the cache path the theme block reads — without it every login starts at
#     dwm's compiled-in colours (since 2026-10-05);
#   * dots-session.target — without it no desktop portal can start (2026-10-06);
#   * dots_session_end — without it clipmenud outlives X and floods the login
#     TTY at logout (2026-10-07).
# The last two share one paste block: the cleanup replaces the session tail.
session_xinitrc_report() {
    local xinitrc="$1" theme=0 session=0 ended=0
    grep -q 'dots/theme' "$xinitrc" && theme=1
    grep -q 'dots-session.target' "$xinitrc" && session=1
    grep -q 'dots_session_end' "$xinitrc" && ended=1
    if ((theme && session && ended)); then
        green "ok      ~/.xinitrc exists, restores the dots theme and starts and ends the session"
        return 0
    fi
    ((theme)) || session_xinitrc_report_theme
    if ((!session)); then
        session_xinitrc_report_session 'never starts dots-session.target' \
            'without it no desktop portal starts: GTK4/libadwaita apps stay light' \
            'and apps get no portal file chooser.'
    elif ((!ended)); then
        session_xinitrc_report_session 'never stops clipmenud at logout' \
            'without it clipmenud outlives X and floods the login TTY with' \
            '"xsel: Can'"'"'t open display" errors.'
    fi
}

# The paste-in lines a ~/.xinitrc needs; split out for the 60-line cap.
# shellcheck disable=SC2016,SC2088
session_xinitrc_report_theme() {
    yellow "kept    ~/.xinitrc (exists, never restores the dots theme)"
    yellow '        without it dwm starts on its compiled-in colours and no wallpaper.'
    yellow '        Add these lines above `exec dwm` (NOT in autostart.sh — re-theming'
    yellow '        a running dwm restarts it, and every start re-runs autostart.sh):'
    yellow '          c="${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme"'
    yellow '          if [ -r "$c/xresources" ]; then xrdb -merge "$c/xresources"; [ -x ~/.fehbg ] && ~/.fehbg'
    yellow '          else "$HOME/.local/bin/dots" theme dark; fi'
}

# $1 what the file lacks, $2 $3 what that costs. One block fixes either lack.
# shellcheck disable=SC2016
session_xinitrc_report_session() {
    yellow "kept    ~/.xinitrc (exists, $1)"
    yellow "        $2"
    yellow "        $3 Replace \`exec dwm\` — and any"
    yellow '        dots-session.target block above it — with:'
    yellow '          dots_session_target='
    yellow '          dots_session_end() {'
    yellow '            pkill -u "$(id -u)" -x clipmenud'
    yellow '            pkill -u "$(id -u)" -x clipnotify'
    yellow '            [ -z "$dots_session_target" ] || systemctl --user stop dots-session.target'
    yellow '          }'
    yellow '          trap dots_session_end EXIT'
    yellow "          trap 'exit 0' HUP INT TERM"
    yellow '          systemctl --user import-environment DISPLAY XAUTHORITY'
    yellow '          systemctl --user daemon-reload'
    yellow '          systemctl --user start dots-session.target && dots_session_target=1'
    yellow '          dwm'
    yellow '        then log out and back in.'
}
