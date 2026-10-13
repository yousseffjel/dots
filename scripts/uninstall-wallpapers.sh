#!/usr/bin/env bash
# The "wallpaper collection" uninstall step — removes the clone
# install-restore-wallpapers.sh made, and the parent directories it had to
# create, only while the clone is still exactly what was cloned.
#
# Sourced by uninstall.sh only: assumes `set -euo pipefail`, global_fn.sh
# (manifest_rows), install-restore-wallpapers.sh (wallpapers_prune_parents),
# uninstall.sh's own logging-aware red/green/yellow/blue plus confirm() and
# DRY_RUN.
#
# "Exactly what was cloned" is what git can prove: the same origin, nothing
# modified or untracked (an image the user dropped in is untracked, and is
# theirs), and no commit that is not on the upstream. Anything else keeps the
# whole directory — a left-behind clone is recoverable, a deleted image is not.

# WALLPAPERS rows: "<url> <clone dir> <top-most dir created, or ->".
uninstall_wallpapers() {
    blue "=== wallpaper collection ==="
    local rows=() row url dir created
    mapfile -t rows < <(manifest_rows WALLPAPERS)
    if [[ ${#rows[@]} -eq 0 ]]; then
        blue "  no WALLPAPERS rows in manifest — nothing to remove"
        return 0
    fi
    if ! confirm "Remove the wallpaper collection dots cloned (only if you have not changed it)?"; then
        yellow "  skipped wallpaper collection"
        return 0
    fi
    for row in "${rows[@]}"; do
        IFS=$'\t' read -r _ url dir created <<<"$row"
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would remove $dir if it is still an unchanged clone of $url"
            continue
        fi
        uninstall_wallpaper_clone "$url" "$dir" "$created"
    done
}

uninstall_wallpaper_clone() {
    local url="$1" dir="$2" created="$3" why
    if [[ ! -e "$dir" ]]; then
        blue "  gone     $dir (already removed)"
    elif why="$(wallpapers_clone_changed "$url" "$dir")"; then
        yellow "  kept     $dir ($why)"
        return 0
    else
        rm -rf "$dir"
        green "  removed  $dir"
    fi
    [[ "$created" == "-" ]] || wallpapers_prune_parents "$dir" "$created"
}

# Succeeds — printing the reason — when $2 is NOT an unchanged clone of $1.
# Every git answer is captured before it is tested: under pipefail a
# `git ... | grep -q` can report 141 on a match (see manifest_has_path).
wallpapers_clone_changed() {
    local url="$1" dir="$2" top origin dirty ahead
    top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)"
    if [[ "$top" != "$dir" ]]; then
        echo "not a git checkout any more"
        return 0
    fi
    origin="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
    if [[ "$origin" != "$url" ]]; then
        echo "origin is now ${origin:-unset}"
        return 0
    fi
    dirty="$(git -C "$dir" status --porcelain 2>/dev/null || echo unreadable)"
    if [[ -n "$dirty" ]]; then
        echo "files added or changed since install"
        return 0
    fi
    ahead="$(git -C "$dir" rev-list --count '@{u}..HEAD' 2>/dev/null || echo unknown)"
    if [[ "$ahead" != "0" ]]; then
        echo "local commits not on the upstream"
        return 0
    fi
    return 1
}
