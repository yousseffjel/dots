#!/usr/bin/env bash
# Install Void Linux onto a disk from the Void live ISO (scope J). Run as
# root on the live ISO, against a target root you have already partitioned
# and mounted. The disk picker and partitioning come in J-3, encryption in
# J-4.
#
#   xbps-install -Sy git && git clone <this repo> && cd dots
#   mount /dev/<root> /mnt   (UEFI also: mount the ESP at /mnt/boot/efi)
#   scripts/install-live.sh
#
# It asks its questions with dialog (hostname, user, passwords, timezone,
# keymap, locale), or reads them from --answers. Then it bootstraps
# base-system with `linux` and `linux-lts`, configures the system, and
# installs GRUB for whichever firmware the ISO booted with. The result
# boots to a tty login. Running install-void.sh in the new system before
# the reboot is J-2; until then, log in and run it there.
#
# It writes no dots manifest rows. It creates the operating system itself,
# which `dots uninstall` never removes. That manifest belongs to the
# install-void.sh run on top of it.
#
# usage: install-live.sh [--target DIR] [--answers FILE] [--dry-run]
#
#   --target DIR    the mounted new root (default /mnt).
#   --answers FILE  KEY=VALUE answers instead of dialog menus, for
#                   unattended runs. The keys are listed in
#                   install-live-answers.sh. Passwords are crypt hashes
#                   (openssl passwd -6), never plain text.
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
LIVE_TARGET=/mnt
ANSWERS=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --target)
            [[ $# -ge 2 ]] || {
                red "--target needs a directory"
                exit 1
            }
            LIVE_TARGET="$2"
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
            echo "usage: install-live.sh [--target DIR] [--answers FILE] [--dry-run]"
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
# shellcheck source=scripts/install-live-config.sh
source "$SCRIPT_DIR/install-live-config.sh"

# The plan, without a secret: what the answers say, plus where GRUB goes.
plan_text() {
    live_answers_summary
    printf '%-10s %s\n' target "$LIVE_TARGET on $LIVE_DISK" firmware "$LIVE_FIRMWARE" \
        kernels "linux (default), linux-lts (Advanced options)"
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

blue "==> plan"
plan_text
if [[ $LIVE_INTERACTIVE -eq 1 ]] && ! dialog --title "Install Void here?" --yesno "$(plan_text)" 18 72; then
    clear
    yellow "Cancelled. Nothing was written."
    exit 1
fi

live_bootstrap
live_configure_system
live_configure_accounts
live_configure_boot

if [[ $DRY_RUN -eq 1 ]]; then
    green "dry run complete: every check passed"
else
    green "Void is installed on $LIVE_DISK."
    # base-system has no git: the clone in the new system needs it first.
    blue "Next: umount -R $LIVE_TARGET && reboot, log in as $LIVE_USERNAME, run"
    blue "      sudo xbps-install -S git, clone this repo and run scripts/install-void.sh."
fi
