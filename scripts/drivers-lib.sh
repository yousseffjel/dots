#!/usr/bin/env bash
# `dots drivers` — install what THIS machine's hardware needs. SOURCED by
# drivers.sh (the command) and by install-pkg-repos.sh (the installer), never
# run alone. Assumes `set -euo pipefail`, DRY_RUN, SUDO, the red/green/yellow/
# blue helpers, global_fn.sh's manifest_* functions, a FAILED_EXTRA array and
# install-pkg-tiers.sh's read_pkg_list, pkg_installed, pkg_available and
# pkg_ensure (install-pkg.sh and drivers.sh both source that file; this one
# must not, or a re-source would reset the installer's failure arrays
# mid-run). pkg_ensure is how every driver package is installed: one helper,
# so "installed:" means the same thing everywhere.
#
# usage: source "$SCRIPT_DIR/drivers-lib.sh"; drivers_install
#
# Four parts, each in its own file to stay under the 250-line cap:
#   drivers-detect.sh    what is there (read-only, /sys and /proc), incl. chassis
#   drivers-gpu.sh       VA-API video decoding per GPU; NVIDIA is REPORT-ONLY
#   drivers-firmware.sh  firmware the kernel asked for, microcode, fwupd
#   drivers-laptop.sh    laptop only: packages/laptop.lst, the touchpad snippet
#
# The NVIDIA proprietary driver is never installed: a wrong branch or a
# kernel module that fails to build leaves the machine with no graphical
# session, and Secure Boot needs an interactive key enrolment at reboot. The
# user decided this on 2026-10-13 — see docs/HARDWARE.md.
#
# Manifest contract, the same one install-pkg-repos.sh keeps: a PACKAGE row
# only for a package this run installed, a SERVICE row only for a runit
# service this run linked. `dots uninstall` reverts exactly those and nothing
# that was already there. (The Fedora version also swapped packages and
# gated on RPM Fusion; Void's main repo needs neither.)

DRIVERS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=drivers-detect.sh
source "$DRIVERS_LIB_DIR/drivers-detect.sh"
# shellcheck source=drivers-gpu.sh
source "$DRIVERS_LIB_DIR/drivers-gpu.sh"
# shellcheck source=drivers-firmware.sh
source "$DRIVERS_LIB_DIR/drivers-firmware.sh"
# shellcheck source=sysfile-lib.sh
source "$DRIVERS_LIB_DIR/sysfile-lib.sh"
# shellcheck source=drivers-laptop.sh
source "$DRIVERS_LIB_DIR/drivers-laptop.sh"
# runit_enable, for the laptop's power-profiles-daemon.
# shellcheck source=install-services-runit.sh
source "$DRIVERS_LIB_DIR/install-services-runit.sh"

drivers_install() {
    local virt
    virt="$(drivers_virt)"
    blue "==> hardware drivers (${virt/none/bare metal})"
    drivers_laptop
    drivers_gpu
    drivers_firmware
    if [[ "$virt" == none || "$virt" == unknown ]]; then
        drivers_microcode
        drivers_fwupd
    else
        blue "  microcode and fwupd skipped — a virtual machine's firmware belongs to its host ($virt)"
    fi
}
