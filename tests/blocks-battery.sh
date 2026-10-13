#!/usr/bin/env bash
# Exercises the BAT status block (suckless/dwmblocks/scripts/dwm-battery) on a
# sealed PATH over a synthetic /sys/class/power_supply (DOTS_POWER_SUPPLY_ROOT)
# — harness in tests/lib/blocks.sh. scope-h slot 3.
#
# What is asserted:
#   * no system battery prints NOTHING (a desktop's bar is unchanged), and a
#     mouse battery (scope=Device) or an AC adapter does not count;
#   * the percent comes from energy (uWh) or charge (uAh), summed across two
#     batteries, and falls back to averaging `capacity` across mixed units;
#   * `+` while charging, and charging wins over a second draining battery;
#   * while discharging, STATUS_WARN at 15% and STATUS_URGENT at 5%;
#   * one notification per threshold crossed (low, then critical), never a
#     repeat on the next 60 s run, and re-armed by charging;
#   * left-click explains the state, with the time left from power_now.
#
# The attribute files copy the kernel's power_supply sysfs ABI: type,
# status (Charging/Discharging/Full/Not charging), scope, capacity,
# energy_now/energy_full/power_now and charge_now/charge_full/current_now.

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

# shellcheck disable=SC2001 # [^^]* has no ${var//} equivalent
colour_of() { sed 's/^\(\^[^^]*\^\).*/\1/' <<<"$RAW"; }
# notified <pattern> — a notify-send call matching <pattern>, polled because
# the block backgrounds it.
notified() {
    for _ in $(seq 1 20); do
        grep -q -- "$1" "$LOG" && return 0
        sleep 0.05
    done
    red "        log: $(tr '\n' '|' <"$LOG")"
    return 1
}
# ps <name> <attr=value>... — one power_supply directory.
ps() {
    local d="$SB/ps/$1" kv
    shift
    mkdir -p "$d"
    for kv in "$@"; do printf '%s\n' "${kv#*=}" >"$d/${kv%%=*}"; done
}
fresh() { rm -rf "$SB/ps" "$SB/home/.local/state" && mkdir -p "$SB/ps"; }

blue "==> a desktop: nothing at all"
fresh
ps AC type=Mains online=1
ps hidpp_battery_0 type=Battery scope=Device capacity=40 status=Discharging
block dwm-battery
check "no system battery: prints nothing, takes no space" test -z "$RAW"
block dwm-battery 1
check "...and a click does nothing" not_logged notify-send

blue "==> one battery, energy units"
fresh
ps BAT0 type=Battery status=Discharging capacity=99 energy_now=42000000 energy_full=50000000 power_now=10000000
block dwm-battery
check "84% from energy_now/energy_full, not the stale capacity file" is "BAT 84%"
check "normal colour above 15%" test "$(colour_of)" = "^c#7ebd6f^"
block dwm-battery 1
check "left: time left from power_now (42/10 Wh -> 4:12)" notified "Battery On battery, 84%, 4:12 left"

blue "==> two batteries, charge units; charging wins"
fresh
ps BAT0 type=Battery status=Charging charge_now=3000000 charge_full=4000000 current_now=1000000
ps BAT1 type=Battery status=Discharging charge_now=1000000 charge_full=4000000
block dwm-battery
check "summed charge: 4/8 Ah = 50%, + while charging" is "BAT 50%+"
block dwm-battery 1
check "left: time to full (4 Ah at 1 A -> 4:00)" notified "Battery Charging, 50%, full in 4:00"

blue "==> mixed units: average capacity"
fresh
ps BAT0 type=Battery status=Discharging capacity=80 energy_now=1 energy_full=2
ps BAT1 type=Battery status=Discharging capacity=40 charge_now=1 charge_full=2
block dwm-battery
check "units disagree: mean of capacity (60%)" is "BAT 60%"

blue "==> an unreadable attribute"
fresh
ps BAT0 type=Battery status=Discharging capacity= energy_now=garbage energy_full=50000000
block dwm-battery
check "empty capacity + junk energy_now: renders 0%, never blanks" is "BAT 0%"

blue "==> full on AC"
fresh
ps BAT0 type=Battery status=Full capacity=100
block dwm-battery
check "full, no +" is "BAT 100%"
block dwm-battery 1
check "left: plugged in" notified "Battery Plugged in, 100%"

blue "==> thresholds and alerts"
fresh
ps BAT0 type=Battery status=Discharging capacity=15
block dwm-battery
check "15% discharging: warn colour" test "$(colour_of)" = "^c#d9a05b^"
check "low alert sent" notified "notify-send -u normal -a dots .* Battery low 15% left"
block dwm-battery
check "next run at 15%: no repeat" not_logged notify-send
ps BAT0 capacity=5
block dwm-battery
check "5%: urgent colour" test "$(colour_of)" = "^c#cc5555^"
check "critical alert sent, critical urgency" notified "notify-send -u critical .* Battery critical 5% left"
ps BAT0 capacity=12
block dwm-battery
check "back at 12% after critical: no low alert" not_logged notify-send
ps BAT0 status=Charging capacity=12
block dwm-battery
check "charging: no alert, not warn-coloured" test "$(colour_of)" = "^c#7ebd6f^"
check "charging cleared the alert state" test ! -e "$SB/home/.local/state/dots/battery-alert"
ps BAT0 status=Discharging capacity=14
block dwm-battery
check "unplugged again below 15%: re-armed, alerts again" notified "Battery low 14% left"
rm "$SB/fake/notify-send"
fresh
ps BAT0 type=Battery status=Discharging capacity=3
block dwm-battery
check "no notify-send: the block still renders" is "BAT 3%"

blocks_done "blocks-battery"
