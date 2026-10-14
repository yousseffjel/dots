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

# Report on a ~/.xinitrc the user already has. Never edits it, for the same
# reason as autostart.sh above. Five markers, checked independently, because
# files generated by earlier installers carry only a prefix of them:
#   * the cache path the theme block reads — without it every login starts at
#     dwm's compiled-in colours (since 2026-10-05);
#   * the xcursor merge — without it dwm and other non-GTK clients get the
#     cursor SIZE libXcursor guesses; the theme itself still arrives through
#     icons/default/index.theme, which needs no .xinitrc (2026-10-07);
#   * dots-session.target — without it no desktop portal can start (2026-10-06);
#   * dots_session_end — without it clipmenud outlives X and floods the login
#     TTY at logout (2026-10-07);
#   * a dwmblocks pkill inside it — without it a quick re-login finds the old
#     dwmblocks and night-light daemon, starts neither, and the bar stays empty
#     once they die (2026-10-07, later the same day);
#   * an xss-lock pkill inside it — without it xss-lock aborts with a core
#     dump at every logout when X vanishes under it (2026-10-12).
# The last four share one paste block (the cleanup replaces the session tail)
# while dots_session_end is missing; once it exists, a missing dwmblocks or
# xss-lock stop gets only its own lines (session_xinitrc_report_stops).
session_xinitrc_report() {
    local xinitrc="$1" theme=0 cursor=0 session=0 ended=0 blocks=0 xsslock=0
    grep -q 'dots/theme' "$xinitrc" && theme=1
    grep -q '/xcursor' "$xinitrc" && cursor=1
    grep -q 'dots-session.target' "$xinitrc" && session=1
    grep -q 'dots_session_end' "$xinitrc" && ended=1
    grep -q 'pkill.*dwmblocks' "$xinitrc" && blocks=1
    grep -q 'pkill.*xss-lock' "$xinitrc" && xsslock=1
    if ((theme && cursor && session && ended && blocks && xsslock)); then
        green "ok      ~/.xinitrc exists, restores the dots theme and starts and ends the session"
        return 0
    fi
    ((theme)) || session_xinitrc_report_theme
    ((!theme || cursor)) || session_xinitrc_report_cursor
    if ((!session)); then
        session_xinitrc_report_session 'never starts dots-session.target' \
            'without it no desktop portal starts: GTK4/libadwaita apps stay light' \
            'and apps get no portal file chooser.'
    elif ((!ended)); then
        session_xinitrc_report_session 'never stops clipmenud at logout' \
            'without it clipmenud outlives X and floods the login TTY with' \
            '"xsel: Can'"'"'t open display" errors.'
    else
        session_xinitrc_report_stops "$blocks" "$xsslock"
    fi
}

# The file already has dots_session_end and lacks only some of its stops, so
# print only those lines — not the whole block (on the Fedora VM, 2026-10-12,
# the full block was printed for one missing line). $1 $2: whether the
# dwmblocks and xss-lock stops are already there.
# shellcheck disable=SC2016
session_xinitrc_report_stops() {
    if (($1 == 0)); then
        yellow "kept    ~/.xinitrc (exists, never stops dwmblocks at logout)"
        yellow '        after a quick re-login the bar can stay empty ("dwm-6.8") and night'
        yellow '        light off: the old copies are found, so no new ones start.'
    fi
    if (($2 == 0)); then
        yellow "kept    ~/.xinitrc (exists, never stops xss-lock at logout)"
        yellow '        without it xss-lock aborts with a core dump every time X closes'
        yellow '        (harmless, but each one is a crash report).'
    fi
    yellow '        Add inside dots_session_end(), above its systemctl line:'
    if (($1 == 0)); then
        yellow '            pkill -u "$(id -u)" -x dwmblocks'
        yellow "            pkill -u \"\$(id -u)\" -f '/dwm-nightlight daemon\$'"
    fi
    (($2)) || yellow '            pkill -u "$(id -u)" -x xss-lock'
    yellow '        then log out and back in.'
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
    yellow '          [ -r "$c/xcursor" ] && xrdb -merge "$c/xcursor"'
}

# A themed ~/.xinitrc from before 2026-10-07: only the cursor merge is missing.
# shellcheck disable=SC2016
session_xinitrc_report_cursor() {
    yellow "kept    ~/.xinitrc (exists, never loads the cursor size)"
    yellow '        dwm and other non-GTK apps may draw the cursor at a different size'
    yellow '        than GTK apps. Add this line right after the xresources merge:'
    yellow '          c="${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme"; [ -r "$c/xcursor" ] && xrdb -merge "$c/xcursor"'
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
    yellow '            pkill -u "$(id -u)" -x dwmblocks'
    yellow "            pkill -u \"\$(id -u)\" -f '/dwm-nightlight daemon\$'"
    yellow '            pkill -u "$(id -u)" -x xss-lock'
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
