#!/usr/bin/env bash
# The live-ISO installer's partitions after sfdisk (scope J, J-3): the
# nodes are read back by number and GPT name (vda1, but nvme0n1p1), never
# guessed, except by a dry run. And a re-run over an earlier run's disk:
# a target that is already this disk's dots-root is resumed, anything else
# is unmounted and laid out again, and a table that does not read back is
# never formatted. The fakes, which record every mutating call, are in
# tests/lib/live-disk-env.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
# Called by the sourced modules, through in_live's eval.
# shellcheck disable=SC2329
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/live-disk-env.sh
source "$SCRIPT_DIR/lib/live-disk-env.sh"

blue "==> partition nodes, read back by number and name"
nodes() { # <disk> <firmware> — prints the three nodes or NO
    in_live "LIVE_DISK=$1 LIVE_FIRMWARE=$2; if live_part_nodes; then echo \"\$LIVE_PART1 \$LIVE_PART2 \$LIVE_PART3\"; else echo NO; fi"
}
printf '%s\n' '/dev/vda  ' '/dev/vda1 1 dots-esp' '/dev/vda2 2 dots-boot' '/dev/vda3 3 dots-root' \
    | says -nrpo NAME,PARTN,PARTLABEL /dev/vda
printf '%s\n' '/dev/nvme0n1  ' '/dev/nvme0n1p1 1 dots-bios' '/dev/nvme0n1p2 2 dots-boot' \
    '/dev/nvme0n1p3 3 dots-root' '/dev/mapper/cryptroot  ' | says -nrpo NAME,PARTN,PARTLABEL /dev/nvme0n1
if [[ "$(nodes /dev/vda uefi)" == "/dev/vda1 /dev/vda2 /dev/vda3" ]]; then pass "vda: vda1..3"; else fail "vda nodes" "$(nodes /dev/vda uefi)"; fi
if [[ "$(nodes /dev/nvme0n1 bios)" == "/dev/nvme0n1p1 /dev/nvme0n1p2 /dev/nvme0n1p3" ]]; then
    pass "nvme: p1..p3, a mapping inside a partition skipped"
else
    fail "nvme nodes" "$(nodes /dev/nvme0n1 bios)"
fi
if [[ "$(nodes /dev/vda bios)" == NO ]]; then pass "an ESP where BIOS wants bios_grub: not this layout"; else fail "wrong firmware layout"; fi
printf '%s\n' '/dev/vda  ' '/dev/vda1 1 dots-esp' '/dev/vda2 2 dots-boot' | says -nrpo NAME,PARTN,PARTLABEL /dev/vda
if [[ "$(nodes /dev/vda uefi)" == NO ]]; then pass "a missing root partition: not this layout"; else fail "missing partition"; fi
printf '%s\n' '/dev/vda1 1 dots-esp' '/dev/vda2 2 dots-boot' '/dev/vda3 3 dots-root' '/dev/vda4 4 data' \
    | says -nrpo NAME,PARTN,PARTLABEL /dev/vda
if [[ "$(nodes /dev/vda uefi)" == NO ]]; then pass "a fourth partition: not this layout"; else fail "extra partition"; fi
# shellcheck disable=SC2016
guess="$(in_live 'LIVE_DISK=/dev/nvme0n1; live_part_guess; echo "$LIVE_PART1 $LIVE_PART3"; LIVE_DISK=/dev/sda; live_part_guess; echo "$LIVE_PART2"')"
if [[ $guess == $'/dev/nvme0n1p1 /dev/nvme0n1p3\n/dev/sda2' ]]; then pass "the dry run's guessed names"; else fail "live_part_guess" "$guess"; fi

blue "==> an earlier run's disk: resumed or laid out again"
dots_vdc() { printf '%s\n' '/dev/vdc  ' '/dev/vdc1 1 dots-esp' '/dev/vdc2 2 dots-boot' '/dev/vdc3 3 dots-root'; }
dots_vdc >"$STATE/after-sfdisk"
prepare() {
    : >"$STATE/called"
    mkdir -p "$SB/mnt"
    out="$(in_live "LIVE_TARGET=$SB/mnt LIVE_DISK=/dev/vdc DRY_RUN=0; live_part_prepare")"
    called="$(cat "$STATE/called")"
}
dots_vdc | says -nrpo NAME,PARTN,PARTLABEL /dev/vdc
echo "$SB/mnt /dev/vdc3" >"$STATE/mounts"
prepare
if [[ $out == *"resuming it, not erasing"* && $called == *"mount /dev/vdc2 $SB/mnt/boot"* &&
    $called == *"mount /dev/vdc1 $SB/mnt/boot/efi"* && $called != *sfdisk* && $called != *mkfs* &&
    $called != *umount* && $called != *"mount /dev/vdc3"* ]]; then
    pass "the target is this disk's dots-root: resumed, only /boot and the ESP mounted"
else
    fail "resume" "$out"$'\n'"$called"
fi
printf '%s\n' '/dev/vdc  ' '/dev/vdc1 1 data' | says -nrpo NAME,PARTN,PARTLABEL /dev/vdc
echo "$SB/mnt /dev/vdc1" >"$STATE/mounts"
prepare
if [[ $called == "umount -R $SB/mnt"*"sfdisk --wipe always --wipe-partitions always -q /dev/vdc"*"mkfs.vfat -F 32 -n EFI /dev/vdc1"*"mkfs.ext4 -F -q -L void /dev/vdc3"*"mount /dev/vdc3 $SB/mnt"* ]]; then
    pass "anything else under the target: unmounted first, then laid out, formatted, mounted"
else
    fail "re-layout" "$out"$'\n'"$called"
fi
: >"$STATE/after-sfdisk"
: >"$STATE/mounts"
prepare
if [[ $out == *"does not show the three dots-* partitions"* && $called != *mkfs* && $called != *mount\ * ]]; then
    pass "a table that does not read back is never formatted"
else
    fail "read-back failure" "$out"$'\n'"$called"
fi

exit "$rc"
