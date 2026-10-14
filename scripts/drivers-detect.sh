#!/usr/bin/env bash
# What hardware is in this machine — the read-only half of `dots drivers`.
# SOURCED by drivers-lib.sh (and through it by doctor-drivers.sh), never run
# alone. Nothing here installs, prints in colour or needs root.
#
# Everything is read from /sys and /proc, not lspci: pciutils is declared in
# no packages/*.lst, and the kernel already exposes vendor, device and bound
# driver per PCI function. Each source has a test override, like
# DWM_NET_SYSFS in dwm-net:
#
#   DOTS_SYSFS      /sys      (tests build a fake tree; also covers dmi + power_supply)
#   DOTS_CPUINFO    /proc/cpuinfo
#   DOTS_PCI_IDS    /usr/share/hwdata/pci.ids    (names only; may be absent)
#   DOTS_VIRT       systemd-detect-virt's answer ("none" on bare metal)

#
# Each is read at CALL time, not when this file is sourced: a test that moves
# DOTS_SYSFS between cases must not keep reading the first tree — or, worse,
# the real /sys it saw before setting one.
drivers_sysfs() { echo "${DOTS_SYSFS:-/sys}"; }

# The 128-bit EFI global-variable GUID SecureBoot lives under.
DRIVERS_EFI_GLOBAL="8be4df61-93ca-11d2-aa0d-e7a2a1b7f2ab"

# drivers_gpus — one line per display controller (PCI class 0x03xxxx):
#   <slot> TAB <vendor> TAB <device> TAB <bound driver or "-">
# vendor/device are lowercase hex without 0x (8086, 1002, 10de, ...).
drivers_gpus() {
    local dev class vendor device driver
    for dev in "$(drivers_sysfs)"/bus/pci/devices/*; do
        [[ -r "$dev/class" ]] || continue
        class="$(<"$dev/class")"
        [[ "$class" == 0x03* ]] || continue
        vendor="$(<"$dev/vendor")"
        device="$(<"$dev/device")"
        driver=-
        [[ -L "$dev/driver" ]] && driver="$(basename "$(readlink "$dev/driver")")"
        printf '%s\t%s\t%s\t%s\n' "${dev##*/}" "${vendor#0x}" "${device#0x}" "$driver"
    done
}

# drivers_virtual_gpu <vendor> — true for an emulated display adapter:
# virtio, QXL, bochs/stdvga, VMware, VirtualBox, Hyper-V. The hypervisor
# decodes video, not the guest, so there is no driver to install.
drivers_virtual_gpu() {
    case "$1" in
        1af4 | 1b36 | 1234 | 15ad | 80ee | 1414) return 0 ;;
    esac
    return 1
}

# drivers_chassis_type — the SMBIOS chassis type number, or nothing.
drivers_chassis_type() {
    local f
    f="$(drivers_sysfs)/class/dmi/id/chassis_type"
    [[ -r "$f" ]] && tr -dc '0-9' <"$f"
    return 0
}

# drivers_system_battery — the first power_supply that powers THIS machine,
# or nothing. A wireless mouse or headset battery is a power_supply too, with
# type Battery, but the kernel marks it scope=Device; a laptop's own battery
# has no scope or scope=System.
drivers_system_battery() {
    local ps scope
    for ps in "$(drivers_sysfs)"/class/power_supply/*; do
        [[ "$(cat "$ps/type" 2>/dev/null || true)" == Battery ]] || continue
        scope="$(cat "$ps/scope" 2>/dev/null || true)"
        [[ "$scope" == Device ]] && continue
        echo "${ps##*/}"
        return 0
    done
    return 0
}

# drivers_is_vm — true inside a virtual machine (not a container: a container
# runs on real hardware, and its chassis is the host's). DOTS_VIRT, the test
# override drivers_virt reads too, counts as a VM unless it is none/unknown.
drivers_is_vm() {
    if [[ -n "${DOTS_VIRT:-}" ]]; then
        [[ "$DOTS_VIRT" != none && "$DOTS_VIRT" != unknown ]]
        return
    fi
    command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt --vm -q 2>/dev/null
}

# drivers_chassis — vm, laptop, desktop or unknown. vm first: a hypervisor
# can expose a fake battery or any chassis type, and a guest gets desktop
# behaviour either way (nothing laptop-only, picom on xrender). Laptop when
# the firmware says so (chassis types 8 Portable, 9 Laptop, 10 Notebook,
# 14 Sub Notebook, 31 Convertible, 32 Detachable) OR when a system battery
# exists, because some firmware reports a laptop as "Other" or "Desktop".
# unknown (bare metal reporting e.g. 1, "Other") gets the desktop behaviour
# everywhere: nothing laptop-only is installed on a guess.
drivers_chassis() {
    local type
    type="$(drivers_chassis_type)"
    if drivers_is_vm; then
        echo vm
    elif [[ " 8 9 10 14 31 32 " == *" $type "* || -n "$(drivers_system_battery)" ]]; then
        echo laptop
    elif [[ " 3 4 5 6 7 13 15 16 17 23 24 35 36 " == *" $type "* ]]; then
        echo desktop
    else
        echo unknown
    fi
}

