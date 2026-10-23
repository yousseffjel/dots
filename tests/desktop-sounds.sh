#!/usr/bin/env bash
# config/dwm/bin/dwm-sound and dwm-sound-notify against a fake pw-play, on a
# sealed PATH — NOTHING PLAYS: no real pw-play is ever reachable. Checked:
#   * an event plays its sound-theme file; $XDG_DATA_HOME wins over
#     $XDG_DATA_DIRS, and .oga over .wav; --file prints the same path;
#   * an unknown event exits 1 naming the package; bad arguments exit 2;
#   * `off` silences everything (status says so), `on` brings it back; no
#     pw-play exits 0, silently;
#   * one sound of each event at a time: while the lock is held the same
#     event is dropped, another event still plays;
#   * --login: once per session (bus address), again for a new one; it waits
#     for an audio server that is not up yet, and gives up quietly;
#   * dwm-sound-notify: CRITICAL -> dialog-warning, NORMAL ->
#     message-new-instant, LOW -> nothing (the OSD and screenshot pop-ups);
#   * the volume keys tick on raise and lower, not on mute.
# The dunst side (the rule runs only for a shown notification) is
# tests/dunst-reload.sh; the screenshot shutter is tests/dwm-screenshot.sh.
# SEALED PATH: tests/lib/sealed-path.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

PASS=0
FAIL=0
check() {
    local what="$1"
    shift
    if "$@"; then
        green "  ok: $what"
        PASS=$((PASS + 1))
    else
        red "  FAIL: $what"
        FAIL=$((FAIL + 1))
    fi
}

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"
BINDIR="$DOTS_DIR/config/dwm/bin"
BIN="$SB/bin"
LOG="$SB/play.log"
seal_path "$BIN" bash mkdir rm cut id flock
# shellcheck disable=SC2016 # the bodies expand when the fakes run
{
    # pw-play FILE: logged; fails while $SB/fails holds a count above 0.
    fake "$BIN" pw-play 'n="$(<"$FAILS")"; if ((n > 0)); then echo $((n - 1)) >"$FAILS"; exit 1; fi
echo "${1#"$SHARE"/}" >>"$LOG"'
    fake "$BIN" sleep 'echo sleep >>"$LOG"'
    fake "$BIN" pgrep 'exit 1'
}

SHARE="$SB/share"
STEREO="sounds/freedesktop/stereo"
mkdir -p "$SHARE/sys/$STEREO" "$SHARE/home/$STEREO"
for e in service-login message-new-instant dialog-warning audio-volume-change; do
    : >"$SHARE/sys/$STEREO/$e.oga"
done
: >"$SHARE/sys/$STEREO/bell.wav"
: >"$SHARE/home/$STEREO/bell.oga"
: >"$SHARE/sys/$STEREO/complete.wav"

# run <cmd> [args...] — cmd is dwm-sound or dwm-sound-notify; BUS from the caller.
run() {
    local cmd="$1"
    shift
    : >"$LOG"
    echo "${FAILN:-0}" >"$SB/fails"
    env -i PATH="$BIN" HOME="$SB/home" XDG_DATA_HOME="$SHARE/home" XDG_DATA_DIRS="$SHARE/none:$SHARE/sys" \
        XDG_STATE_HOME="$SB/state" XDG_RUNTIME_DIR="$SB/run" DBUS_SESSION_BUS_ADDRESS="${BUS:-}" \
        LOG="$LOG" FAILS="$SB/fails" SHARE="$SHARE" "$(type -P bash)" "$BINDIR/$cmd" "$@" >"$SB/out" 2>&1
}
played() { [[ "$(paste -sd' ' "$LOG")" == "$1" ]]; }
nothing() { [[ ! -s "$LOG" ]]; }
says() { grep -q -- "$1" "$SB/out"; }
rc_of() {
    local rc=0
    run "$@" || rc=$?
    echo "$rc"
}

