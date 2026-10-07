#!/usr/bin/env bash
# Sourced by dwm-screenshot and dwm-record, never run (no exec bit, so
# dmenu_path never lists it): the one place that decides where they save.
# Each script falls back to a fixed path if this file is missing.

# xdg_dir <NAME> <fallback> — the XDG user directory, as `xdg-user-dir` names
# it (localised, or moved in ~/.config/user-dirs.dirs). autostart.sh runs
# xdg-user-dirs-update at login so it exists. xdg-user-dir answers $HOME for a
# directory it has no entry for, and files dropped straight into ~ are not
# what anyone wants — so that answer, like no xdg-user-dir at all, means the
# fallback.
xdg_dir() {
    local dir
    dir="$(xdg-user-dir "$1" 2>/dev/null || true)"
    dir="${dir%/}"
    if [[ -z "$dir" || "$dir" == "${HOME%/}" ]]; then
        dir="$2"
    fi
    printf '%s' "$dir"
}
