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
#   power-profiles-daemon        its runit service linked (a SERVICE row, only
#                                when this run linked it), so the profile
#                                dwm-power picks survives a reboot. It replaced
#                                Fedora's tuned + tuned-ppd: same D-Bus API.
#
# The SYSFILE contract (an edit is never overwritten, a file we did not write
# is never claimed) lives in sysfile-lib.sh.

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
        pkg_ensure "$pkg" "a laptop feature that needs it stays off (see packages/laptop.lst)" || true
    done < <(read_pkg_list "$lst" || true)
    drivers_touchpad
    drivers_power
}

# drivers_power — see the header. runit starts it within seconds of the link,
# so the switcher works before the next boot. One already enabled is the
# user's and gets no row, so uninstall never disables it (runit_enable's rule).
drivers_power() {
    # A dry run installed nothing, so the service dir is not there to link.
    if [[ $DRY_RUN -eq 1 ]] && ! [[ -d "$(runit_sv)/power-profiles-daemon" ]]; then
        blue "  (dry-run) would enable power-profiles-daemon"
        return 0
    fi
    runit_enable power-profiles-daemon \
        || FAILED_EXTRA+=(power-profiles-daemon)
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
