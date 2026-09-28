#!/usr/bin/env bash
# Exercises config/dwm/bin/dwm-brightness against a faked xrandr.
#
# The highest-value untested dwm-* script (queued 2026-08-12): it PARSES
# `xrandr --verbose` and does arithmetic on the result, so its failures are
# silent wrong numbers rather than crashes. What is asserted:
#   * `get` reads the first CONNECTED output — a disconnected output listed
#     first, carrying its own Brightness: line, must not win (the trap the
#     script's header describes);
#   * up/down step by 10 from that reading and clamp to 10..100 — never 0,
#     which would black the screen out;
#   * every connected output is written, no disconnected one ever is;
#   * a failed READ writes nothing at all (the old inline form clamped the
#     display to 10% when only the read had failed);
#   * `set` validates its argument and clamps too.
#
# SAFETY: xrandr is a fake on a sealed PATH. A real call would change the
# tester's actual screens — the dev host sat at 0.45 while this was written.
# The fake's --verbose output copies the real shape: unindented output header
# lines, then a TAB-indented `Brightness: 0.45` (checked against a live
# `xrandr --verbose` on 2026-09-28).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SUT="$DOTS_DIR/config/dwm/bin/dwm-brightness"
[[ -f "$SUT" ]] || {
    red "missing: $SUT"
    exit 1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"
seal_path "$BIN" bash awk cat
LOG="$TMP/xrandr.log"

rc=0
pass() { green "  ok: $1"; }
fail() {
    red "  FAIL: $1"
    rc=1
}

# The fake answers `xrandr` and `xrandr --verbose` from $SCREENS (a file) and
# logs every --output call. An empty $SCREENS file models a dead X server.
fake "$BIN" xrandr "
if [[ \"\${1:-}\" == --output ]]; then echo \"\$*\" >>'$LOG'; exit \"\${FAKE_SET_RC-0}\"; fi
if [[ \"\${1:-}\" == --verbose ]]; then [[ -n \"\${FAKE_VERBOSE_FAIL:-}\" ]] && exit 1; cat \"\$SCREENS\"; exit 0; fi
awk '/^[^[:space:]]/' \"\$SCREENS\""

screens() { # <file> then lines on stdin
    cat >"$TMP/$1"
}
printf -v TAB '\t'
screens two <<EOF
Screen 0: minimum 16 x 16, current 3840 x 1080, maximum 32767 x 32767
DP-9 disconnected (normal left inverted right x axis y axis)
${TAB}Identifier: 0x60
${TAB}Brightness: 0.0
HDMI-A-1 connected 1920x1080+0+0 (0x25) normal (normal left inverted right x axis y axis) 600mm x 330mm
${TAB}Gamma:      1.0:1.0:1.0
${TAB}Brightness: 0.45
  1920x1080 (0x25) 148.500MHz +HSync +VSync *current +preferred
HDMI-A-2 connected 1920x1080+1920+0 (0x41) normal (normal left inverted right x axis y axis) 600mm x 330mm
${TAB}Brightness: 0.44
EOF
screens high <<EOF
HDMI-A-1 connected 1920x1080+0+0 (0x25) normal
${TAB}Brightness: 0.95
EOF
screens low <<EOF
HDMI-A-1 connected 1920x1080+0+0 (0x25) normal
${TAB}Brightness: 0.15
EOF
screens none <<EOF
DP-9 disconnected (normal left inverted right x axis y axis)
${TAB}Brightness: 1.0
EOF
: >"$TMP/dead"

# run <screens> <args...> — sets OUT, ERR, RC; the call log starts empty.
run() {
    local s="$1"
    shift
    : >"$LOG"
    RC=0
    env -i PATH="$BIN" SCREENS="$TMP/$s" ${FAKE_SET_RC+FAKE_SET_RC="$FAKE_SET_RC"} \
        ${FAKE_VERBOSE_FAIL+FAKE_VERBOSE_FAIL=1} \
        bash "$SUT" "$@" >"$TMP/out" 2>"$TMP/err" || RC=$?
    OUT="$(cat "$TMP/out")"
    ERR="$(cat "$TMP/err")"
}
calls() { cat "$LOG"; }

blue "==> get"
run two get
if [[ $RC -eq 0 && "$OUT" == 45 ]]; then
    pass "reads the first CONNECTED output (45), not the disconnected one listed before it"
else
    fail "get: rc=$RC out='$OUT' (expected 45)"
fi
if [[ ! -s "$LOG" ]]; then
    pass "get writes nothing"
else
    fail "get called: $(calls)"
fi
run dead get
if [[ $RC -ne 0 && "$ERR" == *"xrandr returned nothing"* ]]; then
    pass "a dead X server is reported, not read as a value"
else
    fail "dead X: rc=$RC err='$ERR'"
fi

blue "==> up / down"
run two up
if [[ $RC -eq 0 && "$OUT" == 55 ]]; then pass "up: 45 -> 55"; else fail "up: rc=$RC out='$OUT'"; fi
expected="--output HDMI-A-1 --brightness 0.55
--output HDMI-A-2 --brightness 0.55"
if [[ "$(calls)" == "$expected" ]]; then
    pass "every connected output set to 0.55; DP-9 (disconnected) untouched"
else
    fail "up wrote: $(calls | tr '\n' ';')"
fi
run two down
if [[ "$OUT" == 35 ]]; then
    pass "down: 45 -> 35"
else
    fail "down: out='$OUT'"
fi
run high up
if [[ "$OUT" == 100 && "$(calls)" == *"--brightness 1.00"* ]]; then
    pass "clamps at 100 (95 + 10)"
else
    fail "high up: out='$OUT' calls=$(calls)"
fi
run low down
if [[ "$OUT" == 10 && "$(calls)" == *"--brightness 0.10"* ]]; then
    pass "clamps at 10, never 0 (15 - 10)"
else
    fail "low down: out='$OUT' calls=$(calls)"
fi
run dead up
if [[ $RC -ne 0 && ! -s "$LOG" ]]; then
    pass "a failed read writes NOTHING (does not clamp the screen to 10%)"
else
    fail "dead up: rc=$RC calls=$(calls)"
fi
# The realistic half-failure: the outputs still list, only the --verbose read
# fails. The script's own comment names this — an unguarded read would carry
# on with an empty value and clamp every screen to 10%.
FAKE_VERBOSE_FAIL=1 run two up
if [[ $RC -ne 0 && ! -s "$LOG" ]]; then
    pass "--verbose fails but outputs list: still writes nothing"
else
    fail "verbose-only failure wrote: $(calls) (rc=$RC)"
fi
run none up
if [[ $RC -ne 0 && "$ERR" == *"no connected outputs"* && ! -s "$LOG" ]]; then
    pass "no connected output: error, no write"
else
    fail "none up: rc=$RC err='$ERR' calls=$(calls)"
fi

blue "==> set"
run two set 70
if [[ $RC -eq 0 && "$(calls)" == *"HDMI-A-2 --brightness 0.70" ]]; then
    pass "set 70 -> 0.70"
else
    fail "set 70: rc=$RC calls=$(calls)"
fi
run two set 0
if [[ "$OUT" == 10 ]]; then
    pass "set 0 clamps to 10"
else
    fail "set 0: out='$OUT'"
fi
run two set 250
if [[ "$OUT" == 100 ]]; then
    pass "set 250 clamps to 100"
else
    fail "set 250: out='$OUT'"
fi
for bad in "" abc -5 7.5; do
    run two set "$bad"
    if [[ $RC -ne 0 && ! -s "$LOG" ]]; then
        pass "set '$bad' rejected with no write"
    else
        fail "set '$bad': rc=$RC calls=$(calls)"
    fi
done
FAKE_SET_RC=1 run two set 50
if [[ $RC -ne 0 && "$ERR" == *"failed to set"* ]]; then
    pass "an xrandr write failure is reported and fails the run"
else
    fail "write failure: rc=$RC err='$ERR'"
fi
run two bogus
if [[ $RC -ne 0 ]]; then
    pass "unknown command rejected"
else
    fail "bogus accepted"
fi

if ((rc != 0)); then
    red "✗ dwm-brightness is broken"
    exit 1
fi
green "✓ dwm-brightness: reading, stepping, clamping and output selection all hold"
