#!/usr/bin/env bash
# Exercises the runit service helpers (scripts/install-services-runit.sh) and
# their revert (uninstall_services in scripts/uninstall-runit.sh) on real
# directories: DOTS_RUNIT_SV and DOTS_RUNIT_SERVICE point at a sandbox, so
# `ln -s` and `rm` run for real and the assertions read the filesystem.
#
# What is asserted:
#   * the desktop services are linked in dbus-first order, one SERVICE row
#     each; a service not installed is skipped, with no row;
#   * NetworkManager enabled: dhcpcd and wpa_supplicant are unlinked
#     (SERVICEOFF rows); NetworkManager NOT installed: they are left alone,
#     so the box keeps its network;
#   * a re-run changes nothing and appends no row;
#   * the getty handover writes a down file only when there was none, and
#     records that it did;
#   * --dry-run touches nothing;
#   * uninstall unlinks what dots linked (dangling links included), re-links
#     what it unlinked, and removes only the down file it created.

# The predicates are only called through check's "$@". See tests/pkg-repos.sh.
# SC2016: the eval'd checks are single-quoted on purpose, so they expand when
# check runs them, not when the line is read.
# shellcheck disable=SC2317,SC2329,SC2016

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
# All four XDG variables: HOME alone leaks into the real install manifest.
export HOME="$SB/home" XDG_STATE_HOME="$SB/state" XDG_CONFIG_HOME="$SB/config" \
    XDG_DATA_HOME="$SB/data" XDG_CACHE_HOME="$SB/cache" \
    DOTS_RUNIT_SV="$SB/sv" DOTS_RUNIT_SERVICE="$SB/service" DOTS_VIRT=none

# No red/green/blue of its own (CLAUDE.md rule 2): it sources global_fn.sh,
# then replaces them with plain ones so output is greppable.
# shellcheck source=../scripts/global_fn.sh
source "$DOTS_DIR/scripts/global_fn.sh"
red() { printf 'RED %s\n' "$*"; }
green() { printf '%s\n' "$*"; }
yellow() { green "$@"; }
blue() { green "$@"; }
# shellcheck source=../scripts/uninstall-runit.sh
source "$DOTS_DIR/scripts/uninstall-runit.sh"
SUDO=() DRY_RUN=0 ASSUME_YES=1

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then printf '\033[32m  ok    %s\033[0m\n' "$what"; else
        printf '\033[31m  FAIL  %s\033[0m\n' "$what"
        FAILS=$((FAILS + 1))
    fi
}
said() { grep -qF -- "$1" "$SB/out"; }
linked() { [[ -L "$SB/service/$1" && "$(readlink "$SB/service/$1")" == "$SB/sv/$1" ]]; }
unlinked() { [[ ! -e "$SB/service/$1" && ! -L "$SB/service/$1" ]]; }
rows() { manifest_rows "$1" | cut -f2- | tr '\t\n' ' |'; }
# box <installed...> [-- <enabled...>] — a fresh /etc/sv and /var/service.
box() {
    rm -rf "$SB/sv" "$SB/service" "$SB/state"
    mkdir -p "$SB/sv" "$SB/service"
    local s mode=sv
    for s in "$@"; do
        [[ "$s" == -- ]] && mode=on && continue
        if [[ $mode == sv ]]; then mkdir -p "$SB/sv/$s"; else ln -s "$SB/sv/$s" "$SB/service/"; fi
    done
}

printf '\033[34m%s\033[0m\n' "==> a fresh Void base: dhcpcd running, no desktop services"
box dbus elogind NetworkManager bluetoothd dhcpcd wpa_supplicant agetty-tty2 -- dhcpcd agetty-tty2
services_enable_desktop >"$SB/out" 2>&1
check "the four desktop services are linked" eval 'linked dbus && linked elogind && linked NetworkManager && linked bluetoothd'
check "...one SERVICE row each, dbus first" test "$(rows SERVICE)" = "dbus|elogind|NetworkManager|bluetoothd|"
check "dhcpcd unlinked once NetworkManager is in" unlinked dhcpcd
check "...recorded, with no down file" test "$(rows SERVICEOFF)" = "dhcpcd |"
check "wpa_supplicant was not enabled: nothing to do, no row" test "$(manifest_rows SERVICEOFF | grep -c wpa || true)" -eq 0

