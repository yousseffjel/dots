#!/usr/bin/env bash
# Exercises config/dwm/bin/dwm-shotkey with fake xinput, xmodmap, pkill and
# pgrep on a sealed PATH, and a fake dwm-screenshot beside a copy of it.
#
# What is asserted:
#   * the captured stream of a real Super+a then Escape (tests/fixtures,
#     `xinput test-xi2 --root` in Xvfb) starts one region-to-clipboard shot
#     with --no-grab, and the Escape kills slop while that shot runs;
#   * a alone, Super+Shift+a, and Escape with no shot running do nothing;
#   * a second Super+a while a shot runs, or an autorepeated a, starts none;
#   * the "a" key is looked up in the live keymap (an AZERTY a fires, the US
#     keycode does not), with the evdev keycodes when xmodmap is missing;
#   * it exits at once when another listener runs (a bash process), not when
#     a wrapper such as setsid matches, and fails without xinput;
#   * an xinput that ends while the X server is still up (BadAccess: another
#     client holds the root window's XI2 selections) is restarted, and why is
#     logged; once `xinput list` fails too, it exits.
#
# SAFETY: pkill is a fake — the real one would kill the tester's own slop.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

FIXTURE="$SCRIPT_DIR/fixtures/xinput-test-xi2-super-a-escape.txt"
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

seal_path "$SB/real" bash cat awk id sleep mkdir
mkdir -p "$SB/fake" "$SB/noxi" "$SB/bin"
cp "$DOTS_DIR/config/dwm/bin/dwm-shotkey" "$SB/bin/"
export LOG="$SB/log" SB

# The shot runs for a moment, so an Escape that follows it finds it running.
# shellcheck disable=SC2016 # expanded by the fake, not here
fake "$SB/bin" dwm-screenshot 'echo "shot $*" >>"$LOG"; sleep "${SHOT_TIME:-0.5}"'
# `xinput list` answers whether the X server is up: no, unless XLIST_UP
# names a counter file holding how many more times to say yes. test-xi2
# replays $STREAM, with XI_ERR on stderr.
# shellcheck disable=SC2016
fake "$SB/fake" xinput 'if [ "$1" = list ]; then
    n="$(cat "${XLIST_UP:-/nonexistent}" 2>/dev/null)" || exit 1
    [ "${n:-0}" -gt 0 ] || exit 1
    echo $((n - 1)) >"$XLIST_UP"
    exit 0
fi
cat "$STREAM"
[ -z "${XI_ERR:-}" ] || echo "$XI_ERR" >&2'
# The real format: `keycode  38 = a A a A`. XMODMAP_A moves the a key.
# shellcheck disable=SC2016
fake "$SB/fake" xmodmap 'printf "keycode   9 = Escape NoSymbol Escape\nkeycode  %s = a A a A\nkeycode 133 = Super_L NoSymbol Super_L\nkeycode 134 = Super_R NoSymbol Super_R\n" "${XMODMAP_A:-38}"'
# shellcheck disable=SC2016
fake "$SB/fake" pkill 'echo "pkill $*" >>"$LOG"'
# shellcheck disable=SC2016
fake "$SB/fake" pgrep '[ -n "${OTHER:-}" ] && echo "$OTHER"; exit 0'
for t in pkill pgrep xmodmap; do ln -s "$SB/fake/$t" "$SB/noxi/$t"; done

# A stream in the fixture's format: p<code> is a press, r<code> a release.
stream() {
    local e
    for e in "$@"; do
        if [[ "$e" == p* ]]; then printf 'EVENT type 13 (RawKeyPress)\n'; else printf 'EVENT type 14 (RawKeyRelease)\n'; fi
        printf '    device: 3 (5)\n    time:   1\n    detail: %s\n    valuators:\n\n' "${e:1}"
    done >"$SB/stream"
}

rc=0
RC=0
# run [VAR=val...] — the listener over $STREAM, then long enough for any shot.
run() {
    rm -f "$LOG"
    RC=0
    env PATH="${BIN:-$SB/fake}:$SB/real" STREAM="${STREAM:-$SB/stream}" \
        XDG_STATE_HOME="$SB/state" "$@" \
        "$(type -P bash)" "$SB/bin/dwm-shotkey" >/dev/null 2>&1 || RC=$?
    sleep 0.8
}
check() {
    local name="$1" want="$2" got
    got="$({ tr '\n' '|' <"$LOG"; } 2>/dev/null || true)"
    if [[ "$got" == "$want" ]]; then
        green "  ok: $name"
    else
        red "  $name: expected '$want', got '$got'"
        rc=1
    fi
}

