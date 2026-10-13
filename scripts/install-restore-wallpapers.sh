#!/usr/bin/env bash
# The wallpaper collection for the "restore" stage: a shallow clone of the
# wallpaper repo into wallpapers/dots/ inside the XDG pictures dir, where
# wallpaper.sh (which searches its directory recursively) finds it. Sourced by
# install-restore.sh, never standalone: assumes `set -euo pipefail`,
# global_fn.sh (manifest_*), xdg_dir (config/dwm/bin/dwm-lib-xdg.sh), DRY_RUN
# and the red/green/yellow/blue helpers. scripts/theme/wallpaper.sh sources it
# too, for wallpaper_collection_dir alone — so nothing at the top level here
# may do more than assign.
#
# usage: source "$SCRIPT_DIR/install-restore-wallpapers.sh"; restore_wallpapers
#
# No image is committed to this repo (themes/dark/wallpapers/README.md says
# why); the collection is the user's own repo, cloned at install time like the
# zinit and TPM pre-clones. A re-run — which is what `dots update` does —
# fast-forwards it. DOTS_WALLPAPER_REPO overrides the source; set it empty to
# skip the ~400 MB download entirely.
#
# Same contract as the Flathub remote (install-restore-flatpak.sh): a
# WALLPAPERS manifest row is written only for a clone this step made, and
# uninstall-wallpapers.sh removes it only while it is still exactly that.
# A directory already at the path, cloned by hand or not, is the user's.

WALLPAPER_REPO_DEFAULT="https://github.com/yousseffjel/wallpaper.git"
# 1 once this run has made a fresh clone: the first install opens on a random
# image from it, a re-run (an update) keeps whatever is set.
WALLPAPERS_CLONED=0

# wallpapers/dots, not wallpapers/ itself: theme-apply.sh seeds wallpapers/
# with the generated gradient, so on every existing install that directory
# already exists and would read as "not ours".
wallpaper_collection_dir() {
    printf '%s/wallpapers/dots' "$(xdg_dir PICTURES "$HOME/Pictures")"
}

restore_wallpapers() {
    local url="${DOTS_WALLPAPER_REPO-$WALLPAPER_REPO_DEFAULT}" dir
    dir="$(wallpaper_collection_dir)"
    blue "==> wallpaper collection"
    if [[ -z "$url" ]]; then
        blue "skip    DOTS_WALLPAPER_REPO is empty — no wallpaper collection"
        return 0
    fi
    if [[ -e "$dir" ]]; then
        wallpapers_refresh "$dir"
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would clone $url -> $dir (~400 MB)"
        return 0
    fi
    wallpapers_clone "$url" "$dir"
}

# Fast-forwards a clone this step made; anything else at the path is left as
# it is. A failed pull (no network, local edits in the way) costs only the new
# images, never the install.
wallpapers_refresh() {
    local dir="$1"
    if ! manifest_has_path WALLPAPERS "$dir"; then
        green "ok      $dir exists and is not ours (left alone)"
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would fast-forward $dir"
        return 0
    fi
    if git -C "$dir" pull --ff-only --quiet 2>/dev/null; then
        green "ok      wallpaper collection up to date ($dir)"
    else
        yellow "skip    could not fast-forward $dir (no network, or local changes)"
    fi
}

# The row records the top-most directory the clone had to create, so
# uninstall can remove exactly that much again ("-" when only dots/ was new).
wallpapers_clone() {
    local url="$1" dir="$2" created="-" d
    d="$(dirname "$dir")"
    while [[ ! -e "$d" ]]; do
        created="$d"
        d="$(dirname "$d")"
    done
    blue "  cloning $url (~400 MB, shallow)"
    mkdir -p "$(dirname "$dir")"
    if wallpapers_git_clone "$url" "$dir"; then
        manifest_append_row WALLPAPERS "$url" "$dir" "$created"
        # Read by theme_initial_apply (install-restore-theme.sh).
        # shellcheck disable=SC2034
        WALLPAPERS_CLONED=1
        green "cloned  wallpaper collection -> $dir"
        return 0
    fi
    rm -rf "$dir"
    [[ "$created" == "-" ]] || wallpapers_prune_parents "$dir" "$created"
    yellow "skip    could not clone $url (no network?)."
    yellow "        Re-run scripts/install-fedora.sh --only-restore once online."
}

# git prints progress only to a terminal, and install-fedora.sh pipes all
# output through tee into install.log — so a ~400 MB clone used to show one
# line and then nothing for a minute, which reads as a hang (it was Ctrl-C'd
# on the VM, 2026-10-13). Progress goes straight to the terminal instead, so
# the log never fills with it; with no terminal (CI, a container, a test under
# setsid) the clone stays quiet. On the terminal path git's own error text
# goes there too; the yellow skip line below is what the log records.
wallpapers_git_clone() {
    if { : >/dev/tty; } 2>/dev/null; then
        git clone --depth=1 --progress "$1" "$2" 2>/dev/tty
    else
        git clone --depth=1 --quiet "$1" "$2"
    fi
}

# rmdir from dir's parent up to and including $2, stopping at the first
# directory that is not empty. Shared with uninstall-wallpapers.sh.
wallpapers_prune_parents() {
    local d stop="$2"
    # An empty or "-" stop (a damaged row) would match every absolute path.
    [[ "$stop" == /?* ]] || return 0
    d="$(dirname "$1")"
    while [[ "$d" == "$stop" || "$d" == "$stop"/* ]]; do
        rmdir "$d" 2>/dev/null || return 0
        d="$(dirname "$d")"
    done
}