# drivers_chassis_why — one line saying what drivers_chassis based it on.
drivers_chassis_why() {
    local type battery
    type="$(drivers_chassis_type)"
    battery="$(drivers_system_battery)"
    if drivers_is_vm; then
        printf '%s, chassis type %s\n' "$(drivers_virt)" "${type:-unreadable}"
        return 0
    fi
    printf 'chassis type %s%s\n' "${type:-unreadable}" "${battery:+, battery $battery}"
}

# drivers_cpu_vendor — intel, amd, or other.
drivers_cpu_vendor() {
    local id
    id="$(awk -F': *' '/^vendor_id/ {print $2; exit}' "${DOTS_CPUINFO:-/proc/cpuinfo}" 2>/dev/null || true)"
    case "$id" in
        GenuineIntel) echo intel ;;
        AuthenticAMD) echo amd ;;
        *) echo other ;;
    esac
}

# drivers_virt — "none" on bare metal, else the hypervisor's name. Microcode
# and firmware updates belong to the host, not the guest.
drivers_virt() {
    if [[ -n "${DOTS_VIRT:-}" ]]; then
        echo "$DOTS_VIRT"
    elif command -v systemd-detect-virt >/dev/null 2>&1; then
        # Exits 1 while printing "none" on bare metal — the text is the answer.
        systemd-detect-virt 2>/dev/null || true
    else
        echo unknown
    fi
}

# drivers_secure_boot — yes, no, or unknown (BIOS boot, or efivars unreadable).
# The variable's payload is 4 attribute bytes then one value byte.
drivers_secure_boot() {
    local var byte
    var="$(drivers_sysfs)/firmware/efi/efivars/SecureBoot-$DRIVERS_EFI_GLOBAL"
    if [[ ! -r "$var" ]]; then
        echo unknown
        return 0
    fi
    byte="$(od -An -tu1 -j4 -N1 "$var" 2>/dev/null | tr -d '[:space:]')"
    case "$byte" in
        1) echo yes ;;
        0) echo no ;;
        *) echo unknown ;;
    esac
}

# drivers_pci_name <vendor> <device> — "GA104 [GeForce RTX 3070]" from
# pci.ids, or nothing. Device lines are scoped to their vendor block, because
# the same device id means different hardware under different vendors.
drivers_pci_name() {
    local vendor="$1" device="$2" ids="${DOTS_PCI_IDS:-/usr/share/hwdata/pci.ids}"
    [[ -r "$ids" ]] || return 0
    awk -v v="$vendor" -v d="$device" '
        /^[0-9a-f]{4} / { inv = ($1 == v); next }
        inv && $0 ~ "^\t" d "  " { sub("^\t" d "  ", ""); print; exit }
    ' "$ids"
}

# drivers_intel_legacy <device> — true for Intel GPUs older than Broadwell
# (gen 4 to 7.5), which intel-media-driver (iHD) does not support and only
# libva-intel-driver (i965) decodes on. The id blocks come from the kernel's
# include/drm/intel/pciids.h (INTEL_I965G .. INTEL_HSW and INTEL_VLV). This
# list cannot drift: those generations are finished, and every id not in it
# — including any GPU released after this was written — gets iHD.
drivers_intel_legacy() {
    case "$1" in
        29[0-9a-f][0-9a-f] | 2a[0-9a-f][0-9a-f] | 2e[0-9a-f][0-9a-f]) return 0 ;; # 965 / G4x
        004[26]) return 0 ;;                                                      # Ironlake
        01[0-6][0-9a-f]) return 0 ;;                                              # Sandy/Ivy Bridge, Valleyview
        04[0-9a-f][0-9a-f] | 0a[0-2][0-9a-f] | 0c[0-9a-f][0-9a-f]) return 0 ;;    # Haswell
        0d[0-9a-f][0-9a-f] | 0f3[0-9a-f]) return 0 ;;                             # Haswell CRW, Bay Trail
    esac
    return 1
}

# drivers_nvidia_branch <vendor-name-from-pci.ids> — the RPM Fusion package
# suffix for this card's driver branch, read from the chip codename that
# pci.ids puts first ("GP104 [GeForce GTX 1080]" -> Pascal -> 580xx):
#   ""        current branch (Turing and newer)
#   -580xx    Maxwell, Pascal, Volta — the last branch that supports them
#   -470xx    Kepler
#   -390xx    Fermi
#   none      older than Fermi: RPM Fusion has no driver, nouveau only
#   unknown   no name, or a codename this table does not know
drivers_nvidia_branch() {
    local chip="${1%% *}"
    case "$chip" in
        TU* | GA* | AD* | GB* | GH*) echo "" ;;
        GM* | GP* | GV*) echo -580xx ;;
        GK*) echo -470xx ;;
        GF*) echo -390xx ;;
        G[0-9]* | GT[0-9]* | NV* | C[0-9]* | MCP*) echo none ;;
        *) echo unknown ;;
    esac
}