printf '\033[34m%s\033[0m\n' "==> in a VM: the SPICE guest agent's system half too"
box dbus spice-vdagentd
DOTS_VIRT=kvm services_enable_desktop >"$SB/out" 2>&1
check "spice-vdagentd linked in a VM" linked spice-vdagentd
box dbus spice-vdagentd
services_enable_desktop >"$SB/out" 2>&1
check "...never on bare metal" unlinked spice-vdagentd
box dbus elogind NetworkManager bluetoothd dhcpcd wpa_supplicant agetty-tty2 -- dhcpcd agetty-tty2
services_enable_desktop >/dev/null 2>&1

printf '\033[34m%s\033[0m\n' "==> a re-run"
services_enable_desktop >"$SB/out" 2>&1
check "no new rows" test "$(rows SERVICE)$(rows SERVICEOFF)" = "dbus|elogind|NetworkManager|bluetoothd|dhcpcd |"
check "says already enabled" said "ok      dbus already enabled"

printf '\033[34m%s\033[0m\n' "==> NetworkManager not installed: the network is left alone"
box dbus elogind dhcpcd -- dhcpcd
services_enable_desktop >"$SB/out" 2>&1
check "dhcpcd still linked" linked dhcpcd
check "NetworkManager skipped, saying why" said "skip    NetworkManager — not installed"
check "no row for a skipped service" test "$(manifest_rows SERVICE | grep -c NetworkManager || true)" -eq 0

printf '\033[34m%s\033[0m\n' "==> the getty handover"
box agetty-tty2 ly -- agetty-tty2
runit_disable agetty-tty2 down >"$SB/out" 2>&1
runit_enable ly >>"$SB/out" 2>&1
check "getty unlinked, down file created" eval 'unlinked agetty-tty2 && [[ -e $SB/sv/agetty-tty2/down ]]'
check "...recorded as made by us" test "$(rows SERVICEOFF)" = "agetty-tty2 down|"
check "ly linked" linked ly
box agetty-tty2 -- agetty-tty2
touch "$SB/sv/agetty-tty2/down"
runit_disable agetty-tty2 down >"$SB/out" 2>&1
check "a down file already there is not claimed" test "$(rows SERVICEOFF)" = "agetty-tty2 |"

printf '\033[34m%s\033[0m\n' "==> --dry-run"
box dbus NetworkManager dhcpcd -- dhcpcd
DRY_RUN=1 services_enable_desktop >"$SB/out" 2>&1
check "nothing linked or unlinked" eval 'unlinked dbus && linked dhcpcd'
check "no rows" test -z "$(manifest_rows SERVICE)$(manifest_rows SERVICEOFF)"
check "says what it would do" said "(dry-run) would enable dbus"

printf '\033[34m%s\033[0m\n' "==> uninstall reverts it"
box dbus elogind NetworkManager bluetoothd dhcpcd agetty-tty2 ly -- dhcpcd agetty-tty2
services_enable_desktop >/dev/null 2>&1
runit_disable agetty-tty2 down >/dev/null 2>&1
runit_enable ly >/dev/null 2>&1
rm -rf "$SB/sv/bluetoothd" # its package was removed: a dangling link stays
uninstall_services >"$SB/out" 2>&1
check "every service dots linked is unlinked, the dangling one too" \
    eval 'unlinked dbus && unlinked elogind && unlinked NetworkManager && unlinked bluetoothd && unlinked ly'
check "dhcpcd re-linked (the network comes back)" linked dhcpcd
check "tty2's getty re-linked" linked agetty-tty2
check "...and the down file dots made is gone" test ! -e "$SB/sv/agetty-tty2/down"
box dhcpcd
manifest_append_row SERVICEOFF dhcpcd ""
touch "$SB/sv/dhcpcd/down"
uninstall_services >"$SB/out" 2>&1
check "a down file dots did not make is kept" test -e "$SB/sv/dhcpcd/down"
DRY_RUN=1
box dbus -- dbus
manifest_append_row SERVICE dbus
uninstall_services >"$SB/out" 2>&1
check "uninstall --dry-run unlinks nothing" linked dbus
DRY_RUN=0

if [[ $FAILS -eq 0 ]]; then
    printf '\033[32m%s\033[0m\n' "✓ runit services: enabled once, reverted exactly"
else
    printf '\033[31m%s\033[0m\n' "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
