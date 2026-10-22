#!/usr/bin/env bash
# Exercises the clock, UPD and BT status blocks
# (suckless/dwmblocks/scripts/dwm-clock, dwm-updates, dwm-bluetooth) and the
# shared helpers in dwm-blockutil, on a sealed PATH — harness in
# tests/lib/blocks.sh.
#
# What is asserted:
#   * clock: one formatted date; left-click notifies the month's calendar;
#   * UPD: counts the `update` lines of a LOCAL dry run (`xbps-install -nu`,
#     no -S), not the `install` lines of new dependencies, and lists exactly
#     those packages; n/a when xbps fails or is missing; left lists them; right
#     opens the upgrade in a floating terminal EVEN when the count failed —
#     and that command, run for real against fakes, upgrades, then refreshes
#     the block, then waits for Enter;
#   * BT: n/a without bluetoothctl or an adapter, the crossed icon alone when
#     unpowered, the connect icon and count, the plain icon with none; left
#     opens blueman-manager;
#   * notification button (dwm-dnd): always visible — bell + history count,
#     FOCUS + held count while paused; right toggles and the same run renders
#     the new state, left opens dwm-notify;
#   * block_bin prefers PATH, falls back to ~/.config/dwm/bin, fails cleanly;
#     block_term fails cleanly with no terminal at all, and the class it
#     gives a terminal is one config.def.h's rules[] floats.
#
# The xbps fixture is `xbps-install -nu`'s real shape (`<pkgver> <action>
# <arch> <repo> <installed> <download>`, exit 0), captured with xbps-static
# 0.60.7 on 2026-10-15; bluetoothctl's from bluez 5.8x on the dev host.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"
# shellcheck source=lib/blocks.sh
source "$SCRIPT_DIR/lib/blocks.sh"
# For float_rule_classes only: the rules[] parser the dwm runtime test uses.
# shellcheck source=lib/dwm-runtime-floating.sh
source "$SCRIPT_DIR/lib/dwm-runtime-floating.sh"

has() { grep -qF -- "$1" "$LOG" || {
    red "        log: $(tr '\n' '|' <"$LOG")"
    return 1
}; }

blue "clock"
# The real date(1), pinned to one instant: the block's format string is what
# is under test, so it must go through the real formatter.
real_date="$(type -P date)"
fake "$SB/fake" date "LC_ALL=C exec $real_date -d '2026-10-07 14:05' \"\$@\""
fake "$SB/fake" cal 'echo CAL'
block dwm-clock
check "weekday, day, month, time" is "Wed 07 Oct 14:05"
block dwm-clock 1
check "left: the month's calendar" logged "notify-send -u low October 2026 CAL"

blue "UPD"
# shellcheck disable=SC2016
fake "$SB/fake" xbps-install 'echo "xbps-install $*" >>"$LOG"; cat "'"$SB"'/xbps.out"; exit "$(cat "'"$SB"'/xbps.rc")"'
printf '%s\n' \
    'oniguruma-6.9.10_1 update x86_64 https://repo-default.voidlinux.org/current 640404 199767' \
    'cairo-1.18.6_1 update x86_64 https://repo-default.voidlinux.org/current 1924096 731242' \
    'libnew-1.0_1 install x86_64 https://repo-default.voidlinux.org/current 10240 4096' \
    'mesa-26.2.5_1 update x86_64 https://repo-default.voidlinux.org/current 52428800 9437184' >"$SB/xbps.out"
