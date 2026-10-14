#!/usr/bin/env bash
# Every config/dwm/bin/dwm-* command answers --help with a usage line and
# exits 0 — without opening a menu, notifying, or touching the session.
#
# WHY. Eight of them used to ignore --help and open their dmenu: a smoke run
# on the Fedora VM (2026-10-14) left a clipboard menu on the user's screen.
# Run by the glob, never a list, so a new dwm-* script is held to it too.
#
# HOW. Each runs under `env -i` with a PATH of fakes: dmenu, notify-send,
# xrandr, xdotool, pkill, systemctl and friends record that they were called,
# and any record fails the check. `timeout` bounds a script that waits for
# input anyway. dwm-lib-*.sh are sourced libraries, not commands, and are
# skipped.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
LOG="$SB/called.log"
seal_path "$SB/bin" bash sed grep awk cat tr cut head tail sort readlink dirname basename timeout
# Anything a menu, a notification or a session change would reach.
for t in dmenu notify-send dunstify xrandr xdotool xprop xrdb xsetroot pkill pgrep \
    systemctl loginctl slock xss-lock maim slop ffmpeg feh clipmenu picom gdbus \
    brightnessctl pamixer xclip xsel autorandr gammastep; do
    fake "$SB/bin" "$t" "echo \"$t \$*\" >>'$LOG'"
done

fails=0
n=0
for s in "$DOTS_DIR"/config/dwm/bin/dwm-*; do
    name="${s##*/}"
    [[ "$name" == dwm-lib-* ]] && continue
    n=$((n + 1))
    : >"$LOG"
    rc=0
    out="$(env -i PATH="$SB/bin" HOME="$SB/home" DISPLAY=:99 \
        timeout 5 "$SB/bin/bash" "$s" --help 2>&1)" || rc=$?
    if [[ $rc -ne 0 ]]; then
        red "  FAIL  $name --help exited $rc${out:+: ${out%%$'\n'*}}"
        fails=$((fails + 1))
    elif [[ "$out" != usage:* && "$out" != *$'\n'usage:* ]]; then
        red "  FAIL  $name --help printed no usage line: ${out%%$'\n'*}"
        fails=$((fails + 1))
    elif [[ -s "$LOG" ]]; then
        red "  FAIL  $name --help reached: $(tr '\n' ';' <"$LOG")"
        fails=$((fails + 1))
    else
        green "  ok    $name"
    fi
done

if ((n < 10)); then
    red "✗ found only $n dwm-* commands — wrong DOTS_DIR?"
    exit 1
fi
if ((fails > 0)); then
    red "✗ $fails of $n dwm-* commands mishandle --help"
    exit 1
fi
green "✓ dwm-help: all $n dwm-* commands answer --help and open nothing"
