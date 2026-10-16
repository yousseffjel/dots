#!/usr/bin/env bash
# The live-ISO installer's partitioning (scope J, J-3): lay the chosen disk
# out as GPT, format it and mount it at the target.
#
#   #  UEFI         BIOS              filesystem   mount
#   1  ESP, 1 GiB   bios_grub, 1 MiB  vfat / none  /boot/efi / -
#   2  1 GiB        1 GiB             ext4         /boot
#   3  the rest     the rest          ext4         /
#                                     (inside LUKS2 when chosen, J-4:
#                                      install-live-luks.sh)
#
# Each partition carries a GPT name (dots-esp or dots-bios, dots-boot,
# dots-root). The partition nodes are read back from lsblk by number and
# name, never built from the disk's name (vda1, but nvme0n1p1).
#
# Sourced by install-live.sh after install-live-base.sh (live_run, live_ok,
# LIVE_FIRMWARE, LIVE_BIOS_GRUB_GUID) and install-live-disk.sh (LIVE_DISK).
# Never standalone.
#
# usage: source "$SCRIPT_DIR/install-live-part.sh"
#
# A re-run converges. A target already mounted from this disk's dots-root
# is an earlier run that got past formatting (all three filesystems are
# made before the first mount), so it is resumed: only what is not mounted
# yet gets mounted. Encrypted, the root must be a mapping on dots-root that
# this run's passphrase opens. Otherwise whatever is mounted under the
# target is unmounted, any mapping on the disk closed, and the disk is laid
# out again.

LIVE_GUID_ESP="c12a7328-f81f-11d2-ba4b-00a0c93ec93b"
LIVE_GUID_LINUX="0fc63daf-8483-4772-8e79-3d69d8477de4"
LIVE_PART1="" LIVE_PART2="" LIVE_PART3=""

live_part_first_name() {
    if [[ $LIVE_FIRMWARE == uefi ]]; then echo dots-esp; else echo dots-bios; fi
}

# live_part_script — the sfdisk input for LIVE_FIRMWARE. sfdisk aligns the
# first partition at 1 MiB.
live_part_script() {
    echo 'label: gpt'
    if [[ $LIVE_FIRMWARE == uefi ]]; then
        echo "size=1GiB, type=$LIVE_GUID_ESP, name=dots-esp"
    else
        echo "size=1MiB, type=$LIVE_BIOS_GRUB_GUID, name=dots-bios"
    fi
    echo "size=1GiB, type=$LIVE_GUID_LINUX, name=dots-boot"
    echo "type=$LIVE_GUID_LINUX, name=dots-root"
}

# live_part_nodes — set LIVE_PART1..3 from lsblk and check each carries the
# name live_part_script gave it. Returns 1 unless the disk holds exactly
# this layout. Reads only.
live_part_nodes() {
    local out name n label want
    want=("" "$(live_part_first_name)" dots-boot dots-root)
    LIVE_PART1="" LIVE_PART2="" LIVE_PART3=""
    out="$(lsblk -nrpo NAME,PARTN,PARTLABEL "$LIVE_DISK")" || return 1
    while read -r name n label; do
        case "$n" in
            # The disk itself, or a mapping inside a partition (J-4).
            "") continue ;;
            1 | 2 | 3) [[ $label == "${want[n]}" ]] || return 1 ;;
            *) return 1 ;;
        esac
        printf -v "LIVE_PART$n" '%s' "$name"
    done <<<"$out"
    [[ -n $LIVE_PART1 && -n $LIVE_PART2 && -n $LIVE_PART3 ]]
}

# live_part_guess — what the nodes will be called, for a dry run only:
# there are no partitions to read back yet.
live_part_guess() {
    local p=""
    [[ $LIVE_DISK == *[0-9] ]] && p=p
    LIVE_PART1="${LIVE_DISK}${p}1" LIVE_PART2="${LIVE_DISK}${p}2" LIVE_PART3="${LIVE_DISK}${p}3"
}

# live_part_mkfs <esp|boot|root> <device> — the one place each filesystem's
# options live (tests/live-disk.sh runs them against image files).
live_part_mkfs() {
    case "$1" in
        esp) live_run mkfs.vfat -F 32 -n EFI "$2" ;;
        boot) live_run mkfs.ext4 -F -q -L boot "$2" ;;
        root) live_run mkfs.ext4 -F -q -L void "$2" ;;
    esac
}

# live_part_create — take down an earlier run's mounts, write the table,
# wait for udev to make the nodes, read them back, format all three.
live_part_create() {
    if [[ $DRY_RUN -eq 0 ]] && mountpoint -q "$LIVE_TARGET"; then
        live_run umount -R "$LIVE_TARGET"
    fi
    if [[ $DRY_RUN -eq 0 ]]; then
        live_luks_close_all
    fi
    blue "  new table on $LIVE_DISK ($LIVE_FIRMWARE):"
    live_part_script | sed 's/^/          /'
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would run: sfdisk --wipe always --wipe-partitions always -q $LIVE_DISK"
    else
        live_part_script | sfdisk --wipe always --wipe-partitions always -q "$LIVE_DISK"
    fi
    live_run udevadm settle
    if [[ $DRY_RUN -eq 1 ]]; then
        live_part_guess
    elif ! live_part_nodes; then
        red "sfdisk wrote $LIVE_DISK, but lsblk does not show the three dots-* partitions."
        return 1
    fi
    if [[ $LIVE_FIRMWARE == uefi ]]; then
        live_part_mkfs esp "$LIVE_PART1"
    fi
    live_part_mkfs boot "$LIVE_PART2"
    if [[ $LIVE_LUKS -eq 1 ]]; then
        live_luks_format
    fi
    live_part_mkfs root "$(live_luks_root_dev)"
}

# live_mount_once <device> <dir> — mount unless something already is.
live_mount_once() {
    if [[ $DRY_RUN -eq 0 ]] && mountpoint -q "$2"; then
        return 0
    fi
    live_run mkdir -p "$2"
    live_run mount "$1" "$2"
}

# live_part_prepare — partition, format and mount LIVE_DISK at the target,
# or resume an earlier run that got that far. Called plainly, never from an
# || list, so set -e still stops it at the first failing command.
live_part_prepare() {
    local src
    blue "==> disk $LIVE_DISK"
    src="$(findmnt -nvo SOURCE --mountpoint "$LIVE_TARGET" 2>/dev/null || true)"
    if [[ $DRY_RUN -eq 0 && -n $src ]] && live_part_nodes && live_luks_resumable "$src"; then
        yellow "note    $LIVE_TARGET is $src from an earlier run: resuming it, not erasing"
    else
        live_part_create
    fi
    live_mount_once "$(live_luks_root_dev)" "$LIVE_TARGET"
    live_mount_once "$LIVE_PART2" "$LIVE_TARGET/boot"
    if [[ $LIVE_FIRMWARE == uefi ]]; then
        live_mount_once "$LIVE_PART1" "$LIVE_TARGET/boot/efi"
    fi
    live_ok "$LIVE_DISK partitioned, formatted and mounted at $LIVE_TARGET"
}
