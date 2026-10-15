#!/usr/bin/env bash
# runit service helpers for the services stage. Sourced by
# install-services.sh and uninstall-runit.sh, never standalone: assumes
# `set -euo pipefail`, DRY_RUN, SUDO, global_fn.sh (manifest_*) and the
# colour helpers.
#
# On Void a service is enabled by linking /etc/sv/<name> into /var/service/,
# and runsvdir starts it within seconds; removing the link stops it. A
# service stays installed but disabled while /var/service/<name> is absent,
# and an `/etc/sv/<name>/down` file keeps a linked one from starting (the
# handbook's way of freeing a getty's TTY).
#
# Manifest rows, each written only by the run that made the change, so a
# re-run appends nothing and uninstall reverts exactly what dots did:
#   SERVICE     <name>          we linked it into /var/service
#   SERVICEOFF  <name> [down]   we unlinked it (and created its down file)
#
# Both directories are overridable for tests (DOTS_RUNIT_SV, DOTS_RUNIT_SERVICE),
# resolved at call time, not source time.

runit_sv() { printf '%s\n' "${DOTS_RUNIT_SV:-/etc/sv}"; }
runit_service() { printf '%s\n' "${DOTS_RUNIT_SERVICE:-/var/service}"; }

# The services the desktop needs (scope I, decision D2). Order matters: dbus
# first, since elogind's and NetworkManager's run scripts exit until
# `sv check dbus` passes. polkit and udisks are D-Bus activated (their .service
# files ship in /usr/share/dbus-1/system-services), so they are not here.
DESKTOP_SERVICES=(dbus elogind NetworkManager bluetoothd)
# What NetworkManager replaces. The handbook: disable them before enabling it,
# or they fight over the interfaces.
NM_CONFLICTS=(dhcpcd wpa_supplicant)

# drivers_is_vm, for the VM-only guest agent below.
# shellcheck source=drivers-detect.sh
source "$(dirname "${BASH_SOURCE[0]}")/drivers-detect.sh"

runit_enabled() { [[ -e "$(runit_service)/$1" || -L "$(runit_service)/$1" ]]; }

# runit_enable <name> — link the service; returns 1 when it is not installed.
runit_enable() {
    local name="$1"
    if [[ ! -d "$(runit_sv)/$name" ]]; then
        yellow "skip    $name — not installed ($(runit_sv)/$name missing)"
        return 1
    fi
    if runit_enabled "$name"; then
        green "ok      $name already enabled"
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would enable $name"
        return 0
    fi
    if "${SUDO[@]}" ln -s "$(runit_sv)/$name" "$(runit_service)/"; then
        manifest_append_row SERVICE "$name"
        green "enabled $name"
        return 0
    fi
    yellow "could not enable $name — run:  sudo ln -s $(runit_sv)/$name $(runit_service)/"
    return 1
}

# runit_disable <name> [down] — unlink a service we are replacing; with
# `down`, also create its down file (a getty, so a later re-link by hand
# does not start it on top of ly). Not enabled: nothing to do, no row.
runit_disable() {
    local name="$1" down="${2:-}" made=""
    runit_enabled "$name" || return 0
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would disable $name"
        return 0
    fi
    if [[ -n "$down" && ! -e "$(runit_sv)/$name/down" ]]; then
        "${SUDO[@]}" touch "$(runit_sv)/$name/down" && made=down
    fi
    if "${SUDO[@]}" rm -f "$(runit_service)/$name"; then
        manifest_append_row SERVICEOFF "$name" "$made"
        green "disabled $name"
        return 0
    fi
    yellow "could not disable $name — run:  sudo rm $(runit_service)/$name"
    return 1
}

services_enable_desktop() {
    local name
    blue "==> runit services"
    for name in "${DESKTOP_SERVICES[@]}"; do
        runit_enable "$name" || true
    done
    # The SPICE guest agent's system half: Void ships it as a runit service
    # that nothing starts by itself (Fedora activated it from the package).
    # Inside a VM only; autostart.sh starts the session half.
    if drivers_is_vm; then
        runit_enable spice-vdagentd || true
    fi
    # Only once NetworkManager is actually enabled: disabling dhcpcd without
    # it would leave the box with no network at all.
    if runit_enabled NetworkManager || [[ $DRY_RUN -eq 1 ]]; then
        for name in "${NM_CONFLICTS[@]}"; do
            runit_disable "$name" || true
        done
    fi
}