SHOT='shot --region --clipboard --no-grab|'
blue "==> dwm-shotkey"
STREAM="$FIXTURE" run
check "real xinput stream: Super+a shoots, Escape kills slop" "${SHOT}pkill -u $(id -u) -x slop|"

stream p38 r38
run
check "a alone does nothing" ""
stream p133 p50 p38 r38 r50 r133
run
check "Super+Shift+a is not this key" ""
stream p9 r9
run
check "Escape with no shot running kills nothing" ""
stream p133 p38 r38 p38 r38 r133
run
check "a second Super+a while the shot runs starts none" "$SHOT"
stream p133 p38 p38 p38 r38 r133
run SHOT_TIME=0
check "autorepeat of a is one press" "$SHOT"
stream p134 p38 r38 r134
run
check "Super_R works too" "$SHOT"

stream p133 p38 r38 r133
run XMODMAP_A=24
check "AZERTY: the US keycode is not a" ""
stream p133 p24 r24 r133
run XMODMAP_A=24
check "AZERTY: a is read from the keymap" "$SHOT"
BIN="$SB/noxi" STREAM="$FIXTURE" run
if [[ $RC -ne 0 ]]; then
    green "  ok: no xinput: exits non-zero"
else
    red "  no xinput: exited 0"
    rc=1
fi
# pgrep's matches are judged by their comm: bash is another listener, anything
# else (setsid, timeout) a wrapper whose command line ends in the same path.
mkdir -p "$SB/proc/4242"
echo bash >"$SB/proc/4242/comm"
echo "4242 (bash) S 1 4242" >"$SB/proc/4242/stat"
STREAM="$FIXTURE" run OTHER=4242 DOTS_PROC="$SB/proc"
check "another listener running: exits, shoots nothing" ""
# Its own \$( ) subshell: bash, but a child of the listener. The fake's
# parent is that subshell, or the listener when bash ran pgrep without one;
# the entry it writes names the listener as its parent either way. (Until
# mkdir was sealed in, the fake's mkdir failed and this case tested nothing.)
mkdir -p "$SB/child"
# shellcheck disable=SC2016 # expanded by the fake, not here
fake "$SB/child" pgrep 'l=$PPID
p="$(awk "{ print \$4 }" "/proc/$l/stat")"
awk "BEGIN { RS = \"\\0\" } /dwm-shotkey\$/ { f = 1 } END { exit !f }" "/proc/$p/cmdline" && l=$p
echo 4243; mkdir -p "$SB/proc/4243"; echo bash >"$SB/proc/4243/comm"; echo "4243 (bash) S $l 4243" >"$SB/proc/4243/stat"'
BIN="$SB/child:$SB/fake" STREAM="$FIXTURE" run DOTS_PROC="$SB/proc"
check "its own pgrep subshell is not another listener" "${SHOT}pkill -u $(id -u) -x slop|"
echo setsid >"$SB/proc/4242/comm"
STREAM="$FIXTURE" run OTHER=4242 DOTS_PROC="$SB/proc"
check "a wrapper (setsid -f) is not another listener" "${SHOT}pkill -u $(id -u) -x slop|"

# The server stays up for one more check: the stream is listened to twice.
stream p133 p38 r38 r133
echo 1 >"$SB/xlist"
run SHOT_TIME=0 XLIST_UP="$SB/xlist" XI_ERR="X Error of failed request:  BadAccess"
check "xinput ends, X still up: listens again" "$SHOT$SHOT"
if grep -q 'exited: X Error of failed request:  BadAccess; retrying in 1s' "$SB/state/dots/shotkey.log" 2>/dev/null; then
    green "  ok: the retry and xinput's error are logged"
else
    red "  the retry is not logged: '$(cat "$SB/state/dots/shotkey.log" 2>/dev/null)'"
    rc=1
fi
if ((rc == 0)); then green "✓ dwm-shotkey"; else red "✗ dwm-shotkey"; fi
exit "$rc"
