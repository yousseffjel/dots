#!/usr/bin/env bash
# Exercises config/dwm/bin/dwm-idle-dim, xss-lock's notifier, against fake
# xrandr, gammastep and pgrep on a sealed PATH. The real dwm-nightlight runs
# its own apply, through the fake gammastep.
#
# What is asserted:
#   * xrandr path: every step sets the gamma it read (inverted back, because
#     xrandr prints 1/gamma and --brightness alone resets it) and the
#     brightness times the factor; it fades to DIM_LEVEL, touches only
#     outputs that are on, and on SIGTERM (xss-lock, at input or at the lock)
#     puts both back promptly;
#   * a brightness xrandr cannot report (0.0) is restored as 1, not as black;
#   * nightlight path: while its daemon runs the dimmer writes no gamma itself.
#     It hands dwm-nightlight a factor ("<f> <pid>") and asks it to apply,
#     so a daemon tick keeps the screen dim. On SIGTERM the file goes and
#     the stored brightness comes back. A factor whose pid is dead is ignored,
#     so a dimmer killed with -9 never leaves the screen dark;
#   * nothing to dim: it waits, and exits 0 on SIGTERM.
#
# SAFETY: xrandr and gammastep are fakes, and pgrep never sees the tester's
# own night light daemon; the real ones would dim the tester's screen.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

BIN_DIR="$DOTS_DIR/config/dwm/bin"
SB="$(mktemp -d)"
DIMMER_PID=""
cleanup() {
    if [[ -n "$DIMMER_PID" ]]; then kill9 "$DIMMER_PID"; fi
    rm -rf "$SB"
}
trap cleanup EXIT
# kill9 <pid> — the dimmer AND its pending sleep (-9 skips the trap that
# kills it), so no orphan is left holding the caller's output.
kill9() {
    local kids
    kids="$(pgrep -P "$1" 2>/dev/null || true)"
    # shellcheck disable=SC2086 # one pid per word
    kill -9 "$1" $kids 2>/dev/null || true
}
LOG="$SB/calls.log"
export LOG SB

# The scripts are copied next to each other, as they are installed, so
# dwm-idle-dim finds dwm-nightlight beside it.
mkdir -p "$SB/dwm"
cp "$BIN_DIR/dwm-idle-dim" "$BIN_DIR/dwm-nightlight" "$SB/dwm/"
seal_path "$SB/bin" bash awk cat cut mkdir rm date sleep grep id
# shellcheck disable=SC2016
fake "$SB/bin" xrandr '[ "$1" = --verbose ] && { cat "$SB/verbose"; exit 0; }
echo "xrandr $*" >>"$LOG"'
# shellcheck disable=SC2016
fake "$SB/bin" gammastep 'echo "gammastep $*" >>"$LOG"'
# The night light daemon "runs" while $SB/nightlight-on exists.
# shellcheck disable=SC2016
fake "$SB/bin" pgrep '[ -e "$SB/nightlight-on" ]'

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}

STATE="$SB/state/dots/nightlight"
MARKER="$SB/run/dots/idle-dim.pid"
ENV=(env -i PATH="$SB/bin" LOG="$LOG" SB="$SB" HOME="$SB/home" XDG_STATE_HOME="$SB/state"
    XDG_RUNTIME_DIR="$SB/run" DWM_NIGHTLIGHT_NOW=23:00)