echo 0 >"$SB/xbps.rc"
block dwm-updates
check "three pending, the new dependency not counted" is "󰏗 3"
check "a local dry run (-nu), never a sync" logged "xbps-install -nu"
block dwm-updates 1
check "left: lists them" has "notify-send -u low 3 update(s) pending oniguruma-6.9.10_1"
: >"$SB/xbps.out"
block dwm-updates
check "none pending" is "󰏗 0"
echo 1 >"$SB/xbps.rc"
block dwm-updates 3
check "xbps failed (no index yet): n/a" is "󰏗 n/a"
check "right: the upgrade terminal opens anyway" has "alacritty --class dots-float-updates -e sh -c sudo xbps-install -Su;"
upgrade="$(sed -n 's/^alacritty --class dots-float-updates -e sh -c //p' "$LOG")"
# shellcheck disable=SC2016
for t in sudo pkill; do fake "$SB/fake" "$t" 'echo "${0##*/} $*" >>"$LOG"'; done
: >"$LOG"
env -i LOG="$LOG" PATH="$SB/fake:$SB/real" /bin/sh -c "$upgrade" <<<"" >/dev/null
check "the upgrade command syncs and upgrades everything, then refreshes UPD (signal 1)" \
    test "$(tr '\n' '|' <"$LOG")" = "sudo xbps-install -Su|pkill -RTMIN+1 dwmblocks|"
mv "$SB/fake/xbps-install" "$SB/xbps.off"
block dwm-updates
check "no xbps" is "󰏗 n/a"

blue "BT"
# shellcheck disable=SC2016
fake "$SB/fake" bluetoothctl 'case "$*" in show) cat "'"$SB"'/bt.show" ;; "devices Connected") cat "'"$SB"'/bt.dev" ;; esac'
btshow() { printf '%s\n' 'Controller 28:0C:50:84:AA:9D (public)' '	Name: Antar' \
    "	Powered: $1" '	Discoverable: no' >"$SB/bt.show"; }
: >"$SB/bt.show"
block dwm-bluetooth
check "no adapter / no bluetoothd" is "󰂯 n/a"
btshow no
block dwm-bluetooth
check "unpowered: the crossed icon alone" is "󰂲"
btshow yes
printf '%s\n' 'Device AA:BB:CC:DD:EE:01 Headset' 'Device AA:BB:CC:DD:EE:02 Mouse' >"$SB/bt.dev"
block dwm-bluetooth
check "connected: the connect icon and the count" is "󰂱 2"
: >"$SB/bt.dev"
block dwm-bluetooth
check "powered, nothing connected: the icon alone" is "󰂯"
block dwm-bluetooth 1
check "left: blueman-manager" logged "blueman-manager "
rm "$SB/fake/bluetoothctl"
block dwm-bluetooth
check "no bluetoothctl" is "󰂯 n/a"

blue "notification button (dwm-dnd)"
# dunstctl answers from state files: paused, and the history/waiting counts.
# shellcheck disable=SC2016
fake "$SB/fake" dunstctl 'echo "dunstctl $*" >>"$LOG"
case "$1 ${2:-}" in
"is-paused "*) cat "'"$SB"'/paused" ;;
"set-paused toggle") v=true; [ "$(cat "'"$SB"'/paused")" = true ] && v=false; echo "$v" >"'"$SB"'/paused" ;;
"count history") cat "'"$SB"'/history" ;;
"count waiting") cat "'"$SB"'/waiting" ;;
esac'
# shellcheck disable=SC2016
fake "$DWM_BIN" dwm-notify 'echo "dwm-notify $*" >>"$LOG"'
echo false >"$SB/paused"
echo 0 >"$SB/history"
echo 0 >"$SB/waiting"
block dwm-dnd
check "flowing, empty history: a bare bell (always visible)" is "󰂚"
echo 3 >"$SB/history"
block dwm-dnd
check "flowing: bell and the history count" is "󰂚 3"
echo true >"$SB/paused"
block dwm-dnd
check "paused, nothing held: FOCUS" is "󰂛 FOCUS"
echo 2 >"$SB/waiting"
block dwm-dnd
check "paused: FOCUS and the count held back" is "󰂛 FOCUS 2"
block dwm-dnd 3
check "right: toggles focus mode" logged "dunstctl set-paused toggle"
check "right: the same run renders the new state" is "󰂚 3"
block dwm-dnd 1
check "left: opens the notification centre" logged "dwm-notify menu"
check "left: changes nothing itself" not_logged "set-paused"
echo garbage >"$SB/history"
block dwm-dnd
check "a count that is not a number is not shown" is "󰂚"
# For this one run, a timeout that records what it wraps: every dunstctl call
# must go through it, or a wedged bus freezes the whole bar.
# shellcheck disable=SC2016
fake "$SB/fake" timeout 'echo "timeout $*" >>"$LOG"; shift; exec "$@"'
block dwm-dnd 3
check "every dunstctl call is wrapped in timeout" \
    test "$(grep -c '^dunstctl' "$LOG")" = "$(grep -c '^timeout [0-9]* dunstctl' "$LOG")"
