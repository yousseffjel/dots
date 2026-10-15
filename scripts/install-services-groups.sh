#!/usr/bin/env bash
# User groups for the services stage (scope I, decision D4). Sourced by
# install-services.sh, never standalone: assumes `set -euo pipefail`,
# DRY_RUN, SUDO and the colour helpers.
#
# The script, not the Void installer's group screen, makes membership
# reproducible. Each group has one reason, checked in the package that
# grants it (2026-10-15):
#   network    NetworkManager's polkit rule lets this group manage
#              connections without a password (nm-applet, nmtui).
#   bluetooth  bluez's D-Bus policy grants this group the adapter (blueman);
#              bluez creates the group, so it exists only once bluez is in.
#   kvm        libvirt/QEMU guests; harmless on a box without them.
# wheel is NOT here: it is the precondition for sudo, checked by
# install-pre.sh before anything runs.
#
# Never reverted, so no manifest row: taking `network` away can lock a user
# out of their own network settings (docs/UNINSTALL.md, "What's kept").

USER_GROUPS=(network bluetooth kvm)

# groups_add <user> — add the user to every USER_GROUPS group that exists and
# they are not in yet, in one usermod. Idempotent: a re-run adds nothing.
groups_add() {
    local user="$1" g have missing=()
    blue "==> user groups"
    have=" $(id -nG "$user" 2>/dev/null || true) "
    for g in "${USER_GROUPS[@]}"; do
        if [[ "$have" == *" $g "* ]]; then
            continue
        elif ! getent group "$g" >/dev/null 2>&1; then
            yellow "skip    group $g does not exist (its package did not install)"
        else
            missing+=("$g")
        fi
    done
    if [[ ${#missing[@]} -eq 0 ]]; then
        green "ok      $user is in every group it needs"
        return 0
    fi
    local list
    list="$(
        IFS=,
        printf '%s' "${missing[*]}"
    )"
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would run: usermod -aG $list $user"
    elif "${SUDO[@]}" usermod -aG "$list" "$user"; then
        green "added   $user to $list"
        yellow "        log out and back in: new groups apply to new logins only"
    else
        yellow "could not add groups — run:  sudo usermod -aG $list $user"
    fi
}
