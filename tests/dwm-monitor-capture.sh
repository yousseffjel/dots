#!/usr/bin/env bash
# "This monitor" capture: config/dwm/bin/dwm-lib-monitor.sh's
# monitor_geometry, and dwm-screenshot's --monitor mode built on it
# (dwm-record's is in tests/dwm-record.sh, beside its fake ffmpeg).
#
# WHY. On two screens "full" captures the whole X screen — both monitors,
# 3840x1080 on the user's desk — and region needs a drag that has to land
# on the exact edges. The monitor under the pointer is what you mean nine
# times out of ten, and dwm focuses by pointer here anyway.
#
# What is asserted:
#   * the pointer picks the monitor whose rectangle holds it, edges included
#     (x = 1919 is the left one, x = 1920 the right one), for side-by-side,
#     stacked and mixed-size layouts, and once for mirrored screens;
#   * a pointer in no monitor (the dead corner of a mixed-size layout), a
#     missing xdotool, or unreadable output from either tool fails — never
#     a guess, which would silently capture the wrong screen;
#   * dwm-screenshot --monitor hands that rectangle to maim --geometry; on
#     failure it captures nothing and says so in a notification, since the
#     key's stderr goes nowhere;
#   * without dwm-lib-monitor.sh beside it, dwm-screenshot still takes full
#     shots; only --monitor fails.
#
# The formats are the real tools' (Void VM, 2026-10-21): xrandr
# --listactivemonitors prints " 0: +*Virtual-1 1920/508x1080/286+0+0  Virtual-1",
# xdotool getmouselocation --shell prints X=, Y=, SCREEN=, WINDOW= lines.
#
# SAFETY: every tool is a fake on a sealed PATH — a real maim would capture
# the tester's screen and a real xclip would replace their clipboard.
# shellcheck disable=SC2016 # fakes and bash -c bodies expand their own variables
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

BIN="$DOTS_DIR/config/dwm/bin"
LIB="$BIN/dwm-lib-monitor.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
LOG="$TMP/calls.log"
seal_path "$TMP/bin" bash awk mktemp rm mv mkdir date cat
{
    fake "$TMP/bin" xdotool 'printf "X=%s\nY=%s\nSCREEN=0\nWINDOW=590\n" "${FAKE_X:-}" "${FAKE_Y:-}"'
    fake "$TMP/bin" xrandr '[ "$1" = --listactivemonitors ] && cat "$MONITORS"; exit 0'
    fake "$TMP/bin" maim 'echo "maim ${*:1:$#-1}" >>"$LOG"; echo PNG >"${*: -1}"'
    fake "$TMP/bin" xclip 'echo "xclip $*" >>"$LOG"'
    fake "$TMP/bin" notify-send 'echo "notify-send $*" >>"$LOG"'
}
rc=0
check() {
    local name="$1"
    shift
    if "$@"; then green "  ok: $name"; else
        red "  FAIL: $name"
        rc=1
    fi
}

monitors() { printf 'Monitors: %s\n' "$#" >"$TMP/monitors" && printf '%s\n' "$@" >>"$TMP/monitors"; }
# geom <x> <y> — monitor_geometry's answer for a pointer at x,y ("" on failure).
geom() {
    env -i PATH="$TMP/bin" MONITORS="$TMP/monitors" FAKE_X="$1" FAKE_Y="$2" \
        bash -c 'red() { printf "%s\n" "$*" >&2; }; source "$1"; monitor_geometry' _ "$LIB" 2>"$TMP/err" || true
}

blue "==> two 1080p side by side (the user's desk)"
monitors ' 0: +*HDMI-1 1920/530x1080/300+0+0  HDMI-1' ' 1: +HDMI-2 1920/530x1080/300+1920+0  HDMI-2'
check "pointer on the left one" test "$(geom 700 500)" == 1920x1080+0+0
check "x 1919 is still the left one" test "$(geom 1919 1079)" == 1920x1080+0+0
check "x 1920 is the right one" test "$(geom 1920 0)" == 1920x1080+1920+0

