#!/usr/bin/env bash
# dnf speed setup, run before any package is installed. SOURCED by
# install-pkg.sh only; it assumes what that file defines (DRY_RUN, SUDO,
# DOTS_DIR, global_fn.sh, the colour helpers).
#
#   dnf_speed_conf  copies config/dnf/30-dots-speed.conf into dnf5's drop-in
#                   directory (fastestmirror, 10 parallel downloads, a 20 KiB/s
#                   floor that drops a crawling mirror). It persists — `dots
#                   update` and the user's own dnf runs get it too — so it is a
#                   SYSFILE row (sysfile-lib.sh) and `dots uninstall` removes
#                   it while unedited. Written first because the floor is the
#                   point: on 2026-10-14 a fresh install sat an hour on one
#                   3 KiB/s mirror, just above dnf's default 1000 B/s floor.
#   dnf_refresh     one visible `dnf makecache --refresh` with those
#                   settings, so the mirror probe happens up front under its
#                   own line. Without --refresh, metadata still fresh from an
#                   earlier run made makecache touch no mirror, and the probe
#                   (50 s cold on the F44 VM, cached after) ran silently
#                   inside the first install instead.
#
# /etc/dnf/libdnf5.conf.d is dnf5's (Fedora 41+) user drop-in directory;
# DOTS_DNF_CONF_DIR overrides it, for tests only.

# shellcheck source=sysfile-lib.sh
source "$SCRIPT_DIR/sysfile-lib.sh"

DNF_SPEED_REL="config/dnf/30-dots-speed.conf"

dnf_speed_conf() {
    blue "==> dnf download settings"
    sysfile_install dnf "$DNF_SPEED_REL" \
        "${DOTS_DNF_CONF_DIR:-/etc/dnf/libdnf5.conf.d}/${DNF_SPEED_REL##*/}" \
        "fastest mirror, 10 parallel downloads, slow mirrors dropped" \
        "fastest mirror, 10 parallel downloads, slow mirrors dropped" \
        "dnf keeps its defaults (3 downloads at a time, slow mirrors kept)" \
        || FAILED_EXTRA+=(dnf-speed-conf)
}

dnf_refresh() {
    blue "==> refreshing repository metadata (picks the fastest mirror)"
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would run: dnf makecache"
        return 0
    fi
    # Best-effort: every later dnf call refreshes on its own if this fails.
    if "${SUDO[@]}" dnf makecache -q --refresh >/dev/null 2>&1; then
        green "  ok      metadata current"
    else
        yellow "  dnf makecache failed — each install refreshes on its own; check the network if they fail too"
    fi
}
