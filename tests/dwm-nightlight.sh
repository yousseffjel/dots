#!/usr/bin/env bash
# Exercises config/dwm/bin/dwm-nightlight and its hand-off with
# dwm-brightness, with fake gammastep, xrandr, pgrep and notify-send on a
# sealed PATH and the clock pinned by DWM_NIGHTLIGHT_NOW.
#
# What is asserted:
#   * the schedule: day, night, both ramps and their boundaries;
#   * every apply passes -P (without it each one-shot compounds on the last
#     ramp) and the stored brightness as -b B:B, clamped, 100% by default;
#   * toggle flips the filter and keeps the brightness;
#   * while the daemon runs, dwm-brightness reads and writes the stored
#     level and applies through dwm-nightlight, never xrandr; without it,
#     xrandr as before;
#   * the daemon exits at once when another is running (dwm re-runs
#     autostart.sh on every restart), and leaves promptly on SIGTERM.
#
# SAFETY: gammastep and xrandr are fakes — the real ones would recolour the
# tester's screen.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

NL="$DOTS_DIR/config/dwm/bin/dwm-nightlight"
BR="$DOTS_DIR/config/dwm/bin/dwm-brightness"
SB="$(mktemp -d)"
DAEMON=""
cleanup() {
    if [[ -n "$DAEMON" ]]; then kill "$DAEMON" 2>/dev/null || true; fi
    rm -rf "$SB"
}
trap cleanup EXIT
LOG="$SB/calls.log"
export LOG SB

seal_path "$SB/real" bash awk cat cut mkdir rm date sleep grep
mkdir -p "$SB/fake"
ln -s "$NL" "$SB/fake/dwm-nightlight"
# shellcheck disable=SC2016
fake "$SB/fake" gammastep 'echo "gammastep $*" >>"$LOG"'
# shellcheck disable=SC2016
fake "$SB/fake" xrandr 'echo "xrandr $*" >>"$LOG"
[ "$1" = --verbose ] && printf "%s\n" "HDMI-1 connected 1920x1080+0+0" "	Brightness: 0.80"
[ -z "$1" ] && echo "HDMI-1 connected 1920x1080+0+0"
exit 0'
# $NL_OTHER is the pid the fake reports for a running daemon; empty = none.
# With NL_SELF set it also reports what the real `pgrep -f` would: the
# daemon itself and the $( ) subshell it was run from ($PPID, whose parent
# is the daemon) — both carry the daemon's command line.
# shellcheck disable=SC2016
fake "$SB/fake" pgrep 'if [ -n "$NL_SELF" ]; then echo "$PPID"; cut -d" " -f4 "/proc/$PPID/stat"; fi
[ -n "$NL_OTHER" ] || { [ -n "$NL_SELF" ]; exit; }
echo "$NL_OTHER"'
fake "$SB/fake" notify-send ':'
# A sleep that leaves its pid behind, so the test can prove the daemon kills
# its pending sleep on SIGTERM rather than orphaning it for a minute.
# shellcheck disable=SC2016
fake "$SB/fake" sleep 'echo $$ >"$SB/sleeper.pid"; exec "$SB/real/sleep" "$@"'

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}

# run <script> <args...> — NOW and NL_OTHER from the caller; stdout in $OUT.
run() {
    local script="$1"
    shift
    : >"$LOG"
    RC=0
    OUT="$(env -i HOME="$SB" XDG_STATE_HOME="$SB/state" LOG="$LOG" \
        NL_OTHER="${NL_OTHER:-}" DWM_NIGHTLIGHT_NOW="${NOW:-12:00}" \
        PATH="$SB/fake:$SB/real" "$(type -P bash)" "$script" "$@" 2>/dev/null)" || RC=$?
}
logged() { grep -qE -- "$1" "$LOG"; }
unlogged() { ! grep -qE -- "$1" "$LOG"; }
temp_at() {
    NOW="$1" run "$NL" apply
    logged "-O $2 "
}
STATE="$SB/state/dots/nightlight"

