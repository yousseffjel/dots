#!/usr/bin/env bash
# The hardware-driver checks of scripts/doctor.sh — SOURCED by it, never run
# alone. Assumes doctor.sh's report() and `set -euo pipefail`.
#
# Read-only, like all of doctor: no sudo, no dnf install. It asks the same
# questions `dots drivers` acts on — read from the same drivers-detect.sh —
# and points at that command for every fix.

# shellcheck source=drivers-detect.sh
source "$(dirname "${BASH_SOURCE[0]}")/drivers-detect.sh"
# For DRIVERS_TOUCHPAD_REL; its functions are defined here, never called.
# shellcheck source=drivers-laptop.sh
source "$(dirname "${BASH_SOURCE[0]}")/drivers-laptop.sh"

doctor_has_pkg() { rpm -q "$1" >/dev/null 2>&1; }

check_drivers() {
    local s=drivers
    if ! command -v rpm >/dev/null 2>&1; then
        report skip "$s" rpm "rpm not found — not a Fedora system"
        return 0
    fi
    report ok "$s" chassis "$(drivers_chassis) ($(drivers_chassis_why))"
    if [[ "$(drivers_chassis)" == laptop ]]; then
        check_drivers_touchpad
        check_drivers_power
    fi
    check_drivers_gpu
    if [[ "$(drivers_virt)" =~ ^(none|unknown)$ ]]; then
        check_drivers_microcode
        check_drivers_fwupd
    else
        report skip "$s" firmware-host "virtual machine: microcode and firmware updates belong to the host"
    fi
}

check_drivers_gpu() {
    local s=drivers slot vendor device driver want
    while IFS=$'\t' read -r slot vendor device driver; do
        [[ -n "$slot" ]] || continue
        case "$vendor" in
            8086)
                want=intel-media-driver
                drivers_intel_legacy "$device" && want=libva-intel-driver
                ;;
            1002) want=mesa-va-drivers-freeworld ;;
            10de)
                check_drivers_nvidia "$slot" "$device" "$driver"
                continue
                ;;
            *)
                if drivers_virtual_gpu "$vendor"; then
                    report ok "$s" "video-$slot" "GPU $slot ($vendor:$device) is virtual: the host decodes video, no driver needed"
                else
                    report skip "$s" "video-$slot" "GPU $slot ($vendor:$device): vendor not recognised, no video driver checked"
                fi
                continue
                ;;
        esac
        if doctor_has_pkg "$want"; then
            report ok "$s" "video-$slot" "GPU $slot ($vendor:$device): $want installed"
        else
            report warn "$s" "video-$slot" "GPU $slot ($vendor:$device): $want missing, video decodes on the CPU — dots drivers"
        fi
    done <<<"$(drivers_gpus)"
}

check_drivers_nvidia() {
    local s=drivers slot="$1" device="$2" driver="$3"
    if [[ "$driver" != nvidia ]]; then
        report warn "$s" "nvidia-$slot" "NVIDIA GPU $slot runs '$driver', not the NVIDIA driver — dots drivers prints how to install it"
    elif doctor_has_pkg libva-nvidia-driver; then
        report ok "$s" "nvidia-$slot" "NVIDIA GPU $slot: proprietary driver and libva-nvidia-driver"
    else
        report warn "$s" "nvidia-$slot" "NVIDIA GPU $slot: libva-nvidia-driver missing, video decodes on the CPU — dots drivers"
    fi
}

check_drivers_microcode() {
    local s=drivers want
    case "$(drivers_cpu_vendor)" in
        intel) want=microcode_ctl ;;
        amd) want=amd-ucode-firmware ;;
        *) return 0 ;;
    esac
    if doctor_has_pkg "$want"; then
        report ok "$s" microcode "CPU microcode ($want) installed"
    else
        report warn "$s" microcode "$want missing: CPU errata fixes are not loaded at boot — dots drivers"
    fi
}

# Only reports. `fwupdmgr update` flashes firmware and is never run for the
# user. Offline and non-interactive: cached metadata only, no prompts.
check_drivers_fwupd() {
    local s=drivers rc=0 out
    if ! doctor_has_pkg fwupd; then
        report warn "$s" fwupd "fwupd missing: no firmware updates for this machine — dots drivers"
        return 0
    fi
    out="$(fwupdmgr get-updates --no-unreported-check --no-metadata-check </dev/null 2>&1)" || rc=$?
    case "$rc" in
        0) report warn "$s" fwupd "firmware updates are available — fwupdmgr update" ;;
        2) report ok "$s" fwupd "no firmware updates pending (as of the last fwupdmgr refresh)" ;;
        *) report skip "$s" fwupd "fwupdmgr get-updates failed: $(tail -n1 <<<"$out")" ;;
    esac
}

# On a laptop: the Xorg snippet drivers-laptop.sh installs. An edited copy is
# the user's choice, so it is ok, not a warning.
# shellcheck disable=SC2153 # DOTS_DIR is doctor.sh's, which sources this
check_drivers_touchpad() {
    local s=drivers dst
    dst="${DOTS_XORG_CONF_DIR:-/etc/X11/xorg.conf.d}/${DRIVERS_TOUCHPAD_REL##*/}"
    if [[ ! -e "$dst" ]]; then
        report warn "$s" touchpad "no $dst: no tap-to-click or two-finger right-click — dots drivers"
    elif cmp -s "$DOTS_DIR/$DRIVERS_TOUCHPAD_REL" "$dst"; then
        report ok "$s" touchpad "touchpad settings installed ($dst)"
    else
        report ok "$s" touchpad "touchpad settings installed, edited by you ($dst)"
    fi
}

# On a laptop: tuned must be enabled, or the profile dwm-power picks is lost
# at reboot. A missing tuned-ppd is already the packages section's warning.
check_drivers_power() {
    local s=drivers state
    state="$(systemctl is-enabled tuned.service 2>/dev/null || true)"
    if [[ "$state" == enabled ]]; then
        report ok "$s" power "tuned.service is enabled: the power profile survives a reboot"
    else
        report warn "$s" power "tuned.service is ${state:-not installed}: the power profile resets at reboot — dots drivers"
    fi
}