# start [wait] [step] — the dimmer in the background; waits (1.5 s by
# default) for its fade to finish.
start() {
    : >"$LOG"
    "${ENV[@]}" DWM_IDLE_DIM_STEP_SECS="${2:-0.1}" bash "$SB/dwm/dwm-idle-dim" >/dev/null 2>&1 &
    DIMMER_PID=$!
    sleep "${1:-1.5}"
}
# stop — SIGTERM, as xss-lock sends it; STOP_RC and STOP_MS. A dimmer that
# ignores it fails the run (rc 99) rather than hanging it.
stop() {
    local t0 i
    : >"$LOG"
    t0="$(date +%s%N)"
    kill "$DIMMER_PID"
    for ((i = 0; i < 30; i++)); do
        kill -0 "$DIMMER_PID" 2>/dev/null || break
        sleep 0.1
    done
    STOP_RC=0
    if kill -0 "$DIMMER_PID" 2>/dev/null; then
        kill9 "$DIMMER_PID"
        STOP_RC=99
    fi
    wait "$DIMMER_PID" 2>/dev/null || ((STOP_RC)) || STOP_RC=$?
    STOP_MS=$((($(date +%s%N) - t0) / 1000000))
    DIMMER_PID=""
}
last() { grep "^$1 " "$LOG" | tail -n1; }
# last_out <output> — the last xrandr write to that output.
last_out() { grep "^xrandr --output $1 " "$LOG" | tail -n1; }
absent() { ! grep -qE "$1" "$LOG"; }

blue "==> xrandr path (no night light daemon)"
cat >"$SB/verbose" <<'EOF'
HDMI-1 connected primary 1920x1080+0+0 (0x46) normal (normal left inverted right x axis y axis) 527mm x 296mm
	Gamma:      1.0:1.3:1.7
	Brightness: 0.90
DP-2 connected (normal left inverted right x axis y axis)
	Gamma:      1.0:1.0:1.0
	Brightness: 1.00
DP-3 disconnected (normal left inverted right x axis y axis)
HDMI-2 connected 1280x1024+1920+0 (0x50) normal (normal left inverted right x axis y axis) 0mm x 0mm
	Gamma:      1.0:1.0:1.0
	Brightness: 0.50
EOF
start
check "it fades in steps" test "$(grep -c '^xrandr --output HDMI-1 ' "$LOG")" -ge 4
check "...to 0.4 of the brightness, the gamma inverted back" \
    test "$(last_out HDMI-1)" == "xrandr --output HDMI-1 --gamma 1.000:0.769:0.588 --brightness 0.360"
check "...and every other output that is on, with its own values" \
    test "$(last_out HDMI-2)" == "xrandr --output HDMI-2 --gamma 1.000:1.000:1.000 --brightness 0.200"
check "...never touching an output that is off or disconnected" \
    absent 'DP-2|DP-3'
check "the marker names it while it runs" test "$(cat "$MARKER" 2>/dev/null)" == "$DIMMER_PID"
stop
check "SIGTERM puts gamma and brightness back, on each output" \
    test "$(last_out HDMI-1) / $(last_out HDMI-2)" == \
    "xrandr --output HDMI-1 --gamma 1.000:0.769:0.588 --brightness 0.900 / xrandr --output HDMI-2 --gamma 1.000:1.000:1.000 --brightness 0.500"
check "...exit 0" test "$STOP_RC" -eq 0
check "...promptly ($STOP_MS ms)" test "$STOP_MS" -lt 1000
check "...and the marker goes" test ! -e "$MARKER"

start 0.7 0.5
check "SIGTERM mid-fade: still fading" test "$(grep -c '^xrandr --output HDMI-1 ' "$LOG")" -lt 8
stop
check "...restores the same" \
    test "$(last_out HDMI-1)" == "xrandr --output HDMI-1 --gamma 1.000:0.769:0.588 --brightness 0.900"
check "...promptly ($STOP_MS ms)" test "$STOP_MS" -lt 1000

sed -i 's/Brightness: 0.90/Brightness: 0.0/' "$SB/verbose"
start
stop
check "a brightness xrandr cannot report comes back as 1, not black" \
    test "$(last_out HDMI-1)" == "xrandr --output HDMI-1 --gamma 1.000:0.769:0.588 --brightness 1.000"