blue "==> playing an event"
run dwm-sound message-new-instant
check "an event plays its theme file" played "sys/$STEREO/message-new-instant.oga"
run dwm-sound bell
check "XDG_DATA_HOME wins over XDG_DATA_DIRS" played "home/$STEREO/bell.oga"
run dwm-sound complete
check "a .wav is found when there is no .oga" played "sys/$STEREO/complete.wav"
run dwm-sound --file bell
check "--file prints the file it would play" says "^$SHARE/home/$STEREO/bell.oga$"
check "...playing nothing" nothing
check "an unknown event exits 1" test "$(rc_of dwm-sound no-such-event)" -eq 1
check "...naming the package" says 'sound-theme-freedesktop'
check "no argument exits 2" test "$(rc_of dwm-sound)" -eq 2
check "an unknown option exits 2" test "$(rc_of dwm-sound --bogus)" -eq 2
check "an event with a slash exits 2" test "$(rc_of dwm-sound ../x)" -eq 2

blue "==> the switch"
run dwm-sound off
run dwm-sound status
check "off: status says off" says '^off$'
run dwm-sound message-new-instant
check "off: nothing plays" nothing
run dwm-sound on
run dwm-sound status
check "on: status says on" says '^on$'
run dwm-sound message-new-instant
check "on: it plays again" played "sys/$STEREO/message-new-instant.oga"
mv "$BIN/pw-play" "$SB/pw-play"
check "no pw-play: exit 0" test "$(rc_of dwm-sound message-new-instant)" -eq 0
check "...silently" test ! -s "$SB/out"
mv "$SB/pw-play" "$BIN/pw-play"

blue "==> one at a time"
mkdir -p "$SB/run/dots"
exec 8>"$SB/run/dots/sound-audio-volume-change.lock"
flock -n 8
run dwm-sound audio-volume-change
check "while one plays, the same event is dropped" nothing
run dwm-sound message-new-instant
check "...another event still plays" played "sys/$STEREO/message-new-instant.oga"
exec 8>&-
run dwm-sound audio-volume-change
check "once it ends, the event plays" played "sys/$STEREO/audio-volume-change.oga"

blue "==> the login chime"
BUS=unix:path=/tmp/dbus-A,guid=1
run dwm-sound --login
check "a new session chimes" played "sys/$STEREO/service-login.oga"
run dwm-sound --login
check "the same session (a dwm restart) does not" nothing
BUS=unix:path=/tmp/dbus-B,guid=2
FAILN=3 run dwm-sound --login
check "no audio server yet: waits, then chimes" played "sleep sleep sleep sys/$STEREO/service-login.oga"
BUS=unix:path=/tmp/dbus-C,guid=3
check "none ever: gives up with exit 0" test "$(FAILN=99 rc_of dwm-sound --login)" -eq 0
check "...after its ten tries" test "$(grep -c sleep "$LOG")" -eq 9

blue "==> dwm-sound-notify (dunst's rule script)"
run dwm-sound-notify app sum body icon CRITICAL
check "CRITICAL plays dialog-warning" played "sys/$STEREO/dialog-warning.oga"
run dwm-sound-notify app sum body icon NORMAL
check "NORMAL plays message-new-instant" played "sys/$STEREO/message-new-instant.oga"
run dwm-sound-notify dwm-osd "Volume  50%" "" "" LOW
check "LOW plays nothing" nothing
run dwm-sound-notify --help
check "--help answers usage" says '^usage: dwm-sound-notify'

blue "==> the volume keys"
key_cmd() { sed -n "/^$1\$/{n;p}" "$DOTS_DIR/config/sxhkd/sxhkdrc"; }
ticks() { [[ "$(key_cmd "$1")" == *"; dwm-sound audio-volume-change" ]]; }
check "raise ticks" ticks XF86AudioRaiseVolume
check "lower ticks" ticks XF86AudioLowerVolume
no_tick() { ! ticks "$1"; }
check "mute does not" no_tick XF86AudioMute

echo
if [[ $FAIL -eq 0 ]]; then
    green "desktop-sounds: $PASS passed"
else
    red "desktop-sounds: $FAIL failed, $PASS passed"
    exit 1
fi
