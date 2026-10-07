#!/usr/bin/env bash
# Runs the generated ~/.xinitrc against a sandbox HOME and asserts what it does
# about the theme before `exec dwm`, and the systemd session target around
# dwm (started first, stopped after, never in dwm's way), and the session-end
# step that stops clipmenud however dwm exits.
#
# WHY. The first real install (Fedora 44 Server VM, 2026-10-05) came up on
# dwm's compiled-in colours with no wallpaper: a headless install cannot theme
# a desktop that is not running yet, and nothing applied the theme at login.
# session_xinitrc_template now does — and it has to be ~/.xinitrc, before dwm
# starts, because re-theming a running dwm restarts it and every dwm start
# re-runs autostart.sh. This test pins both halves: the theme step runs, and
# dwm starts no matter how that step goes.
#
# 2026-10-07: logging out of the VM left clipmenud — a shell loop holding no X
# connection — spinning on failed clipnotify/xsel calls, flooding ly's TTY.
# Every exit path must now end in dots_session_end, which stops it.
#
# HOW. The shipped function's output is RUN by /bin/sh with PATH holding only
# fakes (xrdb, dwm, timeout, pkill, id, and a dots in the sandbox's
# ~/.local/bin), so nothing reaches the real X server or the real theming
# engine — whose post-commands pkill dunst and dwmblocks system-wide. One
# substitution is made to the copy that runs: /etc/X11/xinit/xinitrc.d is pointed at an empty
# sandbox dir, since this host's own fragments (systemd user-env import,
# dbus) would otherwise be sourced into the run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# install-session.sh only defines functions (and sources its two siblings),
# so sourcing it runs nothing.
# shellcheck source=../scripts/install-session.sh
source "$DOTS_DIR/scripts/install-session.sh"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

mkdir -p "$SB/xinitrc.d"
session_xinitrc_template >"$SB/xinitrc.shipped"
sed "s|/etc/X11/xinit/xinitrc.d|$SB/xinitrc.d|g" "$SB/xinitrc.shipped" >"$SB/xinitrc"
if cmp -s "$SB/xinitrc.shipped" "$SB/xinitrc"; then
    red "the xinitrc.d substitution matched nothing — the fragment path moved;"
    red "   fix this test before it sources the host's real fragments"
    exit 1
fi