blue "==> stacked, and mixed sizes"
monitors ' 0: +*eDP-1 1920/344x1080/194+0+1440  eDP-1' ' 1: +DP-1 2560/600x1440/340+0+0  DP-1'
check "stacked: the lower one by y" test "$(geom 100 1500)" == 1920x1080+0+1440
check "stacked: the upper one" test "$(geom 2000 1439)" == 2560x1440+0+0
check "the dead corner beside the smaller one is no monitor" test -z "$(geom 2200 1500)"
check "...and says where the pointer was" grep -q '2200' "$TMP/err"

monitors ' 0: +*eDP-1 1920/344x1080/194+0+0  eDP-1' ' 1: +HDMI-1 1920/530x1080/300+0+0  HDMI-1'
check "mirrored screens: one rectangle, not two lines" test "$(geom 5 5)" == 1920x1080+0+0

blue "==> nothing to go on"
check "unreadable pointer position" test -z "$(geom '' '')"
check "...says so, not 'no monitor'" grep -q 'could not read the pointer position' "$TMP/err"
check "a non-numeric position too" test -z "$(geom 12a 5)"
: >"$TMP/monitors"
check "no monitors listed" test -z "$(geom 10 10)"
rm "$TMP/bin/xdotool"
monitors ' 0: +*HDMI-1 1920/530x1080/300+0+0  HDMI-1'
check "xdotool missing: fails" test -z "$(geom 10 10)"
check "...saying it is not installed" grep -q 'xdotool is not installed' "$TMP/err"
fake "$TMP/bin" xdotool 'printf "X=%s\nY=%s\nSCREEN=0\nWINDOW=590\n" "${FAKE_X:-}" "${FAKE_Y:-}"'

blue "==> dwm-screenshot --monitor"
shot() { # shot <script> <x> <y> <args...>
    local sut="$1" x="$2" y="$3"
    shift 3
    : >"$LOG"
    RC=0
    env -i PATH="$TMP/bin" HOME="$TMP/home" TMPDIR="$TMP" LOG="$LOG" MONITORS="$TMP/monitors" TMP_MENU="$TMP/menu" \
        FAKE_X="$x" FAKE_Y="$y" DOTS_SCREENSHOT_DIR="$TMP/shots" bash "$sut" "$@" >/dev/null 2>&1 || RC=$?
}
monitors ' 0: +*HDMI-1 1920/530x1080/300+0+0  HDMI-1' ' 1: +HDMI-2 1920/530x1080/300+1920+0  HDMI-2'
shot "$BIN/dwm-screenshot" 2500 300 --monitor --clipboard
check "the right monitor's rectangle reaches maim" grep -qxF 'maim --hidecursor --geometry 1920x1080+1920+0' "$LOG"
check "...and the clipboard" grep -q '^xclip ' "$LOG"
shot "$BIN/dwm-screenshot" 5000 300 --monitor --clipboard
check "pointer off every monitor: exit 1, nothing captured" \
    bash -c '[[ $1 -eq 1 ]] && ! grep -q "^maim" "$2"' _ "$RC" "$LOG"
check "...with a notification" grep -q 'critical Screenshot failed' "$LOG"
# A dmenu that records the menu it was shown, then presses Escape.
fake "$TMP/bin" dmenu 'cat >"$TMP_MENU"; exit 1'
shot "$BIN/dwm-screenshot" 10 10
check "the mode menu offers it" grep -qx monitor "$TMP/menu"

mkdir -p "$TMP/solo"
cp "$BIN/dwm-screenshot" "$BIN/dwm-lib-screenshot.sh" "$TMP/solo/"
shot "$TMP/solo/dwm-screenshot" 10 10 --full --clipboard
check "no dwm-lib-monitor.sh: --full still works" grep -q '^maim --hidecursor' "$LOG"
shot "$TMP/solo/dwm-screenshot" 10 10 --monitor --clipboard
check "...--monitor fails, capturing nothing" bash -c '[[ $1 -eq 1 ]] && ! grep -q "^maim" "$2"' _ "$RC" "$LOG"

if ((rc != 0)); then
    red "✗ monitor capture"
    exit 1
fi
green "✓ monitor capture: the monitor under the pointer, edges, gaps, and dwm-screenshot --monitor"
