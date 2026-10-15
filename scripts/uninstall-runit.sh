#!/usr/bin/env bash
# Reverts the services stage's runit changes and the ly it built. Sourced by
# uninstall.sh, never standalone: assumes `set -euo pipefail`, DRY_RUN, SUDO,
# global_fn.sh (confirm, manifest_rows) and the colour helpers.
#
#   uninstall_services   SERVICE rows: unlink what dots enabled (ly, dbus,
#                        elogind, NetworkManager, bluetoothd). SERVICEOFF
#                        rows: re-link what dots disabled for them (dhcpcd,
#                        wpa_supplicant, tty2's getty), removing a down file
#                        only if dots created it. Unlinking first, re-linking
#                        second, so tty2 is never claimed by both.
#   uninstall_ly_build   LYBUILD rows: the files of the ly dots built, then
#                        their directories once empty. After the service is
#                        gone, so runsv is not left restarting a deleted
#                        binary.
#
# Everything takes effect at once (runsvdir notices a link within seconds):
# NetworkManager stops and dhcpcd takes the network back; on a box where dots
# enabled dbus, stopping it ends the graphical session, so run uninstall from
# a TTY and reboot after.

# shellcheck source=install-services-runit.sh
source "$(dirname "${BASH_SOURCE[0]}")/install-services-runit.sh"

uninstall_services() {
    blue "=== services ==="
    local on off row name down
    mapfile -t on < <(manifest_rows SERVICE | cut -f2 | sort -u)
    mapfile -t off < <(manifest_rows SERVICEOFF | cut -f2-)
    if [[ ${#on[@]} -eq 0 && ${#off[@]} -eq 0 ]]; then
        blue "  no SERVICE rows in manifest — nothing to change"
        return 0
    fi
    confirm "Disable ${#on[@]} service(s) dots enabled${on[*]:+ (${on[*]})} and re-enable ${#off[@]} it disabled?" || {
        yellow "  skipped services"
        return 0
    }
    for name in "${on[@]}"; do
        # -L too: a package uninstall_packages removed leaves a dangling link.
        if ! runit_enabled "$name"; then
            blue "  $name is not enabled — nothing to disable"
        elif [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would disable $name"
        elif "${SUDO[@]}" rm -f "$(runit_service)/$name"; then
            green "  disabled $name"
        else
            red "  failed to disable $name — run:  sudo rm $(runit_service)/$name"
        fi
    done
    for row in "${off[@]}"; do
        IFS=$'\t' read -r name down <<<"$row"
        uninstall_reenable "$name" "$down"
    done
}

# uninstall_reenable <name> <down> — undo one SERVICEOFF row.
uninstall_reenable() {
    local name="$1" down="$2"
    if runit_enabled "$name"; then
        blue "  $name is already enabled again"
        return 0
    fi
    if [[ ! -d "$(runit_sv)/$name" ]]; then
        blue "  $name is no longer installed — nothing to re-enable"
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would re-enable $name${down:+ (and remove its down file)}"
        return 0
    fi
    [[ "$down" == down ]] && "${SUDO[@]}" rm -f "$(runit_sv)/$name/down"
    if "${SUDO[@]}" ln -s "$(runit_sv)/$name" "$(runit_service)/"; then
        green "  re-enabled $name"
    else
        red "  failed to re-enable $name — run:  sudo ln -s $(runit_sv)/$name $(runit_service)/"
    fi
}

uninstall_ly_build() {
    blue "=== ly (built from source) ==="
    local paths p root="${DOTS_LY_ROOT:-}" d
    mapfile -t paths < <(manifest_rows LYBUILD | cut -f3 | sort -u)
    if [[ ${#paths[@]} -eq 0 ]]; then
        blue "  no LYBUILD rows in manifest — nothing to remove"
        return 0
    fi
    confirm "Remove the ${#paths[@]} file(s) of the ly dots built?" || {
        yellow "  kept ly"
        return 0
    }
    for p in "${paths[@]}"; do
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would remove $p"
        elif [[ -e "$root$p" || -L "$root$p" ]]; then
            "${SUDO[@]}" rm -f "$root$p" || red "  failed to remove $p"
        fi
    done
    [[ $DRY_RUN -eq 1 ]] && return 0
    # Deepest first; rmdir only removes what is empty, so a file the user
    # added (a custom session) keeps its directory.
    for d in /etc/ly/lang /etc/ly/custom-sessions /etc/ly /etc/sv/ly; do
        [[ -d "$root$d" ]] && "${SUDO[@]}" rmdir "$root$d" 2>/dev/null || true
    done
    green "  removed ly"
}
