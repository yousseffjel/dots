#!/usr/bin/env bash
# Exercises suckless/dwmblocks/scripts/dwm-net against a fake nmcli and a
# fake /sys/class/net (DWM_NET_SYSFS), on a sealed PATH.
#
# What is asserted:
#   * Wi-Fi shows its SSID and signal; a '\:' in a terse-mode SSID is
#     unescaped; a long SSID is cut;
#   * wired only shows `eth`; Wi-Fi wins when both are connected;
#   * loopback's "connected (externally)" never counts as a connection;
#   * nothing connected shows `off`;
#   * no nmcli, or nmcli printing nothing (NetworkManager stopped), falls
#     back to the kernel's operstate, skipping lo;
#   * the Wi-Fi signal is read with `--rescan no` — a scan every 30 s would
#     stall the bar for seconds.
#
# The fake nmcli output copies the real `-t` shape: ':'-separated fields, a
# literal ':' inside a field escaped as '\:', loopback reported as
# "connected (externally)".

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SUT="$DOTS_DIR/suckless/dwmblocks/scripts/dwm-net"
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
LOG="$SB/calls.log"
export LOG

seal_path "$SB/real" cat sed head cut
mkdir -p "$SB/fake" "$SB/home"
# timeout is faked as a pass-through so the real one's process-group
# handling cannot interfere; the block's own use of it is what matters.
# shellcheck disable=SC2016
fake "$SB/fake" timeout 'shift; exec "$@"'
# shellcheck disable=SC2016
fake "$SB/fake" nmcli '
echo "nmcli $*" >>"$LOG"
case "$*" in
*"device status"*) cat "'"$SB"'/status" 2>/dev/null ;;
*"device wifi list"*) cat "'"$SB"'/wifi" 2>/dev/null ;;
esac'

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}

# net — runs the block, colour escapes stripped, into $OUT.
net() {
    : >"$LOG"
    OUT="$(env -i HOME="$SB/home" XDG_CACHE_HOME="$SB/home/.cache" \
        LOG="$LOG" DWM_NET_SYSFS="$SB/sys" PATH="$SB/fake:$SB/real" \
        /bin/sh "$SUT" 2>/dev/null | sed 's/\^[^^]*\^//g')"
}
sysdev() { # sysdev <name> <operstate>
    mkdir -p "$SB/sys/$1"
    echo "$2" >"$SB/sys/$1/operstate"
}
is() { [[ "$OUT" == "$1" ]] || {
    red "        got: '$OUT'"
    return 1
}; }

blue "Wi-Fi"
printf '%s\n' 'wifi:connected:Home\:Net' 'ethernet:unavailable:' 'loopback:connected (externally):lo' >"$SB/status"
printf '%s\n' 'no:40' 'yes:72' >"$SB/wifi"
net
check "SSID unescaped, with signal" is "NET Home:Net 72%"
check "signal read without a rescan" grep -q -- '--rescan no' "$LOG"

blue "long SSID"
printf '%s\n' 'wifi:connected:ABCDEFGHIJKLMNOPQRSTUVWXYZ' >"$SB/status"
net
check "cut to 16 characters" is "NET ABCDEFGHIJKLMNOP… 72%"

blue "wired"
printf '%s\n' 'ethernet:connected:Wired connection 1' 'loopback:connected (externally):lo' >"$SB/status"
net
check "shows eth" is "NET eth"

blue "wired, set up outside NetworkManager"
printf '%s\n' 'ethernet:connected (externally):enp1s0' 'loopback:connected (externally):lo' >"$SB/status"
net
check "connected (externally) counts" is "NET eth"

blue "both"
printf '%s\n' 'ethernet:connected:Wired connection 1' 'wifi:connected:Cafe' >"$SB/status"
net
check "Wi-Fi wins" is "NET Cafe 72%"

blue "two Wi-Fi adapters"
printf '%s\n' 'wifi:connected:First' 'wifi:connected:Second' >"$SB/status"
net
check "the first listed (NetworkManager's primary) wins" is "NET First 72%"

blue "nothing connected"
printf '%s\n' 'ethernet:unavailable:' 'wifi:disconnected:' 'loopback:connected (externally):lo' >"$SB/status"
net
check "loopback does not count" is "NET off"

blue "fallbacks"
: >"$SB/status"
sysdev lo up
sysdev enp1s0 up
net
check "NetworkManager silent: kernel link state" is "NET up"
sysdev enp1s0 down
net
check "only lo up: off" is "NET off"
mv "$SB/fake/nmcli" "$SB/nmcli.off"
sysdev enp1s0 up
net
check "no nmcli: kernel link state" is "NET up"

if [[ $FAILS -gt 0 ]]; then
    red "$FAILS check(s) failed"
    exit 1
fi
green "✓ dwm-net"
