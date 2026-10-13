#!/usr/bin/env bash
# Exercises `dots drivers` (scripts/drivers-*.sh) and doctor's drivers checks
# against generated /sys trees and fake rpm, dnf and fwupdmgr on a sealed
# PATH. No real hardware, package database or kernel log is read.
#
# What is asserted:
#   * GPU -> package: Intel Broadwell+ gets intel-media-driver, pre-Broadwell
#     libva-intel-driver, AMD the freeworld mesa — a swap with a REPO row where
#     a separate mesa-va-drivers is installed (f43), a plain install where it
#     is not (f44); a virtual GPU and a non-display PCI device get nothing;
#   * NVIDIA is never installed: the branch comes from pci.ids (scoped to the
#     vendor block), Secure Boot adds the MOK steps, an unknown codename only
#     points at the guide, and libva-nvidia-driver follows a loaded driver;
#   * firmware is installed only for files the kernel failed to load AND a
#     package ships — a driver's fallback attempts install nothing;
#   * microcode and fwupd on bare metal, by CPU vendor; skipped in a VM;
#   * without RPM Fusion the video drivers are skipped, never a repo added;
#   * a re-run is a no-op, --dry-run changes nothing, and every install has
#     the manifest row uninstall needs;
#   * doctor's check_drivers agrees with what was installed.

# Predicates are only called through check's "$@". See tests/pkg-repos.sh.
# shellcheck disable=SC2317,SC2329

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# No colours of its own (CLAUDE.md rule 2): it sources global_fn.sh and then
# replaces them with plain ones, as tests/pkg-repos.sh does.

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
export DB="$SB/rpmdb" LOG="$SB/calls.log" FWMAP="$SB/fwmap" SB

seal_path "$SB/bin" bash grep awk sed mkdir touch mktemp mv rm tail head cut sort cat wc \
    basename dirname readlink od tr ln chmod cmp install git cp
# shellcheck disable=SC2016 # the bodies expand when the fakes run
{
    fake "$SB/bin" rpm 'echo "rpm $*" >>"$LOG"; [[ "$1" == -q ]] && grep -qx "$2" "$DB"'
    fake "$SB/bin" dnf 'echo "dnf $*" >>"$LOG"
case "$1" in
install) [[ " ${FAKE_FAIL:-} " == *" $3 "* ]] && exit 1; echo "$3" >>"$DB" ;;
swap) grep -vx "$3" "$DB" >"$DB.new" || true; mv "$DB.new" "$DB"; echo "$4" >>"$DB" ;;
repoquery) [[ " ${FAKE_FAIL:-} " == *" repoquery "* ]] && exit 1; f="${@: -1}"; f="${f#/usr/lib/firmware/}"; awk -v f="${f%\*}" "\$1 == f {print \$2}" "$FWMAP" ;;
esac'
    fake "$SB/bin" fwupdmgr 'exit "${FAKE_FWUPD_RC:-2}"'
    # systemctl: is-enabled answers from $SB/enabled; enable --now records.
    fake "$SB/bin" systemctl 'echo "systemctl $*" >>"$LOG"
case "$1" in
is-enabled) grep -qx "$2" "$SB/enabled" 2>/dev/null && echo enabled || { echo disabled; exit 1; } ;;
enable) [[ " ${FAKE_FAIL:-} " == *" $3 "* ]] && exit 1; echo "$3" >>"$SB/enabled" ;;
esac'
}
PATH="$SB/bin"
export HOME="$SB/home" XDG_STATE_HOME="$SB/state" XDG_CONFIG_HOME="$SB/config" \
    XDG_DATA_HOME="$SB/data" XDG_CACHE_HOME="$SB/cache"

# A pci.ids where the NVIDIA device ids also appear under ANOTHER vendor
# first, so a lookup that ignores the vendor block reads the wrong name.
cat >"$SB/pci.ids" <<'EOF'
8086  Intel Corporation
	1b80  Not a GPU
	2484  Not a GPU either
10de  NVIDIA Corporation
	0a20  GT216 [GeForce GT 220]
	13c2  GM204 [GeForce GTX 970]
	1b80  GP104 [GeForce GTX 1080]
	2484  GA104 [GeForce RTX 3070]
	5000  XZ999 [From the future]
EOF
export DOTS_PCI_IDS="$SB/pci.ids" DOTS_CPUINFO="$SB/cpuinfo" DOTS_KERNEL_LOG="$SB/kmsg" \
    DOTS_XORG_CONF_DIR="$SB/xorg.conf.d"
