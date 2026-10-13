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
#   DOTS_SYSFS      /sys                         (tests/fixtures/sysfs/<case>)
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
