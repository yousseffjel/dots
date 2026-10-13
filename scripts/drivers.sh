#!/usr/bin/env bash
# `dots drivers`: detect this machine's hardware and install what it needs —
# VA-API video decoding for Intel/AMD GPUs, firmware the kernel failed to
# load, CPU microcode and fwupd. An NVIDIA GPU is identified and the exact
# commands for its driver branch are printed; the proprietary driver is never
# installed. The installer runs the same code (install-pkg-repos.sh), so this
# is for after a hardware change, or to see what would happen.
#
# Re-runnable: installed packages are skipped. Every package and swap this
# run makes is recorded in the install manifest, so `dots uninstall`
# reverts it. Never enables a repository — that stays the installer's job.
#
# usage: drivers.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/global_fn.sh"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

usage() {
    echo "usage: ${DOTS_CMD:-drivers.sh} [--dry-run]"
    echo
    echo "Detects GPUs, CPU and missing firmware, and installs the matching"
    echo "packages from Fedora and RPM Fusion. NVIDIA: reported, not installed."
    echo "--dry-run: detect and print, change nothing."
}

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            red "unknown argument: $arg"
            usage >&2
            exit 1
            ;;
    esac
done

if ! command -v dnf >/dev/null 2>&1; then
    red "dnf not found — this command targets Fedora."
    exit 1
fi

SUDO=()
if [[ $EUID -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        red "sudo not found and not running as root."
        exit 1
    fi
    SUDO=(sudo)
fi

FAILED_EXTRA=()
# shellcheck source=drivers-lib.sh
source "$SCRIPT_DIR/drivers-lib.sh"
drivers_install

if [[ ${#FAILED_EXTRA[@]} -gt 0 ]]; then
    yellow "not installed: ${FAILED_EXTRA[*]}"
    exit 1
fi
green "✓ drivers done"