# $1 case; $2 "cache" to seed the theme cache; $3 "fehbg" to seed ~/.fehbg;
# $4 dots mode: ok | fail | absent; $5 systemctl mode: absent (default) | ok |
# fail (the start fails); $6 "hup" makes dwm HUP the xinitrc shell, the way a
# dying X server does. Prints the call log, one call per line.
run_case() {
    local home="$SB/$1" fake="$SB/$1/fakebin" log="$SB/$1/calls.log"
    mkdir -p "$fake" "$home/.local/bin" "$home/cache"
    : >"$log"
    local s
    for s in xrdb dwm pkill; do
        printf '#!/bin/sh\necho "%s $*" >>"%s"\n' "$s" "$log" >"$fake/$s"
    done
    # The $1/$@ belong to the fake script being written, not to this one.
    # shellcheck disable=SC2016
    printf '#!/bin/sh\necho "timeout $1" >>"%s"\nshift\nexec "$@"\n' "$log" >"$fake/timeout"
    printf '#!/bin/sh\necho 4242\n' >"$fake/id"
    [[ "$2" == cache ]] && { mkdir -p "$home/cache/dots/theme" && : >"$home/cache/dots/theme/xresources"; }
    [[ "$3" == fehbg ]] && printf '#!/bin/sh\necho fehbg >>"%s"\n' "$log" >"$home/.fehbg"
    case "$4" in
        ok) printf '#!/bin/sh\necho "dots $*" >>"%s"\n' "$log" >"$home/.local/bin/dots" ;;
        fail) printf '#!/bin/sh\necho "dots $*" >>"%s"\nexit 1\n' "$log" >"$home/.local/bin/dots" ;;
        absent) ;;
    esac
    # shellcheck disable=SC2016 # $PPID belongs to the fake
    [[ "${6:-}" == hup ]] && printf '#!/bin/sh\necho "dwm $*" >>"%s"\nkill -HUP $PPID\n' "$log" >"$fake/dwm"
    # shellcheck disable=SC2016 # $* belongs to the fakes
    case "${5:-absent}" in
        ok) printf '#!/bin/sh\necho "systemctl $*" >>"%s"\n' "$log" >"$fake/systemctl" ;;
        fail) printf '#!/bin/sh\necho "systemctl $*" >>"%s"\ncase "$*" in *start*) exit 1 ;; esac\n' "$log" >"$fake/systemctl" ;;
    esac
    chmod +x "$fake"/* "$home/.local/bin"/* "$home/.fehbg" 2>/dev/null || true
    env -i PATH="$fake" HOME="$home" XDG_CACHE_HOME="$home/cache" /bin/sh "$SB/xinitrc"
    # The cache path is per case; normalise it so expectations stay readable.
    sed "s|$home|HOME|g" "$log"
}

rc=0
expect() {
    local name="$1" want="$2" got="$3"
    if [[ "$got" == "$want" ]]; then
        green "  ok: $name"
    else
        red "  $name: expected:"
        printf '      %s\n' "$want"
        red "     got:"
        printf '      %s\n' "${got:-<nothing>}"
        rc=1
    fi
}

# What dots_session_end does on every exit path, before stopping the target.
END='pkill -u 4242 -x clipmenud
pkill -u 4242 -x clipnotify'

blue "==> theme step in the generated ~/.xinitrc"
expect "cache + wallpaper: merge, re-apply, then dwm" \
    "$(printf '%s\n' 'xrdb -merge HOME/cache/dots/theme/xresources' fehbg 'dwm ' "$END")" \
    "$(run_case cached cache fehbg ok)"
expect "cache, no wallpaper: merge only, then dwm" \
    "$(printf '%s\n' 'xrdb -merge HOME/cache/dots/theme/xresources' 'dwm ' "$END")" \
    "$(run_case cached-nowall cache '' ok)"
expect "first login: dots theme dark, bounded, then dwm" \
    "$(printf '%s\n' 'timeout 120' 'dots theme dark' 'dwm ' "$END")" \
    "$(run_case first-login '' '' ok)"
expect "first login, theme apply fails: dwm still starts" \
    "$(printf '%s\n' 'timeout 120' 'dots theme dark' 'dwm ' "$END")" \
    "$(run_case apply-fails '' '' fail)"
expect "no dots command at all: dwm still starts" \
    "$(printf '%s\n' 'dwm ' "$END")" \
    "$(run_case no-dots '' '' absent)"

blue "==> the session target around dwm"
ST='systemctl --user import-environment DISPLAY XAUTHORITY
systemctl --user daemon-reload
systemctl --user start dots-session.target'
expect "systemd: target started before dwm, stopped after it exits" \
    "$(printf '%s\n' 'xrdb -merge HOME/cache/dots/theme/xresources' "$ST" 'dwm ' "$END" 'systemctl --user stop dots-session.target')" \
    "$(run_case target cache '' ok ok)"
expect "the start fails: dwm still starts, no target to stop" \
    "$(printf '%s\n' 'xrdb -merge HOME/cache/dots/theme/xresources' "$ST" 'dwm ' "$END")" \
    "$(run_case target-fails cache '' ok fail)"
# On bash — Fedora's /bin/sh — the EXIT trap fires on a fatal HUP even without
# the template's `trap 'exit 0' HUP INT TERM`, so this case cannot tell that
# line is there (mutation-tested 2026-10-06: dropping it survives). The line is
# for strict POSIX shells such as dash, where an untrapped signal skips EXIT.
expect "X dies (HUP to the session shell): the target is still stopped" \
    "$(printf '%s\n' 'xrdb -merge HOME/cache/dots/theme/xresources' "$ST" 'dwm ' "$END" 'systemctl --user stop dots-session.target')" \
    "$(run_case target-hup cache '' ok ok hup)"
expect "no systemd, X dies: clipmenud is still stopped" \
    "$(printf '%s\n' 'xrdb -merge HOME/cache/dots/theme/xresources' 'dwm ' "$END")" \
    "$(run_case nosystemd-hup cache '' ok absent hup)"
unit="$DOTS_DIR/config/systemd/user/dots-session.target"
if grep -qx 'BindsTo=graphical-session.target' "$unit" && grep -q 'dots-session.target' "$SB/xinitrc.shipped" \
    && grep -qF 'config/systemd/user/dots-session.target' "$DOTS_DIR/scripts/install-restore-apps.sh"; then
    green "  ok: the unit binds graphical-session.target, and restore deploys the one the template starts"
else
    red "  the unit, the template and the deploy line disagree about dots-session.target"
    rc=1
fi

blue "==> report on an existing ~/.xinitrc"
report() {
    (
        # Called indirectly from session_xinitrc_report. Both codes are
        # disabled for the 0.10.0 rename - see tests/autostart-daemons.sh.
        # shellcheck disable=SC2317,SC2329
        green() { printf '%s\n' "$*"; }
        # shellcheck disable=SC2317,SC2329
        yellow() { printf '%s\n' "$*"; }
        session_xinitrc_report "$1"
    )
}
if grep -q -- '^ok ' <<<"$(report "$SB/xinitrc.shipped")"; then
    green "  ok: the generated file is recognised"
else
    red "  the generated ~/.xinitrc is reported as not restoring the theme"
    rc=1
fi
printf '#!/bin/sh\nexec dwm\n' >"$SB/old-xinitrc"
out="$(report "$SB/old-xinitrc")"
if grep -q -- 'never restores the dots theme' <<<"$out" && grep -q -- 'never starts dots-session.target' <<<"$out" \
    && ! grep -q -- 'never stops clipmenud' <<<"$out"; then
    green "  ok: a pre-2026-10-05 ~/.xinitrc is reported, for both"
else
    red "  an ~/.xinitrc with neither step was NOT reported for both"
    rc=1
fi
# What the installer generated between 2026-10-05 and 2026-10-06: the theme
# block, no session target. Built from the shipped template, not by hand.
{ sed '/^# Session end/,$d' "$SB/xinitrc.shipped" && echo 'exec dwm'; } >"$SB/pre-portal-xinitrc"
out="$(report "$SB/pre-portal-xinitrc")"
if ! grep -q 'dots-session.target' "$SB/pre-portal-xinitrc" && grep -q -- 'never starts dots-session.target' <<<"$out" \
    && ! grep -q -- 'never restores the dots theme' <<<"$out"; then
    green "  ok: a themed but pre-portal ~/.xinitrc gets only the session-target lines"
else
    red "  the pre-portal ~/.xinitrc report is wrong: $out"
    rc=1
fi

# 2026-10-06 to 2026-10-07: a session target, no session-end step. Its exact
# block is gone from the template, so only its marker is reproduced.
{ sed '$d' "$SB/pre-portal-xinitrc" && printf '%s\n' \
    'systemctl --user start dots-session.target && { dwm; exit 0; }' 'exec dwm'; } >"$SB/pre-cleanup-xinitrc"
out="$(report "$SB/pre-cleanup-xinitrc")"
# shellcheck disable=SC2016 # the $(id -u) is the paste line's, matched literally
if grep -q -- 'never stops clipmenud at logout' <<<"$out" && grep -qF -- '            pkill -u "$(id -u)" -x clipmenud' <<<"$out" \
    && ! grep -q -- 'never starts dots-session.target' <<<"$out" && ! grep -q -- 'never restores' <<<"$out"; then
    green "  ok: a pre-cleanup ~/.xinitrc gets only the session-end lines"
else
    red "  the pre-cleanup ~/.xinitrc report is wrong: $out"
    rc=1
fi

# The paste lines live twice — printed by the installer, documented for anyone
# who never re-runs it. Every printed line must appear in the doc's block.
missing=0
while IFS= read -r line; do
    grep -qxF "$line" "$DOTS_DIR/docs/THEMING.md" || {
        red "  docs/THEMING.md lacks the paste line: $line"
        missing=1
    }
done < <(report "$SB/old-xinitrc" | sed -n '/never starts dots-session.target/,$p' | sed -n 's/^          //p')
if ((missing == 0)); then
    green "  ok: docs/THEMING.md carries every session-target paste line"
else
    rc=1
fi

if ((rc != 0)); then
    red "✗ xinitrc theme restore"
    exit 1
fi
green "✓ xinitrc theme restore"
