#!/usr/bin/env bash
# Exercises config/dwm/bin/dwm-osd against fake pamixer, dwm-brightness and
# dunstify on a sealed PATH.
#
# What is asserted:
#   * each kind sends one notification carrying its own stack tag (so a held
#     key replaces one pop-up) and the level as int:value;
#   * mute shows "muted" with no progress bar;
#   * the mic reads the default SOURCE, not the sink;
#   * no audio server (pamixer prints nothing) and no dunstify are both a
#     silent exit 0 — a missing pop-up must never fail the volume key;
#   * a bad argument is exit 1.
#
# SAFETY: every tool it calls is a fake. A real dunstify would pop up on the
# tester's desktop; a real pamixer is harmless here but would make the
# assertions depend on the host's volume.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SUT="$DOTS_DIR/config/dwm/bin/dwm-osd"
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
LOG="$SB/calls.log"
export LOG

seal_path "$SB/real" cat
mkdir -p "$SB/fake"
# The fakes read their answers from files, so each case sets state by
# writing a file rather than rebuilding the fake.
# shellcheck disable=SC2016
fake "$SB/fake" pamixer '
src=sink; [ "$1" = --default-source ] && { src=source; shift; }
case "$1" in
--get-mute) cat "'"$SB"'/$src.mute" 2>/dev/null ;;
--get-volume) cat "'"$SB"'/$src.vol" 2>/dev/null ;;
esac'
# shellcheck disable=SC2016
fake "$SB/fake" dwm-brightness 'cat "'"$SB"'/brightness" 2>/dev/null'
# shellcheck disable=SC2016
fake "$SB/fake" dunstify 'printf "%s\n" "$*" >>"$LOG"'

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}

# osd <kind> — runs the SUT, records its exit code in $RC.
osd() {
    : >"$LOG"
    RC=0
    PATH="$SB/fake:$SB/real" "$(type -P bash)" "$SUT" "$@" >/dev/null 2>&1 || RC=$?
}
calls() { wc -l <"$LOG"; }

blue "volume"
echo false >"$SB/sink.mute"
echo 40 >"$SB/sink.vol"
osd volume
check "exit 0" test "$RC" -eq 0
check "one notification" test "$(calls)" -eq 1
check "volume stack tag" grep -q 'string:x-dunst-stack-tag:dwm-osd-volume' "$LOG"
check "level as a progress value" grep -q 'int:value:40' "$LOG"

blue "volume muted"
echo true >"$SB/sink.mute"
osd volume
check "says muted" grep -q 'Volume muted' "$LOG"
no_progress() { ! grep -q int:value "$LOG"; }
check "no progress bar when muted" no_progress

blue "mic reads the source"
echo false >"$SB/source.mute"
echo 70 >"$SB/source.vol"
osd mic
check "mic level from --default-source" grep -q 'int:value:70' "$LOG"
check "mic stack tag" grep -q 'dwm-osd-mic' "$LOG"

blue "brightness"
echo 60 >"$SB/brightness"
osd brightness
check "brightness level" grep -q 'int:value:60' "$LOG"
check "brightness stack tag" grep -q 'dwm-osd-brightness' "$LOG"

blue "nothing to show"
echo false >"$SB/sink.mute"
: >"$SB/sink.vol"
osd volume
check "no audio server: exit 0" test "$RC" -eq 0
check "no audio server: no pop-up" test "$(calls)" -eq 0
mv "$SB/fake/dunstify" "$SB/dunstify.off"
echo 40 >"$SB/sink.vol"
osd volume
check "no dunstify: exit 0" test "$RC" -eq 0
mv "$SB/dunstify.off" "$SB/fake/dunstify"

blue "bad arguments"
osd louder
check "unknown kind: exit 1" test "$RC" -eq 1
osd
check "no argument: exit 1" test "$RC" -eq 1

if [[ $FAILS -gt 0 ]]; then
    red "$FAILS check(s) failed"
    exit 1
fi
green "✓ dwm-osd"
