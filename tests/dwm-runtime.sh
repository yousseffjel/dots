#!/usr/bin/env bash
# First-ever execution of the built dwm binary in this repo's test suite.
# Starts Xvfb, runs the real suckless/dwm/dwm binary against it, and asserts
# real EWMH root-window state plus the runtime behaviour of the vendored
# patches: xresources (colour loading from the X resource database), pertag
# (per-tag mfact persistence), actualfullscreen (real _NET_WM_STATE),
# restartsig (SIGHUP reload — see the note near that section), dropterm and
# dynamicscratchpads (Super+grave; stash and Super+minus), preserveonrestart
# (a restart keeps tags, view, stash, floating and focus), preservepertag
# (and each tag's layout, mfact, nmaster, bar, and Mod+Tab's history) and
# wakeonsignal (SIGHUP/SIGTERM act with no X event). It also opens a window
# of every floating class in config.def.h's rules[] and checks it floats.
# No patch count: the last one written here went stale twice.
#
# Wired into `build-suckless` (CI) rather than a new job, per scope-d locked
# decision 3 (.claude/tasks/scope-d-verification-harvest.md): that job
# already builds dwm in a Fedora container on both matrix legs and is where
# tests/build.sh already runs.
#
# SKIPS LOUDLY (yellow, exit 0) when a prerequisite tool or the built dwm
# binary is missing, rather than failing — this is real integration against
# real binaries; faking any of Xvfb/xdotool/ImageMagick/xterm would mean
# testing a fixture generator instead of dwm itself (same reasoning as
# tests/dwm-colorpicker.sh's ImageMagick handling).
#
# -noreset on the Xvfb invocation is load-bearing — see start_xvfb() in
# tests/lib/dwm-runtime-x.sh for why.
#
# Every assertion is a hard failure, restartsig (SIGHUP reload) included.
# restartsig was advisory until 2026-10-06 because it never passed — blamed
# on signal delivery in the sandbox, but really because dwm then acted on
# SIGHUP only at its next X event and the test sent none. dwm itself was fixed
# on 2026-10-12 (wakeonsignal); the test now sends no event on purpose, and
# check_sigterm asserts it. See check_restartsig() in
# tests/lib/dwm-runtime-checks.sh. Promoted after 5/5 passes on fedora:latest,
# then 3/3 on each of fedora:latest and fedora:43 (CI's two images).
#
# The sections run BEFORE restartsig and preserveonrestart, which both
# restart dwm. This header used to say a restart's scan()-recovered windows
# "lose dwm's selected client" and left it as a follow-up. It was real, and
# it was the visible edge of a bigger bug: every restart — one per wallpaper
# change — reset every window's tags, floating state and stash, and the view.
# Fixed 2026-10-07 by the preserveonrestart diff; check_preserve proves it,
# and failed 7/7 before the fix.
#
# Split at the 250-line cap (2026-09-28, again 2026-10-07): the X helpers live
# in tests/lib/dwm-runtime-x.sh and the sections in tests/lib/dwm-runtime-
# {checks,floating,restart,pertag}.sh. All sourced, never globbed as tests.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DWM="$DOTS_DIR/suckless/dwm/dwm"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/dwm-runtime-x.sh
source "$SCRIPT_DIR/lib/dwm-runtime-x.sh"
# shellcheck source=lib/dwm-runtime-checks.sh
source "$SCRIPT_DIR/lib/dwm-runtime-checks.sh"
# shellcheck source=lib/dwm-runtime-restart.sh
source "$SCRIPT_DIR/lib/dwm-runtime-restart.sh"
# shellcheck source=lib/dwm-runtime-pertag.sh
source "$SCRIPT_DIR/lib/dwm-runtime-pertag.sh"
# shellcheck source=lib/dwm-runtime-floating.sh
source "$SCRIPT_DIR/lib/dwm-runtime-floating.sh"

skip() {
    yellow "SKIP: dwm-runtime.sh needs $1 and it is not available."
    yellow "      Real dwm/Xvfb integration cannot be faked without testing"
    yellow "      the fixture instead of the thing itself."
    exit 0
}

[[ -x "$DWM" ]] || skip "a built suckless/dwm/dwm binary (run tests/build.sh or scripts/install-suckless.sh first)"
command -v Xvfb >/dev/null 2>&1 || skip "Xvfb"
command -v xdotool >/dev/null 2>&1 || skip "xdotool"
command -v xrdb >/dev/null 2>&1 || skip "xrdb"
command -v xprop >/dev/null 2>&1 || skip "xprop"
command -v xwininfo >/dev/null 2>&1 || skip "xwininfo"
command -v xterm >/dev/null 2>&1 || skip "xterm"
# procps-ng: cleanup() kills the test xterms by class. CI's container lacked
# it, and the "command not found" in the EXIT trap became the exit status —
# build-suckless was red from 2026-09-08 to 2026-10-06 with every check passing.
command -v pkill >/dev/null 2>&1 || skip "pkill (procps-ng)"
if command -v magick >/dev/null 2>&1; then
    MAGICK="magick"
elif command -v convert >/dev/null 2>&1; then
    MAGICK="convert"
else
    skip "ImageMagick (magick or convert)"
fi

rc=0
pass() { green "  ok: $1"; }
fail() {
    red "  FAIL: $1"
    rc=1
}

TMP="$(mktemp -d)"
WINCLASS="DwmRuntimeTest$$"
XVFB_PID=
DWM_PID=
WIN1=
CHECKWIN_HEX=

# Teardown must never decide the exit status: set -e is live in an EXIT
# trap, so a failing kill/pkill here used to replace a passing run's 0.
cleanup() {
    local status=$?
    trap - EXIT
    set +e
    [[ -n "$DWM_PID" ]] && kill "$DWM_PID" 2>/dev/null
    pkill -f "xterm -class $WINCLASS" 2>/dev/null
    pkill -f "dwm-runtime-$$-" 2>/dev/null
    [[ -n "$XVFB_PID" ]] && kill "$XVFB_PID" 2>/dev/null
    wait 2>/dev/null
    rm -rf -- "$TMP"
    exit "$status"
}
trap cleanup EXIT

start_xvfb

# xresources: set colours BEFORE dwm starts, so xresupdate() (called at the
# top of main(), before setup()) loads them at startup.
COLOR_A="#123456"
printf 'dwm.selbordercolor: %s\n' "$COLOR_A" | xrdb -merge -

install_fake_alacritty
start_dwm

# Order is load-bearing: see the header on why restartsig runs last.
check_pertag_fresh_restart
check_ewmh
check_xresources
check_fullscreen
check_pertag
check_float_rules
check_dropterm
check_restartsig
check_preserve
check_pertag_restart
check_sigterm

if ((rc != 0)); then
    red "✗ dwm-runtime is broken"
    exit 1
fi
green "✓ dwm-runtime: EWMH state, xresources, actualfullscreen, pertag, float rules, dropterm, restartsig, preserveonrestart (incl. pertag) and wakeonsignal all hold"
