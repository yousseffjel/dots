#!/usr/bin/env bash
# Install Void Linux onto a disk from the Void live ISO (scope J). Run as
# root on the live ISO.
#
#   xbps-install -Sy git && git clone <this repo> && cd dots
#   scripts/install-live.sh
#
# It asks its questions with dialog (hostname, user, passwords, timezone,
# keymap, locale), or reads them from --answers. Then it asks which disk
# to erase and has you type that disk's name (install-live-disk.sh). It
# lays the disk out as GPT, optionally encrypts the root partition with
# LUKS2 (install-live-luks.sh), formats it and mounts it at /mnt
# (install-live-part.sh), and sets up zram plus a swapfile
# (install-live-swap.sh). With --target it skips all of that and installs
# onto a root you partitioned and mounted yourself. Then it bootstraps
# base-system with `linux` and `linux-lts`, configures the system, and
# installs GRUB for whichever firmware the ISO booted with. Last, it copies
# this repo into the new user's ~/dots and runs install-void.sh there as
# that user (install-live-dots.sh), unmounts the target and offers the
# reboot. The first boot lands on the ly login screen.
#
# It writes no dots manifest rows. It creates the operating system itself,
# which `dots uninstall` never removes. That manifest belongs to the
# install-void.sh run inside it.
#
# A failed run is re-run as it was: every step converges (rule 1).
#
# usage: install-live.sh [--target DIR] [--answers FILE] [--skip-dots]
#                        [--reboot] [--dry-run]
#
#   --target DIR    install onto the root already mounted at DIR (UEFI:
#                   the ESP at DIR/boot/efi too). No disk is erased, and
#                   no swapfile is made. Without it the chosen disk is
#                   erased and mounted at /mnt.
#   --answers FILE  KEY=VALUE answers instead of dialog menus, for
#                   unattended runs. docs/LIVE-INSTALL.md lists the
#                   keys; docs/live-answers.example is one. Passwords
#                   are crypt hashes (openssl passwd -6), never plain
#                   text. The disk to
#                   erase is named twice: DISK=/dev/vda and WIPE=/dev/vda.
#                   LUKS_PASSFILE=/root/pass encrypts / with the passphrase
#                   in that file (root's, mode 600).
#   --skip-dots     stop at a bootable tty system (J-1): no dots, no
#                   unmount. Log in and run install-void.sh yourself.
#   --reboot        reboot when done without asking (for unattended runs).
#   --dry-run       check everything and print every command, writing
#                   nothing. It does not need root, but it does need the
#                   live ISO.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGES_DIR="$DOTS_DIR/packages"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

DRY_RUN=0
LIVE_SKIP_DOTS=0
LIVE_REBOOT=0
LIVE_TARGET=/mnt
# 1: choose, erase and mount a disk; 0: --target, a root already mounted.
LIVE_DISK_MODE=1
ANSWERS=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --skip-dots) LIVE_SKIP_DOTS=1 ;;
        --reboot) LIVE_REBOOT=1 ;;
        --target)
            [[ $# -ge 2 ]] || {
                red "--target needs a directory"
                exit 1
            }
            LIVE_TARGET="$2"
            LIVE_DISK_MODE=0
            shift
            ;;
        --answers)
            [[ $# -ge 2 ]] || {
                red "--answers needs a file"
                exit 1
            }
            ANSWERS="$2"
            shift
            ;;
        -h | --help)
            # The header's usage block, from "# usage:" to the comment's end.
            sed -n '/^# usage:/,/^[^#]/{/^#/s/^# \{0,1\}//p}' "${BASH_SOURCE[0]}"
            exit 0
            ;;
        *)
            red "unknown argument: $1"
            exit 1
            ;;
    esac
    shift
done
LIVE_TARGET="$(realpath -m "$LIVE_TARGET")"
LIVE_INTERACTIVE=1
[[ -n $ANSWERS ]] && LIVE_INTERACTIVE=0

