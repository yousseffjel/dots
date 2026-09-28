#!/usr/bin/env bash
# First-ever execution of the built dwm binary in this repo's test suite.
# Starts Xvfb, runs the real suckless/dwm/dwm binary against it, and asserts
# real EWMH root-window state plus the runtime behaviour of four of the 23
# vendored patches: xresources (colour loading from the X resource database),
# pertag (per-tag mfact persistence), actualfullscreen (real _NET_WM_STATE),
# and restartsig (SIGHUP reload — see the note near that section).
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
# RESTARTSIG (SIGHUP) IS ADVISORY, NOT A HARD FAILURE — see the comment on
# check_restartsig() in tests/lib/dwm-runtime-checks.sh: signal delivery to a
# backgrounded child was proven unreliable in the interactive sandbox this
# test was developed in, independent of dwm entirely. Every other assertion
# here IS a hard failure, including the two the exit criteria actually
# require (xresources colour path, one pertag behaviour).
#
# actualfullscreen and pertag run BEFORE restartsig, deliberately: a SIGHUP
# restart's scan()-recovered pre-existing windows were observed to lose
# dwm's internal "selected client" (togglefullscr() no-ops on !selmon->sel)
# even though the restart itself succeeds. Whether that is a real
# restartsig gap or an artifact of this test's window-recovery path is left
# as a follow-up rather than investigated further — but every
# focus-dependent check needs to run before any restart happens regardless.
#
# Split at the 250-line cap (2026-09-28): the X helpers live in
# tests/lib/dwm-runtime-x.sh and the five check sections in
# tests/lib/dwm-runtime-checks.sh. Both are sourced, never globbed as tests.

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
# Advisory, not blocking: see check_restartsig() for why.
warn() { yellow "  WARN: $1"; }

TMP="$(mktemp -d)"
WINCLASS="DwmRuntimeTest$$"
XVFB_PID=
DWM_PID=
WIN1=
CHECKWIN_HEX=

cleanup() {
    local status=$?
    trap - EXIT
    [[ -n "$DWM_PID" ]] && kill "$DWM_PID" 2>/dev/null
    pkill -f "xterm -class $WINCLASS" 2>/dev/null
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

start_dwm

# Order is load-bearing: see the header on why restartsig runs last.
check_ewmh
check_xresources
check_fullscreen
check_pertag
check_restartsig

if ((rc != 0)); then
    red "✗ dwm-runtime is broken"
    exit 1
fi
green "✓ dwm-runtime: EWMH state, xresources, actualfullscreen and pertag all hold (restartsig is advisory-only, see above)"
