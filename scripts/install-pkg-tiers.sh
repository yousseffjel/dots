#!/usr/bin/env bash
# Tiered package installation — the machinery install-pkg.sh drives.
#
# Sourced by install-pkg.sh only, never standalone: every function here
# assumes the caller has already `set -euo pipefail` and defined DRY_RUN,
# PACKAGES_DIR, SUDO and the red/green/yellow/blue helpers. Same split
# install-restore.sh makes with install-restore-theme.sh — the tier logic
# and the stage's own orchestration are separate concerns, and keeping both
# in one file put it over the repo's 250-line cap.
#
# usage: source "$SCRIPT_DIR/install-pkg-tiers.sh"
#
# The tiers themselves (which list means what) are documented in
# install-pkg.sh's header and in each packages/*.lst file.

# Strips '#' comments (whole-line or trailing) and blank lines from a .lst file.
read_pkg_list() {
    sed 's/#.*//' "$1" | tr -s '[:space:]' '\n' | grep -v '^$'
}

# Packages that failed, collected for the closing summary. Two arrays so the
# report can lead with the ones that break the desktop.
FAILED_DESKTOP=()
FAILED_EXTRA=()

# stderr from the most recent dnf_install, so a failure can say what actually
# went wrong.
DNF_ERR=""

# package -> consequence text, read from the trailing '#' comment on each
# desktop.lst line. Keeping the note on the same line the name is read from
# means the two cannot drift apart; tests/desktop-consequences.sh fails the
# build if an entry is missing one.
declare -A CONSEQUENCE=()
load_consequences() {
    local line
    while IFS= read -r line; do
        [[ "$line" =~ ^([A-Za-z0-9][A-Za-z0-9._+-]*)[[:space:]]+#[[:space:]]*(.*)$ ]] || continue
        CONSEQUENCE["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
    done <"$PACKAGES_DIR/desktop.lst"
}

dnf_install() {
    local pkg="$1"
    DNF_ERR=""
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would install: $pkg"
        return 0
    fi
    # Keep stderr rather than discarding it. The old code sent everything to
    # /dev/null and then reported every failure as "not found in enabled
    # repos" — the same message for a rename, a network drop, a GPG error and
    # a transaction conflict.
    DNF_ERR="$("${SUDO[@]}" dnf install -y "$pkg" 2>&1 >/dev/null)" || return 1
    return 0
}

# One loop for all three tiers; `mode` decides what a failure costs.
install_tier() {
    local label="$1" list="$2" mode="$3" pkg already
    if [[ ! -f "$list" ]]; then
        red "missing package list: $list"
        exit 1
    fi
    blue "==> $label"
    while IFS= read -r pkg; do
        already=0
        rpm -q "$pkg" >/dev/null 2>&1 && already=1
        if dnf_install "$pkg"; then
            green "  installed: $pkg"
            if [[ $DRY_RUN -eq 0 && $already -eq 0 ]]; then
                manifest_append_row PACKAGE "$pkg"
            fi
            continue
        fi
        [[ -n "$DNF_ERR" ]] && yellow "    dnf: $(printf '%s' "$DNF_ERR" | tail -n1)"
        case "$mode" in
            hard)
                red "required package failed to install: $pkg"
                exit 1
                ;;
            desktop)
                yellow "  FAILED: $pkg — ${CONSEQUENCE[$pkg]:-consequence not recorded in desktop.lst}"
                FAILED_DESKTOP+=("$pkg")
                ;;
            *)
                yellow "  skipped: $pkg"
                FAILED_EXTRA+=("$pkg")
                ;;
        esac
    done < <(read_pkg_list "$list")
}

# Closing report. ~100 packages each print a green line, so a lone yellow
# "skipped" three screens up is invisible — that is exactly how picom stayed
# unlaunched for two months. Everything that failed is repeated here.
install_summary() {
    local pkg
    if [[ ${#FAILED_DESKTOP[@]} -eq 0 && ${#FAILED_EXTRA[@]} -eq 0 ]]; then
        green "✓ every package installed"
        return 0
    fi
    echo
    if [[ ${#FAILED_DESKTOP[@]} -gt 0 ]]; then
        red "==> ${#FAILED_DESKTOP[@]} DESKTOP-CRITICAL package(s) did not install:"
        for pkg in "${FAILED_DESKTOP[@]}"; do
            red "  $pkg"
            red "      ${CONSEQUENCE[$pkg]:-consequence not recorded in desktop.lst}"
        done
        red "  Install these by hand before relying on the desktop."
    fi
    if [[ ${#FAILED_EXTRA[@]} -gt 0 ]]; then
        yellow "==> ${#FAILED_EXTRA[@]} optional package(s) skipped:"
        yellow "  ${FAILED_EXTRA[*]}"
        yellow "  Each costs you that program alone — nothing else changes."
    fi
}