# shellcheck source=scripts/install-live-answers.sh
source "$SCRIPT_DIR/install-live-answers.sh"
# shellcheck source=scripts/install-live-base.sh
source "$SCRIPT_DIR/install-live-base.sh"
# shellcheck source=scripts/install-live-disk.sh
source "$SCRIPT_DIR/install-live-disk.sh"
# shellcheck source=scripts/install-live-part.sh
source "$SCRIPT_DIR/install-live-part.sh"
# shellcheck source=scripts/install-live-config.sh
source "$SCRIPT_DIR/install-live-config.sh"
# shellcheck source=scripts/install-live-swap.sh
source "$SCRIPT_DIR/install-live-swap.sh"
# shellcheck source=scripts/install-live-dots.sh
source "$SCRIPT_DIR/install-live-dots.sh"

# The plan, without a secret: what the answers say, plus where GRUB goes.
plan_text() {
    live_answers_summary
    if [[ $LIVE_DISK_MODE -eq 1 ]]; then
        local first="ESP 1 GiB"
        [[ $LIVE_FIRMWARE == uefi ]] || first="bios_grub 1 MiB"
        printf '%-10s %s\n' disk "$LIVE_DISK is ERASED: GPT, $first, /boot 1 GiB, / the rest" \
            target "$LIVE_TARGET" swap "zram (half of RAM, zstd), then a $(live_swap_mib "$LIVE_DISK_BYTES") MiB swapfile"
        live_luks_plan
    else
        printf '%-10s %s\n' target "$LIVE_TARGET on $LIVE_DISK, as mounted" swap "zram (half of RAM, zstd)"
    fi
    printf '%-10s %s\n' firmware "$LIVE_FIRMWARE" kernels "linux (default), linux-lts (Advanced options)"
    if [[ $LIVE_SKIP_DOTS -eq 0 ]]; then
        printf '%-10s %s\n' dots "~$LIVE_USERNAME/dots, install-void.sh as $LIVE_USERNAME"
    fi
    if [[ $LIVE_FIRMWARE == bios ]]; then
        printf '%-10s %s\n' grub "boot code written to $LIVE_DISK"
    else
        printf '%-10s %s\n' grub "EFI entry \"Void\" + EFI/BOOT/BOOTX64.EFI"
    fi
}

[[ $DRY_RUN -eq 1 ]] && yellow "dry run: nothing will be written"
blue "==> checks"
live_preflight || exit 1

if [[ $LIVE_INTERACTIVE -eq 0 ]]; then
    live_answers_load "$ANSWERS" || exit 1
    green "ok      answers read from $ANSWERS"
elif ! live_answers_dialog; then
    clear
    yellow "Cancelled. Nothing was written."
    exit 1
fi

if [[ $LIVE_DISK_MODE -eq 1 ]]; then
    live_disk_choose || exit 1
else
    live_disk_answers_unused || exit 1
fi
live_luks_choose || exit 1

blue "==> plan"
plan_text
if [[ $LIVE_INTERACTIVE -eq 1 ]] && ! dialog --title "Install Void here?" --yesno "$(plan_text)" 18 72; then
    clear
    yellow "Cancelled. Nothing was written."
    exit 1
fi

if [[ $LIVE_DISK_MODE -eq 1 ]]; then
    live_part_prepare
    live_swapfile_create
    if [[ $DRY_RUN -eq 0 ]]; then
        live_check_boot_layout || exit 1
    fi
fi
live_bootstrap
live_configure_system
live_swap_configure
live_configure_accounts
live_configure_boot

if [[ $LIVE_SKIP_DOTS -eq 0 ]]; then
    # Armed before the grant, so no exit path leaves the rule behind. INT
    # and TERM become exits, which run the EXIT trap: it stops everything
    # still running in the target first, then removes the rule.
    trap live_dots_cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    live_dots_install
fi
live_drop_empty_resolv

if [[ $DRY_RUN -eq 1 ]]; then
    [[ $LIVE_SKIP_DOTS -eq 0 ]] && live_dots_finish
    green "dry run complete: every check passed"
elif [[ $LIVE_SKIP_DOTS -eq 0 ]]; then
    green "Void and dots are installed on $LIVE_DISK."
    live_dots_finish
else
    green "Void is installed on $LIVE_DISK."
    # base-system has no git: the clone in the new system needs it first.
    blue "Next: umount -R $LIVE_TARGET && reboot, log in as $LIVE_USERNAME, run"
    blue "      sudo xbps-install -S git, clone this repo and run scripts/install-void.sh."
fi
