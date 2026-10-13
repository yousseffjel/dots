#!/usr/bin/env bash
# Reverts the root-owned files `dots drivers` copied outside $HOME: its
# SYSFILE rows, `SYSFILE <kind> <installed path> <repo path>` (today only the
# touchpad snippet, scripts/drivers-laptop.sh).
#
# Sourced by uninstall.sh, never standalone: it assumes `set -euo pipefail`,
# DRY_RUN, SUDO, DOTS_DIR, global_fn.sh (confirm, manifest_rows,
# file_matches_history) and the colour helpers.
#
# The APP rows' contract, with sudo: a file is removed only while it is an
# unedited copy of some version this repo shipped. An edited one is the
# user's now, so it is kept and named. Runs before uninstall_packages, which
# may remove git, and git is how "unedited" is proved.

uninstall_sysfiles() {
    local rows row kind path rel
    blue "=== system files ==="
    mapfile -t rows < <(manifest_rows SYSFILE)
    if [[ ${#rows[@]} -eq 0 ]]; then
        blue "  no SYSFILE rows in manifest — nothing to remove"
        return 0
    fi
    confirm "Remove the ${#rows[@]} system file(s) dots installed (e.g. the touchpad settings)?" || {
        yellow "  skipped system files"
        return 0
    }
    for row in "${rows[@]}"; do
        IFS=$'\t' read -r _ kind path rel <<<"$row"
        if [[ ! -e "$path" ]]; then
            blue "  $path is already gone"
        elif ! file_matches_history "$path" "$rel"; then
            yellow "  kept $path — edited since dots installed it ($kind); remove it by hand if unwanted"
        elif [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would remove $path"
        elif "${SUDO[@]}" rm -f "$path"; then
            green "  removed $path"
        else
            red "  failed to remove $path"
        fi
    done
}
