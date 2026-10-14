#!/usr/bin/env bash
# Laptop-only setup — part of `dots drivers` (scope-h). SOURCED by
# drivers-lib.sh, never run alone; see that file for what it assumes, plus
# DOTS_DIR (file_matches_history reads the repo's git history).
#
# Nothing here runs unless drivers_chassis says laptop. A "vm" or "unknown"
# chassis is treated as a desktop: nothing laptop-only is
# installed on a guess.
#
#   packages/laptop.lst          its packages, each with a PACKAGE row
#   config/xorg/40-dots-touchpad.conf
#                                copied to /etc/X11/xorg.conf.d with a SYSFILE
#                                row: `SYSFILE xorg <installed path> <repo path>`
#   tuned.service, tuned-ppd.service
#                                enabled (SERVICE rows, only for a unit this run
#                                enabled) so the profile dwm-power picks is
#                                re-applied at boot; tuned-ppd itself is
#                                D-Bus-activated, tuned would otherwise not run
#
# The SYSFILE contract (an edit is never overwritten, a file we did not write
# is never claimed) lives in sysfile-lib.sh, shared with the dnf drop-in.

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
    drivers_power
}

# drivers_power — see the header. `--now` so the switcher works before the
# next boot. A unit already enabled is the user's (or a distribution preset's)
# and gets no row, so uninstall never disables it.
drivers_power() {
    local unit
    for unit in tuned.service tuned-ppd.service; do
        if [[ "$(systemctl is-enabled "$unit" 2>/dev/null || true)" == enabled ]]; then
            green "  ok      $unit already enabled"
        elif [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would enable $unit (power profiles)"
        elif "${SUDO[@]}" systemctl enable --now "$unit" >/dev/null 2>&1; then
            manifest_append_row SERVICE "$unit"
            green "  enabled $unit"
        else
            yellow "  FAILED: systemctl enable --now $unit — power profiles are not kept across reboots"
            FAILED_EXTRA+=("$unit")
        fi
    done
}

# drivers_touchpad — the Xorg snippet; the contract is sysfile_install's
# (sysfile-lib.sh).
drivers_touchpad() {
    sysfile_install xorg "$DRIVERS_TOUCHPAD_REL" \
        "${DOTS_XORG_CONF_DIR:-/etc/X11/xorg.conf.d}/${DRIVERS_TOUCHPAD_REL##*/}" \
        "tap-to-click, natural scrolling, two-finger right-click" \
        "touchpad settings apply at your next login" \
        "the touchpad keeps libinput's defaults (no tap-to-click)" \
        || FAILED_EXTRA+=(touchpad)
}