printf '%s\t%s\n' iwlwifi-so-a0-gf-a0-89.ucode iwlwifi-mvm-firmware >"$FWMAP"

# shellcheck source=../scripts/global_fn.sh
source "$DOTS_DIR/scripts/global_fn.sh"
red() { printf '%s\n' "$*"; }
green() { red "$@"; }
yellow() { red "$@"; }
blue() { red "$@"; }
# read_pkg_list, as drivers.sh (the command) provides it to the lib.
PACKAGES_DIR="$DOTS_DIR/packages"
# shellcheck source=../scripts/install-pkg-tiers.sh
source "$DOTS_DIR/scripts/install-pkg-tiers.sh"
# shellcheck source=../scripts/drivers-lib.sh
source "$DOTS_DIR/scripts/drivers-lib.sh"
SUDO=() DRY_RUN=0

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then printf '\033[32m  ok    %s\033[0m\n' "$what"; else
        printf '\033[31m  FAIL  %s\033[0m\n' "$what"
        FAILS=$((FAILS + 1))
    fi
}
has() { grep -qx "$1" "$DB"; }
lacks() { ! has "$1"; }
not() { ! "$@"; }
said() { grep -qF -- "$1" <<<"$OUT"; }
not_said() { ! said "$1"; }
no_dnf_writes() { ! grep -qE '^dnf (install|swap)' "$LOG"; }
row() {
    local rows
    rows="$(manifest_rows "$1" | cut -f2-)"
    grep -qxF "$2" <<<"$rows"
}

# gpu <slot> <class> <vendor> <device> <driver|-> — one PCI function.
gpu() {
    local d="$SYSFS/bus/pci/devices/$1"
    mkdir -p "$d"
    printf '%s\n' "$2" >"$d/class"
    printf '0x%s\n' "$3" >"$d/vendor"
    printf '0x%s\n' "$4" >"$d/device"
    [[ "$5" == - ]] || ln -s "../../../bus/pci/drivers/$5" "$d/driver"
}
# machine <cpu vendor_id> <virt> <installed package>... — fresh state.
machine() {
    SYSFS="$SB/sys-$RANDOM$RANDOM"
    export DOTS_SYSFS="$SYSFS" DOTS_VIRT="$2"
    mkdir -p "$SYSFS/bus/pci/devices"
    printf 'vendor_id\t: %s\n' "$1" >"$DOTS_CPUINFO"
    shift 2
    rm -rf "$SB/state" "$SB/xorg.conf.d" "$SB/enabled"
    : >"$DB"
    : >"$LOG"
    : >"$DOTS_KERNEL_LOG"
    local p
    for p in rpmfusion-free-release rpmfusion-nonfree-release "$@"; do echo "$p" >>"$DB"; done
    FAILED_EXTRA=()
}
# chassis <smbios type> — the firmware's chassis_type.
chassis() {
    mkdir -p "$SYSFS/class/dmi/id"
    echo "$1" >"$SYSFS/class/dmi/id/chassis_type"
}
# battery <name> [scope] — a power_supply of type Battery.
battery() {
    mkdir -p "$SYSFS/class/power_supply/$1"
    echo Battery >"$SYSFS/class/power_supply/$1/type"
    [[ -z "${2:-}" ]] || echo "$2" >"$SYSFS/class/power_supply/$1/scope"
}
secure_boot_on() {
    mkdir -p "$SYSFS/firmware/efi/efivars"
    printf '\x06\x00\x00\x00\x01' >"$SYSFS/firmware/efi/efivars/SecureBoot-$DRIVERS_EFI_GLOBAL"
}
# Not a $(...) subshell: FAILED_EXTRA must survive the call.
run() {
    drivers_install >"$SB/out" 2>&1
    OUT="$(<"$SB/out")"
}

# shellcheck source=lib/drivers-cases.sh
source "$SCRIPT_DIR/lib/drivers-cases.sh"
# shellcheck source=lib/drivers-cases-laptop.sh
source "$SCRIPT_DIR/lib/drivers-cases-laptop.sh"

if [[ $FAILS -eq 0 ]]; then
    printf '\033[32m%s\033[0m\n' "✓ drivers: right package per device, NVIDIA reported only, reversible"
else
    printf '\033[31m%s\033[0m\n' "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
