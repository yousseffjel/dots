#!/usr/bin/env bash
# Laptop-only setup — part of `dots drivers` (scope-h). SOURCED by
# drivers-lib.sh, never run alone; see that file for what it assumes, plus
# DOTS_DIR (file_matches_history reads the repo's git history).
#
# Nothing here runs unless drivers_chassis says laptop. An "unknown" chassis
# (QEMU reports "Other") is treated as a desktop: nothing laptop-only is
# installed on a guess.
#
#   packages/laptop.lst          its packages, each with a PACKAGE row
#   config/xorg/40-dots-touchpad.conf
#                                copied to /etc/X11/xorg.conf.d with a SYSFILE
#                                row: `SYSFILE xorg <installed path> <repo path>`
#
# SYSFILE follows the APP rows' contract (install-restore-apps.sh), with sudo:
# a re-run replaces the installed copy only while it is byte-identical to a
# version this repo shipped (file_matches_history), so an edit is never
# overwritten; a file there that we did not write is never claimed; and
# uninstall-sysfiles.sh removes it on the same condition.

# DOTS_XORG_CONF_DIR overrides /etc/X11/xorg.conf.d, for tests only.
DRIVERS_TOUCHPAD_REL="config/xorg/40-dots-touchpad.conf"

drivers_laptop() {
    local chassis pkg lst="${PACKAGES_DIR:-$DRIVERS_LIB_DIR/../packages}/laptop.lst"
    chassis="$(drivers_chassis)"
    if [[ "$chassis" != laptop ]]; then
        blue "  $chassis ($(drivers_chassis_why)) — no laptop packages or touchpad setup"
        return 0
    fi
    blue "  laptop ($(drivers_chassis_why)) — packages/laptop.lst:"
    # Inside the process substitution below a missing parser would be a
    # silent empty list, i.e. a laptop that quietly gets nothing.
    if ! declare -F read_pkg_list >/dev/null; then
        red "  read_pkg_list is not loaded (source install-pkg-tiers.sh first) — laptop packages not installed"
        return 1
    fi
    while IFS= read -r pkg; do
        drivers_pkg "$pkg" "a laptop feature that needs it stays off (see packages/laptop.lst)" || true
    done < <(read_pkg_list "$lst" || true)
    drivers_touchpad
}

# drivers_touchpad — the Xorg snippet; see the header for the contract.
drivers_touchpad() {
    local src="$DOTS_DIR/$DRIVERS_TOUCHPAD_REL"
    local dst="${DOTS_XORG_CONF_DIR:-/etc/X11/xorg.conf.d}/${DRIVERS_TOUCHPAD_REL##*/}"
    if [[ -e "$dst" ]] && cmp -s "$src" "$dst"; then
        green "  ok      $dst (touchpad) already current"
        return 0
    fi
    if [[ -e "$dst" ]] && ! { manifest_has_path SYSFILE "$dst" && file_matches_history "$dst" "$DRIVERS_TOUCHPAD_REL"; }; then
        yellow "  kept    $dst — edited, or not written by dots; compare with $DRIVERS_TOUCHPAD_REL"
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would install $dst (tap-to-click, natural scrolling, two-finger right-click)"
        return 0
    fi
    if "${SUDO[@]}" install -D -m 644 "$src" "$dst"; then
        manifest_append_row SYSFILE xorg "$dst" "$DRIVERS_TOUCHPAD_REL"
        green "  wrote   $dst — touchpad settings apply at your next login"
    else
        yellow "  FAILED: could not write $dst — the touchpad keeps libinput's defaults (no tap-to-click)"
        FAILED_EXTRA+=(touchpad)
    fi
}
