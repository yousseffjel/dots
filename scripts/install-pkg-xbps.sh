#!/usr/bin/env bash
# Brings the system up to date before any package is installed. Sourced by
# install-pkg.sh only: assumes `set -euo pipefail`, DRY_RUN, SUDO, the colour
# helpers, and pkg_run_streamed from install-pkg-tiers.sh.
#
# usage: source "$SCRIPT_DIR/install-pkg-xbps.sh"; xbps_prepare
#
# Void does not support partial upgrades. Installing a new package on a
# system older than the repos can fail with "unresolvable shlib", and Void's
# install images are often months old. So every run (including
# `dots update`) does the full sequence the handbook prescribes. This is the
# user's decision (scope I, 2026-10-15), chosen over upgrading only on the
# first install.
#   1. `xbps-install -Syu xbps` — sync the index and update xbps itself first.
#      A newer repo can require a newer xbps, and updating it alone first is
#      the handbook's order.
#   2. `xbps-install -yu` — upgrade everything else.
# Neither step is fatal: a failure is reported and the tiers still run, so
# the closing summary names what that cost.
#
# This replaced install-pkg-dnf.sh (Fedora's speed drop-in + one makecache).
# xbps has no equivalent setting to tune.

xbps_prepare() {
    local rc
    blue "==> bringing the system up to date (Void does not support partial upgrades)"
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would run: xbps-install -Syu xbps, then xbps-install -yu"
        return 0
    fi
    rc=0
    pkg_run_streamed xbps-install -Syu xbps || rc=$?
    rm -f "$PKG_LOG"
    if ((rc != 0)); then
        yellow "  could not sync or update xbps (exit $rc) — package installs may fail below"
        return 0
    fi
    rc=0
    pkg_run_streamed xbps-install -yu || rc=$?
    rm -f "$PKG_LOG"
    if ((rc != 0)); then
        yellow "  the system upgrade failed (exit $rc) — run: sudo xbps-install -Su"
        return 0
    fi
    green "  ok      system up to date"
}
