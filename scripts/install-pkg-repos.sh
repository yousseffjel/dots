#!/usr/bin/env bash
# Extra repositories behind the default applications (config/mimeapps.list),
# then the hardware drivers.
#
# Sourced by install-pkg.sh after the package tiers, never standalone: it
# assumes `set -euo pipefail`, DRY_RUN, SUDO, the red/green/yellow/blue
# helpers, global_fn.sh's manifest_* functions, and install-pkg-tiers.sh
# (pkg_installed, pkg_ensure, pkg_run_streamed, FAILED_EXTRA).
#
# usage: source "$SCRIPT_DIR/install-pkg-repos.sh"; repos_install
#
# On Void this is ONE repository: the official `nonfree` repo, for
# sublime-text4, the default text/code editor. It is a Void repo, signed with
# Void's own key and enabled by installing the `void-repo-nonfree` package
# from main. It is not a third-party source, but it is still a choice beyond
# the base system, made explicitly by the user (CLAUDE.md rule 4; Sublime
# Text since 2026-10-13, nonfree as its source since the Void port).
#
# Everything the Fedora version did here is gone, because Void's main repo
# covers it: clipmenu/clipnotify (desktop.lst; there was a COPR), and the
# full ffmpeg build with HEVC (desktop.lst's ffmpeg6; there were RPM Fusion
# and an ffmpeg-free swap).
#
# A REPO row only when THIS run enabled nonfree, so `dots uninstall` reverts
# what we did and nothing that was already there:
#   REPO  package  nonfree  void-repo-nonfree
# uninstall-repos.sh removes it only while nothing installed comes from it.
#
# Probed with xbps-static 0.60.7 (scratch root, 2026-10-15): installing
# void-repo-nonfree only drops /usr/share/xbps.d/10-repository-nonfree.conf;
# the nonfree index is fetched by the NEXT `xbps-install -S`, so the sync
# below is required before anything from nonfree can resolve.

NONFREE_PKG=void-repo-nonfree

# Its own directory, not the caller's SCRIPT_DIR: tests source this file too.
# shellcheck source=drivers-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/drivers-lib.sh"

# repos_enable_nonfree — returns non-zero when nonfree could not be enabled,
# so the caller skips what needs it.
repos_enable_nonfree() {
    local rc=0
    if pkg_installed "$NONFREE_PKG"; then
        green "  ok      nonfree repository already enabled"
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would install $NONFREE_PKG and re-sync the index"
        return 0
    fi
    pkg_run_streamed xbps-install -y "$NONFREE_PKG" || rc=$?
    rm -f "$PKG_LOG"
    if ((rc != 0)); then
        yellow "  FAILED: could not enable the nonfree repository (xbps exit $rc)"
        FAILED_EXTRA+=("$NONFREE_PKG")
        return 1
    fi
    manifest_append_row REPO package nonfree "$NONFREE_PKG"
    green "  added   nonfree repository"
    pkg_run_streamed xbps-install -S || rc=$?
    rm -f "$PKG_LOG"
    if ((rc != 0)); then
        yellow "  could not sync the nonfree index (xbps exit $rc) — its packages will not resolve"
        return 1
    fi
}

repos_add_sublime() {
    blue "==> Sublime Text (Void's nonfree repository)"
    # glibc x86_64 only: nonfree publishes no musl or other-arch build of it.
    if [[ "$(xbps-uhelper arch 2>/dev/null || true)" != x86_64 ]]; then
        yellow "  skipped — nonfree has no sublime-text4 for $(xbps-uhelper arch 2>/dev/null || uname -m)"
        yellow "        text files open in nvim instead (dots-nvim.desktop)"
        return 0
    fi
    if ! repos_enable_nonfree; then
        yellow "  text files open in nvim instead (dots-nvim.desktop)"
        return 0
    fi
    pkg_ensure sublime-text4 "text files fall back to nvim (dots-nvim.desktop)" || true
}

repos_install() {
    repos_add_sublime
    # The same code as `dots drivers`, run in-process so its failures land in
    # this stage's closing summary. After nonfree, which intel-ucode comes from.
    drivers_install
}
