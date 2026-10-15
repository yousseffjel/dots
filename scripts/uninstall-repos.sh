#!/usr/bin/env bash
# Reverts what scripts/install-pkg-repos.sh (and drivers-lib.sh) changed: the
# REPO rows.
#
# Sourced by uninstall.sh, never standalone: it assumes `set -euo pipefail`,
# DRY_RUN, SUDO, global_fn.sh (confirm, manifest_rows) and the colour helpers.
#
# Runs after uninstall_packages:
#   uninstall_repos       The nonfree repository is removed only
#                         while nothing installed still comes from it, the
#                         same rule uninstall-flatpak.sh applies to Flathub.
#                         With our own packages already gone, what is left
#                         is yours.

# nonfree_in_use — true while an installed package is one the nonfree repo
# ships. One query, probed with xbps-static 0.60.7: `-i --repository=<url>
# -Rs ''` lists only that repository's packages, `[*]` marking the installed
# ones. FAILS CLOSED: if xbps cannot answer, the repo counts as in use, since
# failing open would remove nonfree from under the packages that need it.
nonfree_in_use() {
    local repos url="" u listing
    # Both queries fail closed. Captured, not piped into awk: an early awk
    # exit would SIGPIPE xbps-query and, under pipefail, read as a failure.
    if ! repos="$(xbps-query -L 2>/dev/null)"; then
        yellow "  xbps-query -L failed — cannot tell what comes from nonfree, so it is kept"
        return 0
    fi
    while read -r _ u _; do
        [[ "$u" == */nonfree ]] && url="$u" && break
    done <<<"$repos"
    if [[ -z "$url" ]]; then
        # Enabled but never synced: nothing can have come from it.
        return 1
    fi
    if ! listing="$(xbps-query -i --repository="$url" -Rs '' 2>/dev/null)"; then
        yellow "  xbps-query failed — cannot tell what comes from nonfree, so it is kept"
        return 0
    fi
    # Captured, not piped into grep -q: under pipefail an early grep exit can
    # SIGPIPE the producer and read a match as a failure.
    [[ "$listing" == *$'\n[*] '* || "$listing" == '[*] '* ]]
}

uninstall_repo_package() {
    local pkg="$1"
    if ! xbps-query "$pkg" >/dev/null 2>&1; then
        blue "  $pkg is no longer installed — nothing to remove"
    elif nonfree_in_use; then
        yellow "  kept $pkg — installed packages still come from nonfree"
    elif [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would run: xbps-remove -y $pkg"
    elif "${SUDO[@]}" xbps-remove -y "$pkg" >/dev/null 2>&1 </dev/null; then
        green "  removed $pkg (nonfree repository disabled)"
    else
        red "  xbps-remove failed — remove by hand: $pkg"
    fi
}

uninstall_repos() {
    blue "=== extra repositories ==="
    local rows row kind name what
    mapfile -t rows < <(manifest_rows REPO)
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
            package) uninstall_repo_package "$what" ;;
            *) yellow "  unknown REPO row kind '$kind' ($name) — left alone" ;;
        esac
    done
}
