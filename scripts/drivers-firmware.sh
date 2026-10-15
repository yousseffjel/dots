#!/usr/bin/env bash
# Firmware, microcode and fwupd — part of `dots drivers`. SOURCED by
# drivers-lib.sh, never run alone; see that file for what it assumes.
#
# Void splits linux-firmware into per-vendor packages (linux-firmware-intel,
# -network, -nvidia, -broadcom, ...), and the `linux-firmware` meta pulls in
# only some of them. Rather than keep a driver -> package table, which would
# drift with every kernel, ASK THE KERNEL: a driver that could not load its
# firmware logs exactly which file it wanted,
#
#   Direct firmware load for iwlwifi-so-a0-gf-a0-89.ucode failed with error -2
#
# and the firmware packages' file lists say which one ships it
# (`xbps-query -Rf`, ~1 s per package, probed 2026-10-15). A driver that tries
# several versions in turn logs a failure for each newer one it does not
# find; those files are in no package, so nothing is installed for them.

DRIVERS_FW_PATTERN='Direct firmware load for [^ ]* failed'

# drivers_kernel_log — this boot's kernel messages. Void has no journal;
# dmesg reads the ring buffer, which needs root where dmesg_restrict is set,
# hence SUDO. DOTS_KERNEL_LOG is the test override.
drivers_kernel_log() {
    if [[ -n "${DOTS_KERNEL_LOG:-}" ]]; then
        cat "$DOTS_KERNEL_LOG"
    else
        "${SUDO[@]}" dmesg 2>/dev/null
    fi
}

# drivers_missing_firmware — one firmware path per line, de-duplicated.
# Returns 2 when the log could not be read at all (sudo refused): that must
# not read as "no firmware missing".
drivers_missing_firmware() {
    local log
    log="$(drivers_kernel_log)" || return 2
    # No `grep -q` and no pipefail trap here: grep exiting 1 on a clean boot
    # is the common case, not a failure.
    printf '%s\n' "$log" | grep -o "$DRIVERS_FW_PATTERN" \
        | sed 's/^Direct firmware load for //; s/ failed$//' | sort -u || true
}

# drivers_firmware_index <out> — "<package> <path>" for every file of every
# linux-firmware* package, written to <out>. Called once, in the parent shell,
# before the lookups (which run in $(...) subshells and could not keep it).
# Returns 1 when xbps could not list them (offline, no synced index).
drivers_firmware_index() {
    local out="$1" pkgs pkg
    pkgs="$(xbps-query -Rs linux-firmware 2>/dev/null)" || return 1
    : >"$out"
    while read -r _ pkg _; do
        pkg="${pkg%-*}"
        [[ "$pkg" == linux-firmware* ]] || continue
        xbps-query -Rf "$pkg" 2>/dev/null | sed "s|^|$pkg |" >>"$out" || return 1
    done <<<"$pkgs"
}

# drivers_firmware_pkg <file> <index> — the package that ships it, or
# nothing. The kernel names a file relative to /usr/lib/firmware (maybe with a
# directory, "amdgpu/x.bin"); Void stores it compressed (.zst) and sometimes
# under a vendor directory with a link at the old path, so the match is on the
# path's end, compression suffix optional.
drivers_firmware_pkg() {
    local want="$1" pkg path
    while read -r pkg path; do
        case "$path" in
            */"$want" | */"$want".zst | */"$want".xz)
                echo "$pkg"
                return 0
                ;;
        esac
    done <"$2"
}

drivers_firmware() {
    local file pkg missing found=0 index
    blue "  firmware the kernel asked for this boot:"
    if ! missing="$(drivers_missing_firmware)"; then
        yellow "  could not read this boot's kernel log (dmesg needs sudo) — firmware not checked"
        return 0
    fi
    if [[ -z "$missing" ]]; then
        green "  ok      no failed firmware loads in this boot's kernel log"
        return 0
    fi
    index="$(mktemp)"
    if ! drivers_firmware_index "$index"; then
        rm -f "$index"
        yellow "  could not list the firmware packages (xbps-query -Rf failed) — $(wc -l <<<"$missing") missing file(s) not checked"
        return 0
    fi
    while IFS= read -r file; do
        pkg="$(drivers_firmware_pkg "$file" "$index")"
        [[ -n "$pkg" ]] || continue
        found=1
        pkg_ensure "$pkg" "$file stays missing: the device it belongs to may not work" || true
    done <<<"$missing"
    rm -f "$index"
    if [[ $found -eq 0 ]]; then
        green "  ok      $(wc -l <<<"$missing") failed load(s), none shipped by any package (driver fallbacks)"
    fi
}

# drivers_microcode — the CPU's microcode, loaded early from the initramfs,
# which is rebuilt when this run installed it (the handbook's step;
# intel-ucode adds dracut's early_microcode=yes itself). intel-ucode is in
# nonfree, which the repos step enabled just before; AMD's is in
# linux-firmware-amd, in main.
drivers_microcode() {
    local pkg cost="CPU errata and security fixes are not applied at boot"
    case "$(drivers_cpu_vendor)" in
        intel) pkg=intel-ucode ;;
        amd) pkg=linux-firmware-amd ;;
        *)
            blue "  CPU vendor not Intel or AMD — no microcode package"
            return 0
            ;;
    esac
    if pkg_installed "$pkg"; then
        green "  ok      $pkg already installed"
        return 0
    fi
    if [[ $DRY_RUN -eq 0 ]] && ! pkg_available "$pkg"; then
        yellow "  skipped — $pkg is not in an enabled repo (intel-ucode needs void-repo-nonfree)"
        FAILED_EXTRA+=("$pkg")
        return 0
    fi
    pkg_ensure "$pkg" "$cost" || return 0
    [[ $DRY_RUN -eq 1 ]] && return 0
    drivers_initramfs
}

# drivers_initramfs — rebuild the running kernel's initramfs, so early
# microcode is in it. The kernel package is linuxX.Y (Void's naming).
drivers_initramfs() {
    local kpkg
    kpkg="linux$(uname -r | cut -d. -f1,2)"
    if "${SUDO[@]}" xbps-reconfigure -f "$kpkg" >/dev/null 2>&1 </dev/null; then
        green "  rebuilt the initramfs ($kpkg) — microcode loads from the next boot"
    else
        yellow "  could not rebuild the initramfs — run:  sudo xbps-reconfigure -f $kpkg"
    fi
}

# Installs the daemon only. Flashing firmware is never automatic: it can
# brick a device on power loss, so `dots doctor` reports pending updates and
# the user runs `fwupdmgr update` themselves.
drivers_fwupd() {
    pkg_ensure fwupd "no firmware updates for this machine (UEFI, SSD, dock, ...)" || true
}
