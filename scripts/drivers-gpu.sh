#!/usr/bin/env bash
# VA-API hardware video decoding, per GPU — part of `dots drivers`. SOURCED by
# drivers-lib.sh, never run alone; see that file for what it assumes.
#
# Fedora's own mesa and ffmpeg-free leave out the patent-encumbered codecs,
# so mpv decodes HEVC/H.264 on the CPU unless the GPU's VA-API driver comes
# from RPM Fusion:
#
#   Intel  Broadwell+  intel-media-driver (iHD)      RPM Fusion nonfree
#          older       libva-intel-driver (i965)     RPM Fusion free
#   AMD                mesa-va-drivers-freeworld     RPM Fusion free
#   NVIDIA             REPORTED, never installed — see drivers-lib.sh
#
# AMD differs by release. Up to f43 Fedora ships a separate mesa-va-drivers,
# which is swapped for the freeworld build (a REPO swap row, reverted by
# uninstall). From f44 mesa-dri-drivers carries the VA drivers itself and
# Obsoletes mesa-va-drivers, so there is nothing to swap out: the freeworld
# package installs beside it under /usr/lib64/dri-freeworld, with an
# ld.so.conf.d entry that puts it first. Checked against the f44 rpm's
# Provides/Obsoletes/file list on 2026-10-13.

# PCI vendor ids of emulated display adapters: virtio, QXL, bochs/stdvga,
# VMware, VirtualBox, Hyper-V. The hypervisor decodes video, not the guest.
DRIVERS_VIRTUAL_GPU_VENDORS=" 1af4 1b36 1234 15ad 80ee 1414 "

drivers_gpu() {
    local slot vendor device driver gpus
    gpus="$(drivers_gpus)"
    if [[ -z "$gpus" ]]; then
        yellow "  no display controller found under $(drivers_sysfs)/bus/pci — nothing to do for video"
        return 0
    fi
    while IFS=$'\t' read -r slot vendor device driver; do
        case "$vendor" in
            8086) drivers_gpu_intel "$device" ;;
            1002) drivers_gpu_amd ;;
            10de) drivers_nvidia_report "$slot" "$device" "$driver" ;;
            *)
                if [[ "$DRIVERS_VIRTUAL_GPU_VENDORS" == *" $vendor "* ]]; then
                    blue "  $slot: virtual GPU ($vendor:$device) — no video driver to install"
                else
                    yellow "  $slot: unrecognised GPU vendor $vendor:$device — no video driver chosen"
                fi
                ;;
        esac
    done <<<"$gpus"
}

drivers_gpu_intel() {
    local device="$1"
    if drivers_intel_legacy "$device"; then
        blue "  Intel GPU $device (pre-Broadwell): libva-intel-driver"
        drivers_have_rpmfusion free || return 0
        drivers_pkg libva-intel-driver "no VA-API decoding on this Intel GPU: mpv decodes on the CPU" || true
    else
        blue "  Intel GPU $device: intel-media-driver"
        drivers_have_rpmfusion nonfree || return 0
        drivers_pkg intel-media-driver "no VA-API decoding on Intel: mpv decodes HEVC on the CPU" || true
    fi
}

drivers_gpu_amd() {
    local cost="no HEVC/H.264 VA-API decoding on AMD: mpv decodes on the CPU"
    blue "  AMD GPU: mesa-va-drivers-freeworld"
    drivers_have_rpmfusion free || return 0
    if rpm -q mesa-va-drivers-freeworld >/dev/null 2>&1; then
        green "  ok      mesa-va-drivers-freeworld already installed"
    elif rpm -q mesa-va-drivers >/dev/null 2>&1; then
        drivers_swap mesa-va-drivers mesa-va-drivers-freeworld "$cost" || true
    else
        drivers_pkg mesa-va-drivers-freeworld "$cost" || true
    fi
}

# drivers_nvidia_report <slot> <device> <bound driver> — says what to run;
# runs nothing.
drivers_nvidia_report() {
    local slot="$1" device="$2" driver="$3" name branch
    name="$(drivers_pci_name 10de "$device")"
    branch="$(drivers_nvidia_branch "$name")"
    yellow "  NVIDIA GPU $slot: ${name:-device 10de:$device} (kernel driver: $driver)"
    if [[ "$driver" == nvidia ]]; then
        green "  ok      the proprietary driver is loaded"
        drivers_pkg libva-nvidia-driver "no VA-API decoding on NVIDIA: mpv decodes on the CPU" || true
        return 0
    fi
    case "$branch" in
        none)
            yellow "    older than Fermi: RPM Fusion has no driver for it — nouveau is the only option"
            return 0
            ;;
        unknown)
            yellow "    driver branch not recognised — pick one at https://rpmfusion.org/Howto/NVIDIA"
            return 0
            ;;
    esac
    yellow "    not installed by dots (a failed kernel module means no desktop). To install it:"
    yellow "      sudo dnf install akmod-nvidia$branch xorg-x11-drv-nvidia$branch-cuda"
    yellow "      wait until 'modinfo -F version nvidia' prints a version, then reboot"
    if [[ "$(drivers_secure_boot)" == yes ]]; then
        yellow "    Secure Boot is ON — the module must be signed, BEFORE that reboot:"
        yellow "      sudo kmodgenca -a && sudo mokutil --import /etc/pki/akmods/certs/public_key.der"
        yellow "      then choose 'Enroll MOK' on the blue screen at the next boot"
    fi
    yellow "    then re-run 'dots drivers' to add libva-nvidia-driver (video decoding)."
    yellow "    Guide: https://rpmfusion.org/Howto/NVIDIA"
}
