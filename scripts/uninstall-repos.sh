#!/usr/bin/env bash
# Reverts what scripts/install-pkg-repos.sh changed: its REPO rows.
#
# Sourced by uninstall.sh, never standalone: it assumes `set -euo pipefail`,
# DRY_RUN, SUDO, global_fn.sh (confirm, manifest_rows) and the colour helpers.
#
# Two functions, because they must straddle uninstall_packages:
#   uninstall_repo_swaps  BEFORE it. Undoes every REPO swap row: RPM Fusion's
#                         ffmpeg back to Fedora's ffmpeg-free, and the AMD
#                         mesa-va-drivers swap drivers-gpu.sh makes up to f43.
#                         Removing ffmpeg instead would take everything that
#                         depends on it with it, and ffmpeg-free is then
#                         removed by uninstall_packages if this installer put
#                         it there in the first place.
#   uninstall_repos       AFTER it. A repo is removed only while nothing
#                         installed still comes from it, the same rule
#                         uninstall-flatpak.sh applies to Flathub. With our
#                         own packages already gone, what is left is yours.
#
# Never touched: the rpm signing keys install-pkg-repos.sh imported. A key with
# no repo pointing at it signs nothing, and removing one by hand means picking
# a gpg-pubkey-* package by id — `rpm -qa gpg-pubkey* --qf '%{NAME}-%{VERSION}-%{RELEASE} %{SUMMARY}\n'`.

uninstall_repo_swaps() {
    local swaps kind from to
    swaps="$(manifest_rows REPO | awk -F'\t' '$2=="swap"')"
    [[ -n "$swaps" ]] || return 0
    blue "=== package swaps ==="
    confirm "Swap back the package(s) this installer replaced with RPM Fusion builds?" || {
        yellow "  skipped package swaps"
        return 0
    }
    while IFS=$'\t' read -r _ kind from to; do
        if ! rpm -q "$to" >/dev/null 2>&1; then
            blue "  $to is no longer installed — nothing to swap back"
            continue
        fi
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would run: dnf swap $to $from --allowerasing"
        elif "${SUDO[@]}" dnf swap -y "$to" "$from" --allowerasing >/dev/null 2>&1; then
            green "  swapped $to back to $from"
        else
            red "  dnf swap $to $from failed — run it by hand before removing RPM Fusion"
        fi
    done <<<"$swaps"
}

# True while an installed package other than a release package came from a
# repo whose id starts with $1. Called with the family ("rpmfusion"), not the
# repo: rpmfusion-nonfree-release requires rpmfusion-free-release, so removing
# free while nonfree is still in use would take nonfree with it. The prefix
# also covers each repo's -updates twin.
repo_in_use() {
    local prefix="$1" installed name from
    # Fails CLOSED: if dnf cannot say what is installed, the repo is in use.
    # Failing open would remove RPM Fusion from under the packages that need it.
    if ! installed="$(dnf repoquery --installed --queryformat '%{name} %{from_repo}\n' 2>/dev/null)"; then
        yellow "  dnf repoquery failed — cannot tell what comes from $prefix, so it is kept"
        return 0
    fi
    while read -r name from; do
        [[ "$name" == *-release ]] && continue
        [[ "$from" == "$prefix"* ]] && return 0
    done <<<"$installed"
    return 1
}

uninstall_repo_file() {
    local name="$1" path="$2"
    if rpm -q "$name" >/dev/null 2>&1; then
        yellow "  kept $path — $name is still installed"
    elif [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would remove $path"
    elif "${SUDO[@]}" rm -f "$path"; then
        green "  removed $path"
    else
        red "  failed to remove $path"
    fi
}

uninstall_repos() {
    blue "=== third-party repositories ==="
    local rows row releases=() kind name what
    mapfile -t rows < <(manifest_rows REPO | awk -F'\t' '$2!="swap"')
    if [[ ${#rows[@]} -eq 0 ]]; then
        blue "  no REPO rows in manifest — nothing to remove"
        return 0
    fi
    confirm "Remove the ${#rows[@]} repository(ies) this installer added?" || {
        yellow "  skipped repositories"
        return 0
    }
    for row in "${rows[@]}"; do
        IFS=$'\t' read -r _ kind name what <<<"$row"
        case "$kind" in
            file) uninstall_repo_file "$name" "$what" ;;
            release)
                if repo_in_use "${name%%-*}"; then
                    yellow "  kept $name — installed packages still come from ${name%%-*}"
                else
                    releases+=("$what")
                fi
                ;;
            *) yellow "  unknown REPO row kind '$kind' — left alone" ;;
        esac
    done
    [[ ${#releases[@]} -eq 0 ]] && return 0
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would run: dnf remove -y ${releases[*]}"
    elif "${SUDO[@]}" dnf remove -y "${releases[@]}" >/dev/null 2>&1; then
        green "  removed ${releases[*]}"
    else
        red "  dnf remove failed — remove by hand: ${releases[*]}"
    fi
}
