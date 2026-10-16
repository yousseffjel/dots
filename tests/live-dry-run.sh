#!/usr/bin/env bash
# install-live.sh --dry-run --target (scope J, J-1 and J-2), against fake
# block devices: the right packages and GRUB commands for UEFI and for BIOS,
# the dots stage and its flags, every refusal made before a command is
# printed, and nothing ever run or written. The disk stage (no --target)
# is tests/live-dry-run-disk.sh; both share tests/lib/live-dry-run-env.sh.
#
# One cross-check runs the REAL findmnt and lsblk through live_disk_of on
# this host, so a format drift fails here, not on someone's disk.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/live-dry-run-env.sh
source "$SCRIPT_DIR/lib/live-dry-run-env.sh"

blue "==> UEFI"
printf '%s\n' "$T /dev/vda2 ext4" "$T/boot/efi /dev/vda1 vfat" >"$STATE/mounts"
echo gpt >"$STATE/pttype"
echo c12a7328-f81f-11d2-ba4b-00a0c93ec93b >"$STATE/parttypes"
run uefi --answers "$SB/answers"
check "both kernels, grub and the EFI modules into the target" 0 \
    "xbps-install -Sy -r $T -R https://repo-default.voidlinux.org/current base-system linux-lts grub zramen grub-x86_64-efi" \
    "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Void" \
    "--efi-directory=/boot/efi --removable" "xchroot $T xbps-reconfigure -fa" \
    "would set the ysf password (hash, chpasswd on stdin)" "xchroot $T passwd -l root" \
    '%wheel ALL=(ALL:ALL) ALL' "(dry-run) would be: GRUB installed" "dry run complete" -- "$H6" "i386-pc" "ok      base system installed"
check "dots: cloned, installed as the user under a temporary rule, then unmounted" 0 \
    "would run: git clone --quiet --local --no-hardlinks $DOTS_DIR $T/home/ysf/dots" \
    "would write $T/etc/sudoers.d/99-dots-live-install (mode 440)" "ysf ALL=(ALL:ALL) NOPASSWD: ALL" \
    "xchroot $T sh -c su - ysf -c 'cd ~/dots && ./scripts/install-void.sh'" "would run: umount -R $T" \
    "would remove $T/etc/resolv.conf if xchroot left it empty" \
    -- "would run: reboot"
run uefi --answers "$SB/answers" --reboot
check "--reboot reboots after the unmount" 0 "would run: umount -R $T" "would run: reboot"
run uefi --answers "$SB/answers" --skip-dots
check "--skip-dots stops at the bootable system" 0 "dry run complete" -- \
    "NOPASSWD" "install-void.sh" "umount" "git clone"

printf '%s\n' "$T /dev/vda2 ext4" >"$STATE/mounts"
run uefi --answers "$SB/answers"
check "UEFI without the ESP mounted is refused" 1 "needs the EFI system partition" -- "would run"

blue "==> BIOS"
printf '%s\n' "$T /dev/vda2 ext4" >"$STATE/mounts"
printf '%s\n' 21686148-6449-6e6f-744e-656564454649 0fc63daf-8483-4772-8e79-3d69d8477de4 >"$STATE/parttypes"
run bios --answers "$SB/answers"
check "GRUB's boot code goes to the whole disk, no EFI package" 0 \
    "xchroot $T grub-install --target=i386-pc /dev/vda" "boot code written to /dev/vda" \
    -- "grub-x86_64-efi" "efi-directory"

echo 0fc63daf-8483-4772-8e79-3d69d8477de4 >"$STATE/parttypes"
run bios --answers "$SB/answers"
check "a GPT disk without a bios_grub partition is refused" 1 "needs a 1 MiB bios_grub partition" -- "would run"

echo dos >"$STATE/pttype"
run bios --answers "$SB/answers"
check "an MBR disk needs no bios_grub partition" 0 "has an MBR table" "--target=i386-pc /dev/vda"

blue "==> refusals"
CMDLINE="$SB/cmdline-installed" run bios --answers "$SB/answers"
check "an installed system (no root=live:) is refused" 1 "Not the Void live ISO" -- "would run"
printf '%s\n' "/elsewhere /dev/vda2 ext4" >"$STATE/mounts"
run bios --answers "$SB/answers"
check "an unmounted target is refused" 1 "Mount the new root filesystem at $T first" -- "would run"
printf '%s\n' "$T /dev/vda2 ext4" >"$STATE/mounts"
sed 's/^KEYMAP=.*/KEYMAP=nope/' "$SB/answers" >"$SB/bad" && chmod 600 "$SB/bad"
run bios --answers "$SB/bad"
check "bad answers are refused before any command" 1 "invalid KEYMAP" -- "would run"

blue "==> a password that did not land is caught"
# Plain chpasswd once exited 0 and set nothing (the BIOS VM run,
# 2026-10-16). live_check_password reads the shadow entry back instead.
mkdir -p "$SB/tgt/etc"
printf '%s\n' 'root:!x:20742::::::' 'ysf:!:20742:0:99999:7:::' "kept:$H6:20742::::::" >"$SB/tgt/etc/shadow"
check_pw() {
    (
        # Local to this subshell on purpose: each check sources afresh.
        # shellcheck disable=SC2030
        LIVE_TARGET="$SB/tgt"
        # shellcheck source=../scripts/install-live-config.sh
        source "$DOTS_DIR/scripts/install-live-config.sh"
        live_check_password "$1"
    ) >/dev/null 2>&1
}
if ! check_pw ysf && ! check_pw root && ! check_pw nobody && check_pw kept; then
    green "  ok: '!', a locked root and a missing user fail; a crypt hash passes"
else
    red "  FAIL: live_check_password"
    rc=1
fi

blue "==> the real host"
: >"$STATE/called"
set +e
out="$(bash "$DOTS_DIR/scripts/install-live.sh" --dry-run --target "$T" --answers "$SB/answers" 2>&1)"
status=$?
set -e
if grep -q 'root=live:' /proc/cmdline 2>/dev/null; then
    green "  skip: this host IS a live ISO"
else
    check "this host (not a live ISO) is refused with no overrides" 1 "Not the Void live ISO"
fi
root_src="$(findmnt -nvo SOURCE --mountpoint / 2>/dev/null || true)"
# Only where lsblk knows the root device: GitHub's ubuntu runners mount
# root from /dev/root, a name lsblk cannot resolve.
if [[ $root_src == /dev/* ]] && command -v lsblk >/dev/null && lsblk -n "$root_src" >/dev/null 2>&1; then
    disk="$(
        DRY_RUN=1
        # shellcheck source=../scripts/install-live-base.sh
        source "$DOTS_DIR/scripts/install-live-base.sh"
        live_disk_of /
    )"
    if [[ $disk == /dev/* && "$(lsblk -ndo TYPE "$disk")" == disk ]]; then
        green "  ok: the real findmnt/lsblk resolve / to a disk ($disk)"
    else
        red "  FAIL: live_disk_of / with the real tools gave '$disk' for $root_src"
        rc=1
    fi
else
    green "  skip: lsblk does not know / here ($root_src)"
fi

exit "$rc"