check "...and there were calls to wrap" test "$(grep -c '^dunstctl' "$LOG")" -ge 2
# shellcheck disable=SC2016
fake "$SB/fake" timeout 'shift; exec "$@"'
: >"$SB/paused"
block dwm-dnd
check "dunst does not answer: still a (muted) button" is "󰂚"
rm "$SB/fake/dunstctl"
block dwm-dnd
check "no dunstctl: nothing" test -z "$RAW"

blue "signal-only blocks have a sender"
# A block with interval 0 is never polled: it changes only when something
# sends its signal, which for these is an sxhkd key. Read both sides — the
# blocks from blocks.def.h, the senders from sxhkdrc — so a new signal-only
# block without its pkill, or a key that lost it, fails here instead of
# freezing a bar entry.
sigs="$(awk -F'\t+' '/^\t\{"/ { gsub(/[},]/, "", $5); if ($4 + 0 == 0) print $5 }' \
    "$DOTS_DIR/suckless/dwmblocks/blocks.def.h")"
check "found the signal-only blocks" test -n "$sigs"
for sig in $sigs; do
    check "signal $sig is sent by an sxhkd binding" \
        grep -q "pkill -RTMIN+$sig dwmblocks" "$DOTS_DIR/config/sxhkd/sxhkdrc"
done

blue "dwm-blockutil"
util() { # util <PATH> <snippet> — the helper sourced as a block sources it
    env -i HOME="$SB/home" XDG_CONFIG_HOME="$SB/home/.config" LOG="$LOG" \
        PATH="$1" /bin/sh -c ". '$BLOCKS_DIR/dwm-blockutil'; $2"
}
mkdir -p "$SB/override"
fake "$SB/override" dwm-osd 'true'
check "block_bin: an override on PATH wins" \
    test "$(util "$SB/override:$SB/real" 'block_bin dwm-osd')" = "$SB/override/dwm-osd"
check "block_bin: falls back to ~/.config/dwm/bin" \
    test "$(util "$SB/real" 'block_bin dwm-osd')" = "$DWM_BIN/dwm-osd"
check "block_bin: neither — fails, prints nothing" \
    test "$(util "$SB/real" 'block_bin dwm-nope || echo FAILED')" = "FAILED"
check "block_term: no terminal at all — fails" \
    test "$(util "$SB/real" 'block_term x true || echo FAILED')" = "FAILED"

# The link between the two halves: a class block_term produces must be one
# that a floating rules[] entry matches (strstr), or every pop-up tiles.
: >"$LOG"
util "$SB/fake:$SB/real" 'block_term probe true'
for _ in $(seq 1 20); do
    [[ -s "$LOG" ]] && break
    sleep 0.05
done # backgrounded
cls="$(sed -n 's/^alacritty --class \([^ ]*\) .*/\1/p' "$LOG")"
floated=0
while read -r rule; do [[ -n "$rule" && "$cls" == *"$rule"* ]] && floated=1; done < <(float_rule_classes)
check "block_term's class ($cls) is floated by a rules[] entry" test "$floated" = 1

blocks_done "blocks-info"
