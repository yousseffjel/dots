#!/usr/bin/env bash
# install-live.sh --dry-run without --target (scope J, J-3): the disk named
# by DISK= and WIPE= is erased, laid out, formatted and mounted at /mnt,
# then the swapfile and zram, for UEFI and for BIOS. The pair is required
# and must agree, --target refuses it, and each tool the disk stage needs
# must be on the ISO. Nothing is run or written: the recording fakes are
# in tests/lib/live-dry-run-env.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/live-dry-run-env.sh
source "$SCRIPT_DIR/lib/live-dry-run-env.sh"

blue "==> the disk stage (no --target)"
: >"$STATE/mounts"
printf '%s\n' 'DISK=/dev/vda' 'WIPE=/dev/vda' | cat "$SB/answers" - >"$SB/disk" && chmod 600 "$SB/disk"
TARGET="" run uefi --answers "$SB/disk"
check "UEFI: the chosen disk erased, laid out, formatted and mounted at /mnt" 0 \
    "/dev/vda is ERASED: GPT, ESP 1 GiB, /boot 1 GiB, / the rest" \
    "would run: sfdisk --wipe always --wipe-partitions always -q /dev/vda" \
    "size=1GiB, type=c12a7328-f81f-11d2-ba4b-00a0c93ec93b, name=dots-esp" \
    "would run: mkfs.vfat -F 32 -n EFI /dev/vda1" "would run: mkfs.ext4 -F -q -L boot /dev/vda2" \
    "would run: mkfs.ext4 -F -q -L void /dev/vda3" "would run: mount /dev/vda3 /mnt" \
    "would run: mount /dev/vda2 /mnt/boot" "would run: mount /dev/vda1 /mnt/boot/efi" \
    "then a 1843 MiB swapfile" "would run: fallocate -l 1932525568 /mnt/swapfile" "would run: mkswap -q /mnt/swapfile" \
    "would add to /mnt/etc/fstab: /swapfile none swap defaults,pri=10 0 0" \
    "export ZRAM_COMP_ALGORITHM=zstd" "would run: ln -sfn /etc/sv/zramen /mnt/etc/runit/runsvdir/default/zramen" \
    "xchroot /mnt grub-install --target=x86_64-efi" "dry run complete" -- "needs the EFI system partition" "i386-pc"
TARGET="" run bios --answers "$SB/disk"
check "BIOS: a bios_grub partition, no ESP, GRUB to the chosen disk" 0 \
    "size=1MiB, type=21686148-6449-6e6f-744e-656564454649, name=dots-bios" \
    "xchroot /mnt grub-install --target=i386-pc /dev/vda" -- "mkfs.vfat" "/boot/efi"
TARGET="" run uefi --answers "$SB/answers"
check "an answers file without DISK and no --target is refused" 1 "missing DISK" -- "would run"
sed 's|^WIPE=.*|WIPE=/dev/vdb|' "$SB/disk" >"$SB/wipe" && chmod 600 "$SB/wipe"
TARGET="" run uefi --answers "$SB/wipe"
check "WIPE naming another disk is refused" 1 "WIPE must repeat DISK" -- "would run"
printf '%s\n' "$T /dev/vda2 ext4" "$T/boot/efi /dev/vda1 vfat" >"$STATE/mounts"
echo c12a7328-f81f-11d2-ba4b-00a0c93ec93b >"$STATE/parttypes"
run uefi --answers "$SB/disk"
check "--target with DISK/WIPE in the answers is refused" 1 "Drop one" -- "would run"

blue "==> the disk stage's tools must be on the ISO"
# A sealed PATH: grep (live_is_live) and fakes for every tool but one. A
# prepended PATH would fall through to the host's real tool and pass.
# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"
DISK_TOOLS=(sfdisk udevadm mkfs.ext4 mkfs.vfat fallocate mkswap blkid numfmt)
for gone in "${DISK_TOOLS[@]}"; do
    seal="$SB/seal-$gone"
    seal_path "$seal" grep
    for c in xbps-install xchroot xgenfstab lsblk findmnt mountpoint git "${DISK_TOOLS[@]}"; do
        [[ $c == "$gone" ]] || fake "$seal" "$c" 'exit 0'
    done
    got="$( (
        # Local to this subshell on purpose: each tool is checked afresh.
        # shellcheck disable=SC2030
        PATH="$seal" LIVE_CMDLINE="$SB/cmdline-live" DRY_RUN=1 LIVE_DISK_MODE=1 LIVE_INTERACTIVE=0 LIVE_TARGET=/mnt
        # shellcheck source=../scripts/install-live-base.sh
        source "$DOTS_DIR/scripts/install-live-base.sh"
        live_preflight
    ) 2>&1 || true)"
    if [[ $got == *"missing on the live ISO: $gone"* ]]; then
        green "  ok: no $gone: refused before anything runs"
    else
        red "  FAIL: no $gone"
        printf '%s\n' "$got" | sed 's/^/      /'
        rc=1
    fi
done

exit "$rc"
