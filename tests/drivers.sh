#!/usr/bin/env bash
# Exercises `dots drivers` (scripts/drivers-*.sh) and doctor's drivers checks
# against generated /sys trees and fake xbps-query, xbps-install,
# xbps-reconfigure, uname and fwupdmgr on a sealed PATH, with the runit dirs
# in the sandbox. No real hardware, package database or kernel log is read.
#
# The xbps fakes answer as the real 0.60.7 does (probed 2026-10-15):
# `xbps-query <n>` 0/2 installed; `-R <n>` 0/2 in the index; `-Rs <pattern>`
# "[-] <pkgver> <desc>" lines; `-Rf <pkg>` one path per line.
#
# What is asserted:
#   * GPU -> package: Intel Broadwell+ gets intel-media-driver, pre-Broadwell
#     libva-intel-driver, AMD mesa-vaapi; a virtual GPU and a non-display PCI
#     device get nothing;
#   * NVIDIA is never installed: the branch package (Void's nonfree names)
#     comes from pci.ids (scoped to the vendor block), Secure Boot adds a
#     warning, an unknown codename only points at the guide, and
#     nvidia-vaapi-driver follows a loaded driver;
#   * firmware is installed only for files the kernel failed to load AND a
#     linux-firmware* package ships (matched with Void's .zst suffix and
#     vendor subdirectories) — a driver's fallback attempts install nothing;
#   * microcode on bare metal by CPU vendor (intel-ucode, or
#     linux-firmware-amd), with the initramfs rebuilt; intel-ucode out of reach
#     (nonfree off) is said, never a repo added; fwupd; all skipped in a VM;
#   * VM detection without systemd: the hypervisor CPU flag and DMI vendor;
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
export DB="$SB/pkgdb" LOG="$SB/calls.log" FWMAP="$SB/fwmap" SB \
    DOTS_RUNIT_SV="$SB/sv" DOTS_RUNIT_SERVICE="$SB/service"

seal_path "$SB/bin" bash grep awk sed mkdir touch mktemp mv rm tail head cut sort cat wc \
    basename dirname readlink od tr ln chmod cmp install git cp
# shellcheck disable=SC2016 # the bodies expand when the fakes run
{
    # FWMAP: "<package> <path>" — the firmware packages' file lists.
    fake "$SB/bin" xbps-query 'case "$1" in
-R) [[ " ${FAKE_UNAVAIL:-} " == *" $2 "* ]] && exit 2; exit 0 ;;
-Rs) [[ " ${FAKE_FAIL:-} " == *" fwquery "* ]] && exit 1
    cut -d" " -f1 "$FWMAP" | sort -u | sed "s/.*/[-] &-20260810_1 Binary firmware blobs/" ;;
-Rf) awk -v p="$2" "\$1 == p {print \$2}" "$FWMAP" ;;
*) grep -qx "$1" "$DB" || exit 2; echo "$1-1_1" ;;
esac'
    fake "$SB/bin" xbps-install 'echo "xbps-install $*" >>"$LOG"
[[ "$1" == -y ]] || exit 1
[[ " ${FAKE_FAIL:-} " == *" $2 "* ]] && { echo "ERROR: $2: failed to download" >&2; exit 1; }
echo "$2" >>"$DB"
[[ "$2" == power-profiles-daemon ]] && mkdir -p "$DOTS_RUNIT_SV/power-profiles-daemon"
exit 0'
    fake "$SB/bin" xbps-reconfigure 'echo "xbps-reconfigure $*" >>"$LOG"'
    fake "$SB/bin" uname '[[ "$1" == -r ]] && echo 6.12.5_1'
    fake "$SB/bin" fwupdmgr 'exit "${FAKE_FWUPD_RC:-2}"'
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
# Void keeps iwlwifi under intel/iwlwifi/, compressed; the kernel asks for the
# bare name. The -90 file is in no package (a driver's fallback attempt).
printf '%s\n' 'linux-firmware-network /usr/lib/firmware/intel/iwlwifi/iwlwifi-so-a0-gf-a0-89.ucode.zst' \
    'linux-firmware-intel /usr/lib/firmware/i915/adlp_dmc.bin.zst' >"$FWMAP"

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
no_installs() { ! grep -q '^xbps-install' "$LOG"; }
no_rebuild() { ! grep -q '^xbps-reconfigure' "$LOG"; }
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
# <virt> sets DOTS_VIRT, except "detect": then the CPU flags (with the
# hypervisor flag) and DMI decide, as on a real machine.
machine() {
    SYSFS="$SB/sys-$RANDOM$RANDOM"
    export DOTS_SYSFS="$SYSFS" DOTS_VIRT="$2"
    [[ "$2" == detect ]] && unset DOTS_VIRT
    mkdir -p "$SYSFS/bus/pci/devices"
    printf 'vendor_id\t: %s\nflags\t\t: fpu vme de%s\n' "$1" "${HYPERVISOR_FLAG:-}" >"$DOTS_CPUINFO"
    shift 2
    rm -rf "$SB/state" "$SB/xorg.conf.d" "$SB/sv" "$SB/service"
    mkdir -p "$SB/sv" "$SB/service"
    : >"$DB"
    : >"$LOG"
    : >"$DOTS_KERNEL_LOG"
    local p
    for p in "$@"; do echo "$p" >>"$DB"; done
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
