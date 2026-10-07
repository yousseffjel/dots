#!/usr/bin/env bash
# Exercises the VOL, MIC and GAMMA status blocks
# (suckless/dwmblocks/scripts/dwm-vol, dwm-mic, dwm-brightness-block) on a
# sealed PATH — harness in tests/lib/blocks.sh.
#
# What is asserted:
#   * each prints its value, `mute`/`off` when muted, and `n/a` when the tool
#     is missing or prints nothing (no sound server, no display);
#   * every click does what its header says, mutation BEFORE the read, so one
#     run both applies and shows the change;
#   * the clicks that change a level show the same dwm-osd pop-up the keys do,
#     and the ones that only open a window do not;
#   * MIC never touches the speakers: every pamixer call has --default-source;
#   * GAMMA finds dwm-brightness / dwm-osd / dwm-nightlight in
#     ~/.config/dwm/bin when PATH lacks them, as under dwmblocks, and still
#     renders when dwm-blockutil itself is missing.
#
# pamixer's fake prints what the real one prints: a bare integer for
# --get-volume and `true`/`false` for --get-mute (pamixer 1.6, 2026-10-07).

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

# shellcheck disable=SC2016
fake "$SB/fake" pamixer '
echo "pamixer $*" >>"$LOG"
case "$*" in
*--default-source*--get-mute*) cat "'"$SB"'/smute" ;;
*--default-source*--get-volume*) cat "'"$SB"'/svol" ;;
*--get-mute*) cat "'"$SB"'/mute" ;;
*--get-volume*) cat "'"$SB"'/vol" ;;
esac
exit 0'
echo false >"$SB/mute"
echo 42 >"$SB/vol"
echo false >"$SB/smute"
echo 70 >"$SB/svol"

blue "VOL"
block dwm-vol
check "level" is "VOL 42%"
echo true >"$SB/mute"
block dwm-vol
check "muted" is "VOL mute"
echo false >"$SB/mute"
: >"$SB/vol"
block dwm-vol
check "no sound server (pamixer prints nothing)" is "VOL n/a"
echo 42 >"$SB/vol"
block dwm-vol 1
check "left: toggles mute" logged "pamixer --toggle-mute"
check "left: shows the volume pop-up" logged "dwm-osd volume"
block dwm-vol 4
check "scroll up: raises AND unmutes" logged "pamixer --unmute --increase 5"
check "scroll up: pop-up" logged "dwm-osd volume"
block dwm-vol 5
check "scroll down: lowers, does not unmute" logged "pamixer --decrease 5"
check "scroll down: pop-up" logged "dwm-osd volume"
block dwm-vol 3
check "right: opens pavucontrol" logged "pavucontrol "
check "right: no pop-up (nothing changed)" not_logged dwm-osd
mv "$SB/fake/pamixer" "$SB/pamixer.off"
block dwm-vol
check "no pamixer" is "VOL n/a"
mv "$SB/pamixer.off" "$SB/fake/pamixer"

blue "MIC"
block dwm-mic
check "level" is "MIC 70%"
echo true >"$SB/smute"
block dwm-mic
check "muted" is "MIC off"
echo false >"$SB/smute"
block dwm-mic 1
check "left: toggles the SOURCE's mute" logged "pamixer --default-source --toggle-mute"
check "left: shows the mic pop-up" logged "dwm-osd mic"
# shellcheck disable=SC2016 # $1 is the inner bash's argument
check "every pamixer call names the source" bash -c '! grep "^pamixer" "$1" | grep -qv -- "--default-source"' _ "$LOG"

blue "GAMMA"
# shellcheck disable=SC2016 # $1 expands inside the fake
fake "$DWM_BIN" dwm-brightness '
echo "dwm-brightness $*" >>"$LOG"
[ "$1" = get ] && cat "'"$SB"'/gamma"
exit 0'
echo 80 >"$SB/gamma"
block dwm-brightness-block
check "level, found in ~/.config/dwm/bin off PATH" is "GAMMA 80%"
block dwm-brightness-block 4
check "scroll up: dwm-brightness up" logged "dwm-brightness up"
check "scroll up: brightness pop-up" logged "dwm-osd brightness"
block dwm-brightness-block 5
check "scroll down: dwm-brightness down" logged "dwm-brightness down"
check "scroll down: brightness pop-up" logged "dwm-osd brightness"
block dwm-brightness-block 1
check "left: toggles night light" logged "dwm-nightlight toggle"
check "left: no brightness change" not_logged "dwm-brightness up\|dwm-brightness down"
# dwm-blockutil promises that without it a block still RENDERS, and only its
# clicks stop. Run GAMMA from a directory with no helper beside it (and none
# in the sandbox's ~/.local/bin): it must still read its level.
mkdir -p "$SB/solo"
cp "$BLOCKS_DIR/dwm-brightness-block" "$SB/solo/"
OUT="$(env -i HOME="$SB/home" XDG_CONFIG_HOME="$SB/home/.config" LOG="$LOG" \
    PATH="$SB/fake:$SB/real" /bin/sh "$SB/solo/dwm-brightness-block" 2>/dev/null \
    | sed 's/\^[^^]*\^//g')"
check "renders without dwm-blockutil" is "GAMMA 80%"
: >"$SB/gamma"
block dwm-brightness-block
check "no display (get prints nothing)" is "GAMMA n/a"
rm "$DWM_BIN/dwm-brightness"
block dwm-brightness-block 4
check "no dwm-brightness" is "GAMMA n/a"
check "no dwm-brightness: no pop-up either" not_logged dwm-osd

blocks_done "blocks-audio"
