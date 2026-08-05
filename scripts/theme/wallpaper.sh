#!/usr/bin/env bash
# Set the wallpaper and re-theme the desktop from it.
#
#   wallpaper.sh <path>       use a specific image
#   wallpaper.sh --random     pick one at random from the wallpaper dir
#   wallpaper.sh --select     pick one from a dmenu list (NOT rofi)
#
# Pipeline: feh --bg-fill -> colorgen.sh -> apply-templates.sh always ->
# reload.sh. Every stage is a separate script so each is testable and
# replaceable on its own; this is just the user-facing front door.
#
# Wallpaper directory defaults to ~/Pictures/wallpapers, overridable with
# DOTS_WALLPAPER_DIR.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

WALLPAPER_DIR="${DOTS_WALLPAPER_DIR:-$HOME/Pictures/wallpapers}"
cacheDir="${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme"

usage() {
    sed -n '3,7p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

notify() {
    # Notifications are a nicety, never a dependency.
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a "dots-theme" -i preferences-desktop-wallpaper "$@" || true
}

# Only formats feh can actually set as a background.
list_wallpapers() {
    find -L "$WALLPAPER_DIR" -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
        -o -iname '*.webp' -o -iname '*.bmp' \) 2>/dev/null | sort
}

MODE=""
TARGET=""
case "${1:-}" in
    "")
        red "no wallpaper given"
        usage
        exit 1
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    --random) MODE=random ;;
    --select) MODE=select ;;
    -*)
        red "unknown option: $1"
        usage
        exit 1
        ;;
    *)
        MODE=path
        TARGET="$1"
        ;;
esac

if [[ "$MODE" != "path" && ! -d "$WALLPAPER_DIR" ]]; then
    red "wallpaper directory not found: $WALLPAPER_DIR"
    yellow "  create it, or set DOTS_WALLPAPER_DIR, or pass an image path"
    exit 1
fi

case "$MODE" in
    random)
        mapfile -t WALLS < <(list_wallpapers)
        if [[ ${#WALLS[@]} -eq 0 ]]; then
            red "no images in $WALLPAPER_DIR"
            exit 1
        fi
        TARGET="${WALLS[RANDOM % ${#WALLS[@]}]}"
        ;;
    select)
        if ! command -v dmenu >/dev/null 2>&1; then
            red "dmenu not installed — cannot use --select"
            exit 1
        fi
        mapfile -t WALLS < <(list_wallpapers)
        if [[ ${#WALLS[@]} -eq 0 ]]; then
            red "no images in $WALLPAPER_DIR"
            exit 1
        fi
        # Show basenames, resolve back to the full path afterwards, so the
        # menu stays readable on deep directory trees.
        choice="$(printf '%s\n' "${WALLS[@]##*/}" \
            | dmenu -i -l 15 -p "wallpaper>")" || exit 0
        [[ -z "$choice" ]] && exit 0
        TARGET=""
        for w in "${WALLS[@]}"; do
            if [[ "${w##*/}" == "$choice" ]]; then
                TARGET="$w"
                break
            fi
        done
        if [[ -z "$TARGET" ]]; then
            red "no wallpaper matched: $choice"
            exit 1
        fi
        ;;
esac

if [[ ! -f "$TARGET" ]]; then
    red "not a file: $TARGET"
    exit 1
fi
TARGET="$(realpath "$TARGET")"

if ! command -v feh >/dev/null 2>&1; then
    red "feh not installed — cannot set the wallpaper"
    exit 1
fi

blue "==> $TARGET"

# feh writes ~/.fehbg as a side effect; reload.sh re-runs it later to
# repaint the root window after the compositor restarts.
if ! feh --no-fehbg --bg-fill "$TARGET"; then
    red "feh failed to set the wallpaper"
    exit 1
fi
# --no-fehbg above, then write ~/.fehbg ourselves: feh's own version
# embeds the absolute path with no quoting robustness, and reload.sh
# executes this file on every reload.
printf '#!/bin/sh\nfeh --no-fehbg --bg-fill %q\n' "$TARGET" >"$HOME/.fehbg"
chmod 755 "$HOME/.fehbg"
green "wallpaper set"

"$SCRIPT_DIR/colorgen.sh" "$TARGET"
"$SCRIPT_DIR/apply-templates.sh" always
"$SCRIPT_DIR/reload.sh"

# Record which wallpaper the current palette came from, so theme-apply.sh
# --wallbash can regenerate from it without being told again.
mkdir -p "$cacheDir"
printf '%s\n' "$TARGET" >"$cacheDir/wall.set"

notify "Wallpaper applied" "${TARGET##*/}"
green "✓ theme applied from ${TARGET##*/}"
