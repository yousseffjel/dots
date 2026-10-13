#!/usr/bin/env bash
# Firmware, microcode and fwupd — part of `dots drivers`. SOURCED by
# drivers-lib.sh, never run alone; see that file for what it assumes.
#
# Fedora splits linux-firmware into per-vendor packages (iwlwifi-mvm-firmware,
# amd-gpu-firmware, realtek-firmware, ...), and a Server install does not
# carry all of them. Rather than keep a driver -> package table, which would
# drift with every kernel, ASK THE KERNEL: a driver that could not load its
# firmware logs exactly which file it wanted,
#
#   Direct firmware load for iwlwifi-so-a0-gf-a0-89.ucode failed with error -2
#
# and dnf knows which package ships that file. A driver that tries several
# versions in turn logs a failure for each newer one it does not find; those
# files exist in no package, so the lookup comes back empty and nothing is
# installed for them.

DRIVERS_FW_PATTERN='Direct firmware load for [^ ]* failed'

# drivers_kernel_log — this boot's kernel messages. Needs root or the
# systemd-journal group, hence SUDO. DOTS_KERNEL_LOG is the test override.
drivers_kernel_log() {
    if [[ -n "${DOTS_KERNEL_LOG:-}" ]]; then
        cat "$DOTS_KERNEL_LOG"
    else
        "${SUDO[@]}" journalctl -k -b -o cat --no-pager 2>/dev/null
    fi
}

# drivers_missing_firmware — one firmware path per line, de-duplicated.
# Returns 2 when the log could not be read at all (sudo refused, no journal):
# that must not read as "no firmware missing".
drivers_missing_firmware() {
    local log
    log="$(drivers_kernel_log)" || return 2
    # No `grep -q` and no pipefail trap here: grep exiting 1 on a clean boot
    # is the common case, not a failure.
    printf '%s\n' "$log" | grep -o "$DRIVERS_FW_PATTERN" \
        | sed 's/^Direct firmware load for //; s/ failed$//' | sort -u || true
}

# drivers_firmware_pkg <file> — the package that ships it, or nothing.
# Fedora compresses firmware (.xz/.zst), hence the trailing glob. Returns 1
# when dnf itself failed (offline, no metadata): "no package ships it" and
# "could not ask" must not look the same.
drivers_firmware_pkg() {
    local out
    out="$(dnf repoquery --quiet --queryformat '%{name}\n' \
        --whatprovides "/usr/lib/firmware/$1*" 2>/dev/null)" || return 1
    printf '%s\n' "${out%%$'\n'*}"
}

drivers_firmware() {
    local file pkg missing found=0
    blue "  firmware the kernel asked for this boot:"
    if ! missing="$(drivers_missing_firmware)"; then
        yellow "  could not read this boot's kernel log (journalctl -k needs sudo) — firmware not checked"
        return 0
    fi
    if [[ -z "$missing" ]]; then
        green "  ok      no failed firmware loads in this boot's kernel log"
        return 0
    fi
    while IFS= read -r file; do
        if ! pkg="$(drivers_firmware_pkg "$file")"; then
            yellow "  could not look up $file (dnf repoquery failed) — not checked"
            found=1
            continue
        fi
        [[ -n "$pkg" ]] || continue
        found=1
        drivers_pkg "$pkg" "$file stays missing: the device it belongs to may not work" || true
    done <<<"$missing"
    if [[ $found -eq 0 ]]; then
        green "  ok      $(wc -l <<<"$missing") failed load(s), none shipped by any package (driver fallbacks)"
    fi
}

drivers_microcode() {
    case "$(drivers_cpu_vendor)" in
        intel) drivers_pkg microcode_ctl "Intel CPU errata and security fixes are not applied at boot" || true ;;
        amd) drivers_pkg amd-ucode-firmware "AMD CPU errata and security fixes are not applied at boot" || true ;;
        *) blue "  CPU vendor not Intel or AMD — no microcode package" ;;
    esac
}

# Installs the daemon only. Flashing firmware is never automatic: it can
# brick a device on power loss, so `dots doctor` reports pending updates and
# the user runs `fwupdmgr update` themselves.
drivers_fwupd() {
    drivers_pkg fwupd "no firmware updates for this machine (UEFI, SSD, dock, ...)" || true
}
