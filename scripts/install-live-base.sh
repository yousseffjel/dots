#!/usr/bin/env bash
# The live-ISO installer's first half (scope J, J-1): refuse anywhere but
# the Void live ISO with a mounted target root, work out the firmware and
# the disk, then bootstrap the base system into the target with
# `xbps-install -r`.
#
# Sourced by install-live.sh, never standalone. It assumes `set -euo
# pipefail`, the red/green/yellow/blue helpers, DRY_RUN, LIVE_TARGET,
# LIVE_INTERACTIVE, LIVE_REPO and PACKAGES_DIR.
#
# usage: source "$SCRIPT_DIR/install-live-base.sh"
#
# Sets LIVE_FIRMWARE (uefi | bios) and LIVE_DISK (the whole disk under the
# target root, e.g. /dev/vda) for install-live-config.sh's GRUB step.
#
# Overridable at call time, for tests: LIVE_CMDLINE (/proc/cmdline) and
# LIVE_EFI_DIR (/sys/firmware/efi). Evidence for each probe below is in
# .claude/tasks/live-core/context.md (Step 1 findings).

LIVE_FIRMWARE=""
LIVE_DISK=""
# The partition type GRUB embeds itself in on a GPT disk under BIOS.
LIVE_BIOS_GRUB_GUID="21686148-6449-6e6f-744e-656564454649"

# live_run <cmd...> — run it, or under --dry-run say what would run.
# Every mutating command in the live installer goes through here.
live_run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would run: $*"
    else
        "$@"
    fi
}

# live_ok <text> — a step's closing line. A dry run only printed the
# step's commands, so it must not claim the step was done.
live_ok() {
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would be: $*"
    else
        green "ok      $*"
    fi
}

# Same comment/blank stripping as read_pkg_list() in install-pkg-tiers.sh.
live_read_list() {
    sed 's/#.*//' "$1" | tr -s '[:space:]' '\n' | grep -v '^$'
}

# The ISO boots with root=live:CDLABEL=VOID_LIVE (void-mklive mklive.sh);
# an installed system never does.
live_is_live() {
    grep -q 'root=live:' "${LIVE_CMDLINE:-/proc/cmdline}" 2>/dev/null
}

live_firmware() {
    if [[ -d ${LIVE_EFI_DIR:-/sys/firmware/efi} ]]; then echo uefi; else echo bios; fi
}

# live_disk_of <mountpoint> — the whole disk its filesystem lives on.
# `lsblk -s` walks up from the partition (or, from J-4, the LUKS mapping) to
# the disk. -v strips the [/subvol] suffix findmnt adds on btrfs.
live_disk_of() {
    local src
    src="$(findmnt -nvo SOURCE --mountpoint "$1")" || return 1
    lsblk -nrspo NAME,TYPE "$src" | awk '$2 == "disk" { print $1; exit }'
}

# live_check_boot_layout — what GRUB needs from the partitions the user made:
# a mounted vfat ESP on UEFI, a bios_grub partition on a GPT disk on BIOS.
live_check_boot_layout() {
    local esp="$LIVE_TARGET/boot/efi" fstype types
    if [[ $LIVE_FIRMWARE == uefi ]]; then
        fstype="$(findmnt -nvo FSTYPE --mountpoint "$esp" 2>/dev/null || true)"
        if [[ $fstype != vfat ]]; then
            red "UEFI boot needs the EFI system partition (vfat) mounted at $esp."
            return 1
        fi
        green "ok      EFI system partition mounted at $esp"
    elif [[ "$(lsblk -ndrpo PTTYPE "$LIVE_DISK")" == gpt ]]; then
        # Captured first: `lsblk | grep -q` is a 141 under pipefail when grep
        # exits early.
        types="$(lsblk -nrpo PARTTYPE "$LIVE_DISK")"
        if ! grep -qix "$LIVE_BIOS_GRUB_GUID" <<<"$types"; then
            red "BIOS boot from a GPT disk needs a 1 MiB bios_grub partition on $LIVE_DISK."
            return 1
        fi
        green "ok      bios_grub partition on $LIVE_DISK"
    else
        green "ok      $LIVE_DISK has an MBR table, GRUB goes in the boot gap"
    fi
}

# live_preflight — every refusal happens here, before anything is written.
# Each check returns explicitly: set -e is off inside a function called from
# an || list.
live_preflight() {
    local c need=(xbps-install xchroot xgenfstab lsblk findmnt mountpoint)
    [[ $LIVE_INTERACTIVE -eq 1 ]] && need+=(dialog)
    if [[ $EUID -ne 0 && $DRY_RUN -eq 0 ]]; then
        red "Run as root (the live ISO logs in as root)."
        return 1
    fi
    if ! live_is_live; then
        red "Not the Void live ISO (no root=live: on the kernel command line)."
        red "This installer writes a bootloader, so it runs only from the live ISO."
        return 1
    fi
    green "ok      running from the Void live ISO"
    for c in "${need[@]}"; do
        command -v "$c" >/dev/null 2>&1 || {
            red "missing on the live ISO: $c"
            return 1
        }
    done
    if [[ $LIVE_TARGET == / ]] || ! mountpoint -q "$LIVE_TARGET"; then
        red "Mount the new root filesystem at $LIVE_TARGET first (and the ESP at $LIVE_TARGET/boot/efi on UEFI)."
        return 1
    fi
    LIVE_FIRMWARE="$(live_firmware)"
    LIVE_DISK="$(live_disk_of "$LIVE_TARGET" || true)"
    if [[ -z $LIVE_DISK ]]; then
        red "Could not find the disk under $LIVE_TARGET."
        return 1
    fi
    green "ok      target $LIVE_TARGET on $LIVE_DISK, $LIVE_FIRMWARE firmware"
    live_check_boot_layout || return 1
    if [[ -e $LIVE_TARGET/usr/bin/xbps-install ]]; then
        yellow "note    $LIVE_TARGET already holds a system; this run completes it (re-runs converge)"
    fi
}

# live_bootstrap — the base system into the target. The live ISO's xbps is
# updated first: an older xbps refuses a newer repository. The ISO's keys
# go into the target, so the first install there asks nothing.
live_bootstrap() {
    local pkgs
    mapfile -t pkgs < <(live_read_list "$PACKAGES_DIR/live/base.lst")
    [[ $LIVE_FIRMWARE == uefi ]] && mapfile -t -O "${#pkgs[@]}" pkgs < <(live_read_list "$PACKAGES_DIR/live/uefi.lst")
    blue "==> base system into $LIVE_TARGET: ${pkgs[*]}"
    live_run xbps-install -Syu -R "$LIVE_REPO" xbps
    live_run mkdir -p "$LIVE_TARGET/var/db/xbps/keys"
    live_run cp -a /var/db/xbps/keys/. "$LIVE_TARGET/var/db/xbps/keys/"
    live_run env XBPS_ARCH=x86_64 xbps-install -Sy -r "$LIVE_TARGET" -R "$LIVE_REPO" "${pkgs[@]}"
    live_ok "base system installed"
}
