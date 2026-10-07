#!/usr/bin/env bash
# Exercises the CPU, MEM, TEMP and DISK status blocks
# (suckless/dwmblocks/scripts/dwm-cpu, dwm-mem, dwm-temp, dwm-disk) on a
# sealed PATH — harness in tests/lib/blocks.sh.
#
# What is asserted:
#   * CPU differences /proc/stat against its cached sample, and reprints the
#     last figure when too little time has passed (a click's re-run);
#   * MEM is used/total from /proc/meminfo, n/a without MemAvailable;
#   * TEMP takes a CPU-package sensor BY NAME, never another hwmon, rounds
#     millidegrees, and changes colour at its thresholds;
#   * DISK reads `df -P`'s data row, n/a when df prints none, and changes
#     colour at its thresholds;
#   * left-click on CPU, MEM and TEMP opens htop in a terminal with class
#     dots-float-htop (dwm's "dots-float-" rule floats it) — alacritty, else
#     st — and does nothing when htop is not installed; left on DISK opens
#     thunar at /.
#
# /proc and hwmon are synthetic trees (DOTS_PROC_ROOT, DOTS_HWMON_ROOT). The
# df fake prints the real `df -P -h /` shape, copied from coreutils 9.x.

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

# colour_of — the first status2d escape of $RAW, i.e. the label's colour.
# shellcheck disable=SC2001 # [^^]* has no ${var//} equivalent
colour_of() { sed 's/^\(\^[^^]*\^\).*/\1/' <<<"$RAW"; }

htop_click() { # htop_click <block>
    block "$1" 1
    check "$1 left: htop in a floating alacritty" logged "alacritty --class dots-float-htop -e htop"
    mv "$SB/fake/alacritty" "$SB/alacritty.off"
    block "$1" 1
    check "$1 left: st when there is no alacritty" logged "st -c dots-float-htop -e htop"
    mv "$SB/alacritty.off" "$SB/fake/alacritty"
    mv "$SB/fake/htop" "$SB/htop.off"
    block "$1" 1
    check "$1 left: nothing without htop" not_logged "dots-float-htop"
    mv "$SB/htop.off" "$SB/fake/htop"
}

blue "CPU"
echo "cpu  100 0 100 800 0 0 0 0 0 0" >"$SB/proc/stat"
block dwm-cpu
check "first run: average since boot" is "CPU 20%"
echo "cpu  150 0 150 900 0 0 0 0 0 0" >"$SB/proc/stat"
block dwm-cpu
check "second run: the delta (100 busy of 200)" is "CPU 50%"
block dwm-cpu
check "no time passed: last figure reprinted" is "CPU 50%"
htop_click dwm-cpu

blue "MEM"
printf '%s\n' 'MemTotal:        8388608 kB' 'MemFree:          1048576 kB' \
    'MemAvailable:    6291456 kB' >"$SB/proc/meminfo"
block dwm-mem
check "used / total" is "MEM 2.0G/8G"
printf '%s\n' 'MemTotal:        8388608 kB' 'MemFree:          1048576 kB' >"$SB/proc/meminfo"
block dwm-mem
check "no MemAvailable (old kernel)" is "MEM n/a"
htop_click dwm-mem

blue "TEMP"
hwmon() { # hwmon <n> <name> <millideg>
    mkdir -p "$SB/hwmon/hwmon$1"
    echo "$2" >"$SB/hwmon/hwmon$1/name"
    echo "$3" >"$SB/hwmon/hwmon$1/temp1_input"
}
hwmon 0 nvme 45000
block dwm-temp
check "only a non-CPU sensor: n/a, not the NVMe's reading" is "TEMP n/a"
hwmon 1 coretemp 55400
block dwm-temp
check "the CPU package sensor, by name" is "TEMP 55°C"
normal="$(colour_of)"
hwmon 1 coretemp 71500
block dwm-temp
check "millidegrees round, not truncate" is "TEMP 72°C"
warn="$(colour_of)"
hwmon 1 k10temp 80000
block dwm-temp
urgent="$(colour_of)"
check "colour changes at 70 and again at 80" test "$normal" != "$warn" -a "$warn" != "$urgent" -a "$normal" != "$urgent"
htop_click dwm-temp

blue "DISK"
# shellcheck disable=SC2016
fake "$SB/fake" df 'cat "'"$SB"'/df"'
dfrow() { printf '%s\n' 'Filesystem      Size  Used Avail Use% Mounted on' \
    "/dev/nvme0n1p2  476G  338G  $1  $2% /" >"$SB/df"; }
dfrow 135G 72
block dwm-disk
check "free space from df -P" is "DISK 135G free"
normal="$(colour_of)"
dfrow 60G 87
block dwm-disk
warn="$(colour_of)"
dfrow 20G 96
block dwm-disk
urgent="$(colour_of)"
check "colour changes at 85% and again at 95%" test "$normal" != "$warn" -a "$warn" != "$urgent" -a "$normal" != "$urgent"
: >"$SB/df"
block dwm-disk
check "df prints nothing: n/a" is "DISK n/a"
block dwm-disk 1
check "left: thunar at /" logged "thunar /"

blocks_done "blocks-system"