blue "schedule"
check "midday: 6500" temp_at 12:00 6500
check "late night: 4000" temp_at 23:00 4000
check "small hours: 4000" temp_at 03:00 4000
check "dusk midpoint: 5250" temp_at 19:30 5250
check "dawn midpoint: 5250" temp_at 06:30 5250
check "dusk starts at day temperature" temp_at 19:00 6500
check "dawn ends at day temperature" temp_at 07:00 6500
check "dusk ends at night temperature" temp_at 20:00 4000

blue "every apply"
run "$NL" apply
check "-P resets the ramps first" logged '^gammastep .*-P '
check "randr method" logged '^gammastep -m randr '
check "no stored brightness: 1.00" logged '-b 1.00:1.00$'
mkdir -p "$STATE"
echo 70 >"$STATE/brightness"
run "$NL" apply
check "stored 70%: 0.70" logged '-b 0.70:0.70$'
echo 5 >"$STATE/brightness"
run "$NL" apply
check "below the floor: clamped to 0.10" logged '-b 0.10:0.10$'
echo junk >"$STATE/brightness"
run "$NL" apply
check "garbage: 1.00" logged '-b 1.00:1.00$'

blue "toggle"
echo 70 >"$STATE/brightness"
NOW=23:00 run "$NL" toggle
check "off: day temperature at night" logged '-O 6500 '
check "off: brightness kept" logged '-b 0.70:0.70$'
NOW=23:00 run "$NL" status
check "status says off" test "$OUT" = off
NOW=23:00 run "$NL" toggle
check "on again: night temperature" logged '-O 4000 '
NOW=23:00 run "$NL" status
check "status says on 4000K" test "$OUT" = "on 4000K"

blue "dwm-brightness while the daemon runs"
echo 70 >"$STATE/brightness"
NL_OTHER=4242 run "$BR" get
check "get reads the stored level" test "$OUT" = 70
check "get never asks xrandr" unlogged '^xrandr'
NL_OTHER=4242 run "$BR" down
check "down prints the new level" test "$OUT" = 60
check "down stores it" test "$(cat "$STATE/brightness")" = 60
check "down applies through the night light" logged '-b 0.60:0.60$'
check "down never touches xrandr" unlogged '^xrandr'
NL_OTHER=4242 run "$BR" set 3
check "set clamps before storing" test "$(cat "$STATE/brightness")" = 10

blue "dwm-brightness without the daemon"
run "$BR" down
check "xrandr as before" logged '^xrandr --output HDMI-1 --brightness 0.70'
check "no gammastep" unlogged '^gammastep'

blue "daemon"
# Under timeout: without the guard the daemon would loop here forever. The
# "other daemon" must be a live process — the guard rightly skips a pid that
# has already gone — so a real sleep stands in for it.
: >"$LOG"
RC=0
sleep 30 &
OTHER=$!
timeout 5 env -i HOME="$SB" XDG_STATE_HOME="$SB/state" LOG="$LOG" NL_OTHER="$OTHER" \
    PATH="$SB/fake:$SB/real" "$(type -P bash)" "$NL" daemon >/dev/null 2>&1 || RC=$?
kill "$OTHER" 2>/dev/null || true
check "another daemon running: exits at once (not 124, the timeout)" test "$RC" -eq 0
check "another daemon running: no apply" unlogged '^gammastep'
: >"$LOG"
env -i HOME="$SB" SB="$SB" XDG_STATE_HOME="$SB/state" LOG="$LOG" NL_OTHER="" NL_SELF=1 \
    PATH="$SB/fake:$SB/real" "$(type -P bash)" "$NL" daemon &
DAEMON=$!
sleep 0.5
check "applies at start (does not mistake itself for another daemon)" logged '^gammastep '
kill -TERM "$DAEMON"
gone=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
    if ! kill -0 "$DAEMON" 2>/dev/null; then
        gone=1
        break
    fi
    sleep 0.1
done
check "leaves within a second of SIGTERM" test "$gone" -eq 1
sleeper="$(cat "$SB/sleeper.pid" 2>/dev/null || true)"
check "its pending sleep was started" test -n "$sleeper"
dead() { ! kill -0 "$1" 2>/dev/null; }
check "and does not outlive it" dead "${sleeper:-0}"
DAEMON=""

if [[ $FAILS -gt 0 ]]; then
    red "$FAILS check(s) failed"
    exit 1
fi
green "✓ dwm-nightlight"
