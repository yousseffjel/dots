#!/usr/bin/env bash
# VA-API hardware video decoding, per GPU — part of `dots drivers`. SOURCED by
# drivers-lib.sh, never run alone; see that file for what it assumes.
#
# On Void every decoding driver is in the main repo, built with every codec
# (mesa's template sets -Dvideo-codecs=all; checked 2026-10-15), so there is
# no repository to gate on and nothing to swap:
#
#   Intel  Broadwell+  intel-media-driver (iHD) + mesa-vulkan-intel (ANV)
#          older       libva-intel-driver (i965)
#   AMD                mesa-vaapi (radeonsi's VA-API driver) + mesa-vulkan-radeon (RADV)
#   NVIDIA             REPORTED, never installed — see drivers-lib.sh
#
# (Fedora needed RPM Fusion for all three, and a mesa-va-drivers swap on AMD.)
#
# The Vulkan driver is the GPU's ICD for vulkan-loader, which mpv pulls in:
# without one, mpv's gpu-next (libplacebo) cannot start on Vulkan and falls
# back to OpenGL. Found missing on an AMD HawkPoint laptop (2026-10-28), where
# only virtio's ICD was installed. Pre-Broadwell Intel gets none: ANV starts at
# Broadwell, and the older parts' hasvk driver is incomplete.

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
            1002)
                blue "  AMD GPU: mesa-vaapi, mesa-vulkan-radeon"
                pkg_ensure mesa-vaapi "no VA-API decoding on AMD: mpv decodes HEVC on the CPU" || true
                pkg_ensure mesa-vulkan-radeon "no Vulkan on AMD: mpv renders through OpenGL" || true
                ;;
            10de) drivers_nvidia_report "$slot" "$device" "$driver" ;;
            *)
                if drivers_virtual_gpu "$vendor"; then
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
        pkg_ensure libva-intel-driver "no VA-API decoding on this Intel GPU: mpv decodes on the CPU" || true
    else
        blue "  Intel GPU $device: intel-media-driver, mesa-vulkan-intel"
        pkg_ensure intel-media-driver "no VA-API decoding on Intel: mpv decodes HEVC on the CPU" || true
        pkg_ensure mesa-vulkan-intel "no Vulkan on Intel: mpv renders through OpenGL" || true
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
        pkg_ensure nvidia-vaapi-driver "no VA-API decoding on NVIDIA: mpv decodes on the CPU" || true
        return 0
    fi
    case "$branch" in
        none)
            yellow "    older than Fermi: no proprietary driver supports it — nouveau is the only option"
            return 0
            ;;
        unknown)
            yellow "    driver branch not recognised — pick one in the Void handbook's NVIDIA page"
            return 0
            ;;
    esac
    yellow "    not installed by dots (a failed kernel module means no desktop). To install it:"
    yellow "      sudo xbps-install -S void-repo-nonfree && sudo xbps-install -S $branch"
    yellow "      (DKMS builds the module for the running kernel), then reboot"
    if [[ "$(drivers_secure_boot)" == yes ]]; then
        yellow "    Secure Boot is ON — an unsigned DKMS module will not load. Sign it or turn"
        yellow "      Secure Boot off first; the Void handbook's NVIDIA page covers both."
    fi
    yellow "    then re-run 'dots drivers' to add nvidia-vaapi-driver (video decoding)."
    yellow "    Guide: https://docs.voidlinux.org/config/graphical-session/graphics-drivers/nvidia.html"
}
