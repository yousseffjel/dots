#!/usr/bin/env bash
# Exercises the clock, UPD and BT status blocks
# (suckless/dwmblocks/scripts/dwm-clock, dwm-updates, dwm-bluetooth) and the
# shared helpers in dwm-blockutil, on a sealed PATH — harness in
# tests/lib/blocks.sh.
#
# What is asserted:
#   * clock: one formatted date; left-click notifies the month's calendar;
#   * UPD: counts dnf's package lines from the LOCAL cache (`-C`), skipping
#     the header and any Obsoleting section, and lists exactly those lines; n/a when dnf fails or is missing; left lists them; right
#     opens the upgrade in a floating terminal EVEN when the count failed —
#     and that command, run for real against fakes, upgrades, then refreshes
#     the block, then waits for Enter;
#   * BT: n/a without bluetoothctl or an adapter, off when unpowered, the
#     connected count, `on` with none; left opens blueman-manager;
#   * DND: empty (no bar space) unless dunst is paused; left resumes, and
#     the same run renders the block gone;
#   * block_bin prefers PATH, falls back to ~/.config/dwm/bin, fails cleanly;
#     block_term fails cleanly with no terminal at all, and the class it
#     gives a terminal is one config.def.h's rules[] floats.
#
# The dnf fixture is dnf5's real `check-update` shape (exit 100, an
# "Upgrades" header, `name.arch  version  repo`), captured on the Fedora 44
# VM 2026-10-07; bluetoothctl's from bluez 5.8x on the dev host.

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
fake "$SB/fake" dnf 'echo "dnf $*" >>"$LOG"; cat "'"$SB"'/dnf.out"; exit "$(cat "'"$SB"'/dnf.rc")"'
printf '%s\n' 'Upgrades' \
    'SDL3.x86_64                   3.4.18-1.fc44              updates' \
    'cairo.x86_64                  1.18.6-1.fc44              updates' \
    'cairo-devel.x86_64            1.18.6-1.fc44              updates' >"$SB/dnf.out"
echo 100 >"$SB/dnf.rc"
block dwm-updates
check "three pending, header not counted" is "UPD 3"
check "local cache only (-C), never the network" logged "dnf -C check-update -q"
block dwm-updates 1
check "left: lists them" has "notify-send -u low 3 update(s) pending SDL3.x86_64"
printf '%s\n' 'SDL3.x86_64    3.4.18-1.fc44    updates' 'Obsoleting Packages' \
    'grub2-tools.x86_64    1:2.12-30.fc44    updates' >"$SB/dnf.out"
block dwm-updates
check "the Obsoleting Packages section is not counted" is "UPD 1"
: >"$SB/dnf.out"
echo 0 >"$SB/dnf.rc"
block dwm-updates
check "none pending" is "UPD 0"
echo 1 >"$SB/dnf.rc"
block dwm-updates 3
check "dnf failed (no cache yet): n/a" is "UPD n/a"
check "right: the upgrade terminal opens anyway" has "alacritty --class dots-float-updates -e sh -c sudo dnf upgrade --refresh;"
upgrade="$(sed -n 's/^alacritty --class dots-float-updates -e sh -c //p' "$LOG")"
# shellcheck disable=SC2016
for t in sudo pkill; do fake "$SB/fake" "$t" 'echo "${0##*/} $*" >>"$LOG"'; done
: >"$LOG"
env -i LOG="$LOG" PATH="$SB/fake:$SB/real" /bin/sh -c "$upgrade" <<<"" >/dev/null
check "the upgrade command runs dnf, then refreshes UPD (signal 1)" \
    test "$(tr '\n' '|' <"$LOG")" = "sudo dnf upgrade --refresh|pkill -RTMIN+1 dwmblocks|"
mv "$SB/fake/dnf" "$SB/dnf.off"
block dwm-updates
check "no dnf" is "UPD n/a"

blue "BT"
# shellcheck disable=SC2016
fake "$SB/fake" bluetoothctl 'case "$*" in show) cat "'"$SB"'/bt.show" ;; "devices Connected") cat "'"$SB"'/bt.dev" ;; esac'
btshow() { printf '%s\n' 'Controller 28:0C:50:84:AA:9D (public)' '	Name: Antar' \
    "	Powered: $1" '	Discoverable: no' >"$SB/bt.show"; }
: >"$SB/bt.show"
block dwm-bluetooth
check "no adapter / no bluetoothd" is "BT n/a"
btshow no
block dwm-bluetooth
check "unpowered" is "BT off"
btshow yes
printf '%s\n' 'Device AA:BB:CC:DD:EE:01 Headset' 'Device AA:BB:CC:DD:EE:02 Mouse' >"$SB/bt.dev"
block dwm-bluetooth
check "connected count" is "BT 2"
: >"$SB/bt.dev"
block dwm-bluetooth
check "powered, nothing connected" is "BT on"
block dwm-bluetooth 1
check "left: blueman-manager" logged "blueman-manager "
rm "$SB/fake/bluetoothctl"
block dwm-bluetooth
check "no bluetoothctl" is "BT n/a"

blue "DND"
# dunstctl answers is-paused from a state file; set-paused writes it.
# shellcheck disable=SC2016
fake "$SB/fake" dunstctl 'echo "dunstctl $*" >>"$LOG"
case "$1" in
is-paused) cat "'"$SB"'/paused" ;;
set-paused) echo "$2" >"'"$SB"'/paused" ;;
esac'
echo false >"$SB/paused"
block dwm-dnd
check "notifications flowing: prints nothing (no bar space)" test -z "$RAW"
echo true >"$SB/paused"
block dwm-dnd
check "paused: DND" is "DND"
block dwm-dnd 1
check "left: resumes notifications" logged "dunstctl set-paused false"
check "left: the same run renders it gone" test -z "$RAW"
# For this one run, a timeout that records what it wraps: every dunstctl call
# must go through it, or a wedged bus freezes the whole bar.
# shellcheck disable=SC2016
fake "$SB/fake" timeout 'echo "timeout $*" >>"$LOG"; shift; exec "$@"'
block dwm-dnd
check "every dunstctl call is wrapped in timeout" \
    test "$(grep -c '^dunstctl' "$LOG")" = "$(grep -c '^timeout [0-9]* dunstctl' "$LOG")"
check "...and there was a call to wrap" grep -q '^dunstctl is-paused' "$LOG"
# shellcheck disable=SC2016
fake "$SB/fake" timeout 'shift; exec "$@"'
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
