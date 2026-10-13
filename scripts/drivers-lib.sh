#!/usr/bin/env bash
# `dots drivers` — install what THIS machine's hardware needs. SOURCED by
# drivers.sh (the command) and by install-pkg-repos.sh (the installer), never
# run alone. Assumes `set -euo pipefail`, DRY_RUN, SUDO, the red/green/yellow/
# blue helpers, global_fn.sh's manifest_* functions and a FAILED_EXTRA array.
#
# usage: source "$SCRIPT_DIR/drivers-lib.sh"; drivers_install
#
# Four parts, each in its own file to stay under the 250-line cap:
#   drivers-detect.sh    what is there (read-only, /sys and /proc)
#   drivers-gpu.sh       VA-API video decoding per GPU; NVIDIA is REPORT-ONLY
#   drivers-firmware.sh  firmware the kernel asked for, microcode, fwupd
#
# The NVIDIA proprietary driver is never installed: a wrong branch or a
# kernel module that fails to build leaves the machine with no graphical
# session, and Secure Boot needs an interactive key enrolment at reboot. The
# user decided this on 2026-10-13 — see docs/HARDWARE.md.
#
# Manifest contract, the same one install-pkg-repos.sh keeps: a PACKAGE row
# only for a package this run installed, a REPO swap row only for a swap this
# run made. `dots uninstall` reverts exactly those (uninstall.sh's package
# step, uninstall-repos.sh's swap step) and nothing that was already there.

DRIVERS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=drivers-detect.sh
source "$DRIVERS_LIB_DIR/drivers-detect.sh"
# shellcheck source=drivers-gpu.sh
source "$DRIVERS_LIB_DIR/drivers-gpu.sh"
# shellcheck source=drivers-firmware.sh
source "$DRIVERS_LIB_DIR/drivers-firmware.sh"

# drivers_pkg <pkg> <what its absence costs> — install one package unless it
# is already there. A failure goes to the yellow tier of the closing summary.
# DECISION: not install-pkg-repos.sh's repos_install_pkg — `dots drivers`
# runs standalone, where that file (and its repo-adding side effects) is not
# loaded, and this one must honour --dry-run and skip installed packages.
drivers_pkg() {
    local pkg="$1" cost="$2" err
    if rpm -q "$pkg" >/dev/null 2>&1; then
        green "  ok      $pkg already installed"
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would install $pkg"
        return 0
    fi
    if err="$("${SUDO[@]}" dnf install -y "$pkg" 2>&1 >/dev/null)"; then
        green "  installed: $pkg"
        manifest_append_row PACKAGE "$pkg"
        return 0
    fi
    yellow "  FAILED: $pkg — $cost"
    [[ -n "$err" ]] && yellow "    dnf: $(printf '%s' "$err" | tail -n1)"
    FAILED_EXTRA+=("$pkg")
    return 1
}

# drivers_swap <from> <to> <cost> — `dnf swap`, recorded as a REPO swap row
# so uninstall-repos.sh swaps it back, exactly like ffmpeg-free -> ffmpeg.
drivers_swap() {
    local from="$1" to="$2" cost="$3"
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would run: dnf swap $from $to --allowerasing"
        return 0
    fi
    if "${SUDO[@]}" dnf swap -y "$from" "$to" --allowerasing >/dev/null 2>&1; then
        manifest_append_row REPO swap "$from" "$to"
        green "  swapped $from -> $to"
        return 0
    fi
    yellow "  FAILED: dnf swap $from $to — $cost"
    FAILED_EXTRA+=("$to")
    return 1
}

# drivers_have_rpmfusion <flavour> — the video drivers come from RPM Fusion,
# which only the installer may enable (CLAUDE.md rule 4's authorised
# exception). `dots drivers` on its own never adds a repository. The
# installer's dry run sets DRIVERS_ASSUME_RPMFUSION=1: it would have added it.
drivers_have_rpmfusion() {
    [[ "${DRIVERS_ASSUME_RPMFUSION:-0}" == 1 ]] && return 0
    rpm -q "rpmfusion-$1-release" >/dev/null 2>&1 && return 0
    yellow "  skipped — RPM Fusion $1 is not enabled; scripts/install-fedora.sh --only-install enables it"
    return 1
}

drivers_install() {
    local virt
    virt="$(drivers_virt)"
    blue "==> hardware drivers (${virt/none/bare metal})"
    drivers_gpu
    drivers_firmware
    if [[ "$virt" == none || "$virt" == unknown ]]; then
        drivers_microcode
        drivers_fwupd
    else
        blue "  microcode and fwupd skipped — a virtual machine's firmware belongs to its host ($virt)"
    fi
}
