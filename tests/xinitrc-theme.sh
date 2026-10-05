#!/usr/bin/env bash
# Runs the generated ~/.xinitrc against a sandbox HOME and asserts what it does
# about the theme before `exec dwm`.
#
# WHY. The first real install (Fedora 44 Server VM, 2026-10-05) came up on
# dwm's compiled-in colours with no wallpaper: a headless install cannot theme
# a desktop that is not running yet, and nothing applied the theme at login.
# session_xinitrc_template now does — and it has to be ~/.xinitrc, before dwm
# starts, because re-theming a running dwm restarts it and every dwm start
# re-runs autostart.sh. This test pins both halves: the theme step runs, and
# dwm is exec'd no matter how that step goes.
#
# HOW. The shipped function's output is RUN by /bin/sh with PATH holding only
# fakes (xrdb, dwm, timeout, and a dots in the sandbox's ~/.local/bin), so
# nothing reaches the real X server or the real theming engine — whose
# post-commands pkill dunst and dwmblocks system-wide. One substitution is
# made to the copy that runs: /etc/X11/xinit/xinitrc.d is pointed at an empty
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
# $4 dots mode: ok | fail | absent. Prints the call log, one call per line.
run_case() {
    local home="$SB/$1" fake="$SB/$1/fakebin" log="$SB/$1/calls.log"
    mkdir -p "$fake" "$home/.local/bin" "$home/cache"
    : >"$log"
    local s
    for s in xrdb dwm; do
        printf '#!/bin/sh\necho "%s $*" >>"%s"\n' "$s" "$log" >"$fake/$s"
    done
    # The $1/$@ belong to the fake script being written, not to this one.
    # shellcheck disable=SC2016
    printf '#!/bin/sh\necho "timeout $1" >>"%s"\nshift\nexec "$@"\n' "$log" >"$fake/timeout"
    [[ "$2" == cache ]] && { mkdir -p "$home/cache/dots/theme" && : >"$home/cache/dots/theme/xresources"; }
    [[ "$3" == fehbg ]] && printf '#!/bin/sh\necho fehbg >>"%s"\n' "$log" >"$home/.fehbg"
    case "$4" in
        ok) printf '#!/bin/sh\necho "dots $*" >>"%s"\n' "$log" >"$home/.local/bin/dots" ;;
        fail) printf '#!/bin/sh\necho "dots $*" >>"%s"\nexit 1\n' "$log" >"$home/.local/bin/dots" ;;
        absent) ;;
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

blue "==> theme step in the generated ~/.xinitrc"
expect "cache + wallpaper: merge, re-apply, then dwm" \
    "$(printf '%s\n' 'xrdb -merge HOME/cache/dots/theme/xresources' fehbg 'dwm ')" \
    "$(run_case cached cache fehbg ok)"
expect "cache, no wallpaper: merge only, then dwm" \
    "$(printf '%s\n' 'xrdb -merge HOME/cache/dots/theme/xresources' 'dwm ')" \
    "$(run_case cached-nowall cache '' ok)"
expect "first login: dots theme dark, bounded, then dwm" \
    "$(printf '%s\n' 'timeout 120' 'dots theme dark' 'dwm ')" \
    "$(run_case first-login '' '' ok)"
expect "first login, theme apply fails: dwm still starts" \
    "$(printf '%s\n' 'timeout 120' 'dots theme dark' 'dwm ')" \
    "$(run_case apply-fails '' '' fail)"
expect "no dots command at all: dwm still starts" \
    "dwm " \
    "$(run_case no-dots '' '' absent)"

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
if grep -q -- 'never restores the dots theme' <<<"$(report "$SB/old-xinitrc")"; then
    green "  ok: a pre-2026-10-05 ~/.xinitrc is reported"
else
    red "  an ~/.xinitrc with no theme step was NOT reported"
    rc=1
fi

if ((rc != 0)); then
    red "✗ xinitrc theme restore"
    exit 1
fi
green "✓ xinitrc theme restore"
