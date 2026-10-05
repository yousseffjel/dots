#!/usr/bin/env bash
# Exercises config/dwm/bin/dwm-record's start/stop toggle with a fake ffmpeg,
# xrandr, slop, dmenu and notify-send on a sealed PATH.
#
# The fake ffmpeg is Python, not bash, and that is load-bearing. A command a
# non-interactive bash script starts with `&` inherits SIGINT as IGNORED, and
# bash cannot trap a signal that was ignored on entry, so a bash fake would
# never see the stop signal. Real ffmpeg installs its own SIGINT handler
# unconditionally (fftools term_init), and so can Python. Like ffmpeg it
# writes its output file and exits on SIGINT or SIGTERM, and it logs which.
#
# What is asserted:
#   * full screen: x11grab on $DISPLAY at the screen size rounded to even,
#     VP9 into the recordings dir, pid + output kept in $XDG_RUNTIME_DIR;
#   * the second press sends SIGINT (ffmpeg's clean stop), the file exists,
#     the state is cleared and the process is gone;
#   * region: slop's geometry, rounded to even, as -video_size and +x,y;
#   * Escape at dmenu or in slop starts nothing;
#   * a stale pid naming some other process is never signalled;
#   * an ffmpeg that dies at once is reported (exit 1) and leaves no state;
#   * no DISPLAY is exit 1.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

PY="$(type -P python3 || true)"
if [[ -z "$PY" ]]; then
    red "python3 not found — this test's fake ffmpeg needs it (see the header)"
    exit 1
fi

SUT="$DOTS_DIR/config/dwm/bin/dwm-record"
SB="$(mktemp -d)"
STRAY=""
# set -e applies inside an EXIT trap too: a pkill that finds nothing (the
# normal case) returns 1, which would abort the cleanup before the rm and
# turn a green run into exit 1. Every step is therefore made unfailing.
cleanup() {
    if [[ -n "$STRAY" ]]; then kill "$STRAY" 2>/dev/null || true; fi
    pkill -f "$SB/fake/ffmpeg" 2>/dev/null || true
    rm -rf "$SB"
}
trap cleanup EXIT
LOG="$SB/calls.log"
export LOG SB

seal_path "$SB/real" cat mkdir date rm sleep awk tr
mkdir -p "$SB/fake" "$SB/run" "$SB/videos"
cat >"$SB/fake/ffmpeg" <<EOF
#!$PY
import os, signal, sys, time
log = os.environ["LOG"]
with open(log, "a") as f:
    f.write("ffmpeg " + " ".join(sys.argv[1:]) + "\n")
if os.environ.get("FFMPEG_DIES"):
    sys.exit(1)
out = sys.argv[-1]
def done(sig, _frame):
    with open(log, "a") as f:
        f.write("signal %d\n" % sig)
    with open(out, "w") as f:
        f.write("video")
    sys.exit(0)
signal.signal(signal.SIGINT, done)
signal.signal(signal.SIGTERM, done)
while True:
    time.sleep(0.05)
EOF
chmod 755 "$SB/fake/ffmpeg"
fake "$SB/fake" xrandr 'echo "Screen 0: minimum 8 x 8, current 1921 x 1081, maximum 32767 x 32767"'
# shellcheck disable=SC2016
fake "$SB/fake" slop 'cat "$SB/slop" 2>/dev/null'
# shellcheck disable=SC2016
fake "$SB/fake" dmenu 'cat >/dev/null; [ -n "$PICK" ] || exit 1; echo "$PICK"'
# shellcheck disable=SC2016
fake "$SB/fake" notify-send 'echo "notify $*" >>"$LOG"'

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}

# rec [args] — PICK, DISPLAY and FFMPEG_DIES come from the caller's env.
rec() {
    RC=0
    env -i HOME="$SB" LOG="$LOG" SB="$SB" PICK="${PICK:-}" DISPLAY="${DISP-:9}" \
        FFMPEG_DIES="${FFMPEG_DIES:-}" XDG_RUNTIME_DIR="$SB/run" \
        DOTS_RECORD_DIR="$SB/videos" PATH="$SB/fake:$SB/real" \
        "$(type -P bash)" "$SUT" "$@" >/dev/null 2>&1 || RC=$?
}
logged() { grep -qE -- "$1" "$LOG"; }
state_clear() { [[ ! -e "$SB/run/dwm-record/pid" && ! -e "$SB/run/dwm-record/out" ]]; }
ffmpeg_gone() { ! pgrep -f "$SB/fake/ffmpeg" >/dev/null; }
none_started() { ! grep -q "^ffmpeg" "$LOG"; }

blue "start, full screen"
: >"$LOG"
PICK=full rec
check "exit 0" test "$RC" -eq 0
check "x11grab on the display at an even screen size" logged '-f x11grab .*-video_size 1920x1080 -i :9 '
check "VP9 into the recordings dir" logged "libvpx-vp9 .*$SB/videos/dots-recording-.*\.webm$"
check "pid kept" test -s "$SB/run/dwm-record/pid"
check "says it is recording" logged '^notify .*Recording Super\+r stops it'

blue "stop"
: >"$LOG"
rec
check "exit 0" test "$RC" -eq 0
check "ffmpeg got SIGINT, the clean stop" logged '^signal 2$'
check "no new recording started" none_started
check "file written" test -s "$(ls "$SB"/videos/*.webm)"
check "says where it went" logged "^notify .*Recording saved $SB/videos/"
check "state cleared" state_clear
check "process gone" ffmpeg_gone

blue "region"
rm -f "$SB"/videos/*
: >"$LOG"
echo "301 201 10 20" >"$SB/slop"
rec --region
check "slop geometry, rounded to even" logged '-video_size 300x200 -i :9\+10,20 '
rec
check "stopped" ffmpeg_gone

blue "cancels"
: >"$LOG"
: >"$SB/slop"
rec --region
check "Escape in slop: exit 0" test "$RC" -eq 0
check "Escape in slop: nothing started" none_started
PICK="" rec
check "Escape at dmenu: nothing started" none_started

blue "stale pid"
sleep 30 &
STRAY=$!
mkdir -p "$SB/run/dwm-record"
echo "$STRAY" >"$SB/run/dwm-record/pid"
PICK=full rec
check "a non-ffmpeg pid is not signalled" kill -0 "$STRAY"
check "a new recording starts instead" logged '^ffmpeg '
rec

blue "failures"
: >"$LOG"
FFMPEG_DIES=1 PICK=full rec
check "ffmpeg dying at once: exit 1" test "$RC" -eq 1
check "reported" logged '^notify .*Recording failed'
check "no state left" state_clear
DISP="" PICK=full rec
check "no DISPLAY: exit 1" test "$RC" -eq 1

if [[ $FAILS -gt 0 ]]; then
    red "$FAILS check(s) failed"
    exit 1
fi
green "✓ dwm-record"