blue "==> nightlight path (its daemon owns the gamma)"
touch "$SB/nightlight-on"
mkdir -p "$STATE"
echo 80 >"$STATE/brightness"
start
check "no xrandr write of its own" absent '^xrandr '
check "the factor and its pid in the dim file" test "$(cat "$STATE/dim" 2>/dev/null)" == "0.400 $DIMMER_PID"
check "dwm-nightlight applied 80% x 0.4" test "$(last gammastep)" == "gammastep -m randr -P -O 4000 -b 0.32:0.32"
: >"$LOG"
"${ENV[@]}" bash "$SB/dwm/dwm-nightlight" apply
check "a daemon tick while it runs stays dim" test "$(last gammastep)" == "gammastep -m randr -P -O 4000 -b 0.32:0.32"
stop
check "SIGTERM removes the dim file" test ! -e "$STATE/dim"
check "...and applies the stored 80% again" test "$(last gammastep)" == "gammastep -m randr -P -O 4000 -b 0.80:0.80"

start
kill9 "$DIMMER_PID"
wait "$DIMMER_PID" 2>/dev/null || true
DIMMER_PID=""
: >"$LOG"
"${ENV[@]}" bash "$SB/dwm/dwm-nightlight" apply
check "killed with -9: the next tick ignores its dim file" \
    test "$(last gammastep)" == "gammastep -m randr -P -O 4000 -b 0.80:0.80"
check "...and removes it, before its pid can be reused" test ! -e "$STATE/dim"
rm -f "$SB/nightlight-on" "$STATE/dim"

blue "==> xss-lock gone"
cat >"$SB/verbose" <<'EOF2'
HDMI-1 connected 1920x1080+0+0 (0x46) normal
	Gamma:      1.0:1.0:1.0
	Brightness: 1.00
EOF2
: >"$LOG"
# A parent shell standing in for xss-lock; it exits after 1 s.
# shellcheck disable=SC2016 # $1 is the inner shell's argument
"${ENV[@]}" bash -c 'bash "$1" >/dev/null 2>&1 & sleep 1' _ "$SB/dwm/dwm-idle-dim" &
parent=$!
wait "$parent"
for _ in $(seq 40); do
    [[ "$(last xrandr)" == *"--brightness 1.000" ]] && break
    sleep 0.1
done
check "its parent died: it restores and exits within a few seconds" \
    test "$(last xrandr)" == "xrandr --output HDMI-1 --gamma 1.000:1.000:1.000 --brightness 1.000"

blue "==> a brightness key waits for the restore"
# The key is the input that ends the dim: dwm-brightness must not read the
# dimmed level. The marker names a live pid for 0.6 s, then it is gone.
cp "$BIN_DIR/dwm-brightness" "$SB/dwm/"
mkdir -p "${MARKER%/*}"
sleep 0.6 &
echo $! >"$MARKER"
t0="$(date +%s%N)"
"${ENV[@]}" bash "$SB/dwm/dwm-brightness" set 50 >/dev/null 2>&1 || true
ms=$((($(date +%s%N) - t0) / 1000000))
check "a live dimmer: it waits ($ms ms)" test "$ms" -ge 400
echo 999999 >"$MARKER"
t0="$(date +%s%N)"
"${ENV[@]}" bash "$SB/dwm/dwm-brightness" set 50 >/dev/null 2>&1 || true
ms=$((($(date +%s%N) - t0) / 1000000))
check "a stale marker: no wait ($ms ms)" test "$ms" -lt 300
rm -f "$MARKER"

blue "==> nothing to dim"
: >"$SB/verbose"
start
stop
check "no screen that is on: no writes, exit 0 on SIGTERM" \
    test "$STOP_RC" -eq 0 -a ! -s "$LOG"

check "--help answers usage" bash -c '"$@" | grep -q "^usage: dwm-idle-dim"' _ "${ENV[@]}" bash "$SB/dwm/dwm-idle-dim" --help

if ((FAILS)); then
    red "✗ dwm-idle-dim: $FAILS failed"
    exit 1
fi
green "✓ dwm-idle-dim: fade, restore, and the hand-off to night light all hold"
