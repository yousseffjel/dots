#!/usr/bin/env bash
# Third-party repositories behind the default applications (config/mimeapps.list).
#
# Sourced by install-pkg.sh after the package tiers, never standalone: it
# assumes `set -euo pipefail`, DRY_RUN, SUDO, the red/green/yellow/blue
# helpers, global_fn.sh's manifest_* functions, and install-pkg-tiers.sh's
# FAILED_EXTRA array.
#
# usage: source "$SCRIPT_DIR/install-pkg-repos.sh"; repos_install
#
# CLAUDE.md rule 4 says enabling a third-party repository is the user's call.
# Both of these were explicitly authorised in-session on 2026-10-13, like the
# clipmenu COPR and Flathub before them:
#
#   * Sublime HQ's rpm repo, for sublime-text, the default text/code editor.
#     Signed (gpgcheck=1); published for x86_64 and aarch64 only.
#   * RPM Fusion free + nonfree, for codecs. Fedora's ffmpeg-free has no HEVC
#     decoder at all and decodes H.264 only through openh264, so most HDR
#     episodes (10-bit HEVC) would not open in mpv. The fix is RPM Fusion's
#     documented `dnf swap ffmpeg-free ffmpeg`, plus intel-media-driver
#     (nonfree) for VA-API hardware decoding on Intel GPUs.
#
# Every change gets a REPO row only when THIS run made it, so `dots
# uninstall` reverts what we did and nothing that was already there:
#   REPO  file     sublime-text   /etc/yum.repos.d/sublime-text.repo
#   REPO  release  rpmfusion-free rpmfusion-free-release
#   REPO  swap     ffmpeg-free    ffmpeg
# See uninstall-repos.sh for how each one is reverted.

SUBLIME_REPO_FILE="${SUBLIME_REPO_FILE:-/etc/yum.repos.d/sublime-text.repo}"
SUBLIME_KEY_URL="https://download.sublimetext.com/sublimehq-rpm-pub.gpg"
RPMFUSION_MIRROR="https://mirrors.rpmfusion.org"

# repos_install_pkg <pkg> <what its absence costs> — one package from a repo
# enabled here. A failure goes to the yellow tier of the closing summary.
repos_install_pkg() {
    local pkg="$1" cost="$2" already=0 err
    rpm -q "$pkg" >/dev/null 2>&1 && already=1
    if err="$("${SUDO[@]}" dnf install -y "$pkg" 2>&1 >/dev/null)"; then
        green "  installed: $pkg"
        [[ $already -eq 0 ]] && manifest_append_row PACKAGE "$pkg"
        return 0
    fi
    yellow "  FAILED: $pkg — $cost"
    [[ -n "$err" ]] && yellow "    dnf: $(printf '%s' "$err" | tail -n1)"
    FAILED_EXTRA+=("$pkg")
    return 1
}

repos_add_sublime() {
    local arch
    arch="$(uname -m)"
    blue "==> Sublime Text (Sublime HQ rpm repo)"
    if [[ "$arch" != x86_64 && "$arch" != aarch64 ]]; then
        yellow "  skipped — Sublime HQ publishes no rpm repo for $arch"
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would add $SUBLIME_REPO_FILE and install sublime-text"
        return 0
    fi
    if [[ -e "$SUBLIME_REPO_FILE" ]]; then
        green "  ok      $SUBLIME_REPO_FILE already present"
    elif "${SUDO[@]}" rpm --import "$SUBLIME_KEY_URL" \
        && "${SUDO[@]}" dnf config-manager addrepo \
            --from-repofile="https://download.sublimetext.com/rpm/stable/$arch/sublime-text.repo"; then
        manifest_append_row REPO file sublime-text "$SUBLIME_REPO_FILE"
        green "  added   $SUBLIME_REPO_FILE"
    else
        yellow "  FAILED: could not add the Sublime HQ repo — text files fall back to nvim"
        FAILED_EXTRA+=(sublime-text)
        return 0
    fi
    repos_install_pkg sublime-text "text files fall back to nvim (dots-nvim.desktop)" || true
}

# Both release packages in one place: nonfree is only useful with free.
repos_add_rpmfusion() {
    local flavour url fedora
    fedora="$(rpm -E %fedora)"
    for flavour in free nonfree; do
        if rpm -q "rpmfusion-$flavour-release" >/dev/null 2>&1; then
            green "  ok      rpmfusion-$flavour-release already installed"
            continue
        fi
        url="$RPMFUSION_MIRROR/$flavour/fedora/rpmfusion-$flavour-release-$fedora.noarch.rpm"
        if "${SUDO[@]}" dnf install -y "$url" >/dev/null 2>&1; then
            manifest_append_row REPO release "rpmfusion-$flavour" "rpmfusion-$flavour-release"
            green "  added   RPM Fusion $flavour"
        else
            yellow "  FAILED: RPM Fusion $flavour could not be enabled — HEVC/HDR video will not play"
            FAILED_EXTRA+=("rpmfusion-$flavour-release")
            return 1
        fi
    done
}

# ffmpeg-free (desktop.lst, the screen recorder) -> RPM Fusion's full ffmpeg.
# install-pkg-tiers.sh treats ffmpeg-free as satisfied once this is done, so
# a re-run does not try to reinstall it over the top.
repos_swap_ffmpeg() {
    if rpm -q ffmpeg >/dev/null 2>&1; then
        green "  ok      ffmpeg (RPM Fusion) already installed"
    elif rpm -q ffmpeg-free >/dev/null 2>&1; then
        if "${SUDO[@]}" dnf swap -y ffmpeg-free ffmpeg --allowerasing >/dev/null 2>&1; then
            manifest_append_row REPO swap ffmpeg-free ffmpeg
            green "  swapped ffmpeg-free -> ffmpeg"
        else
            yellow "  FAILED: dnf swap ffmpeg-free ffmpeg — HEVC/HDR video will not play"
            FAILED_EXTRA+=(ffmpeg)
        fi
    else
        repos_install_pkg ffmpeg "HEVC/HDR video will not play" || true
    fi
}

repos_add_codecs() {
    blue "==> RPM Fusion codecs (HEVC/HDR video in mpv)"
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would enable RPM Fusion free + nonfree, swap ffmpeg-free -> ffmpeg, install intel-media-driver"
        return 0
    fi
    repos_add_rpmfusion || return 0
    repos_swap_ffmpeg
    repos_install_pkg intel-media-driver \
        "no VA-API hardware decoding on Intel: mpv decodes HEVC on the CPU" || true
}

repos_install() {
    repos_add_sublime
    repos_add_codecs
}
