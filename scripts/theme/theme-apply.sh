#!/usr/bin/env bash
# Apply a colour theme to the desktop.
#
#   theme-apply.sh <name>       use the static palette in themes/<name>/
#   theme-apply.sh --wallbash   re-derive the palette from the current
#                               wallpaper instead of a static theme
#   theme-apply.sh --list       list available themes
#
# Unlike wallpaper.sh this processes BOTH template groups: a theme switch
# can change things (gtk/icon/cursor names, fonts) that a wallpaper change
# cannot, and those live in the theme/ group.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
THEMES_DIR="$DOTS_DIR/themes"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

cacheDir="${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme"

usage() {
    sed -n '3,7p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a "dots-theme" -i preferences-desktop-theme "$@" || true
}

list_themes() {
    [[ -d "$THEMES_DIR" ]] || return 0
    find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
}

MODE=""
THEME=""
case "${1:-}" in
    "")
        red "no theme given"
        usage
        exit 1
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    --list)
        mapfile -t THEMES < <(list_themes)
        if [[ ${#THEMES[@]} -eq 0 ]]; then
            yellow "no themes in $THEMES_DIR"
        else
            printf '%s\n' "${THEMES[@]}"
        fi
        exit 0
        ;;
    --wallbash) MODE=wallbash ;;
    -*)
        red "unknown option: $1"
        usage
        exit 1
        ;;
    *)
        MODE=static
        THEME="$1"
        ;;
esac

PALETTE=""
if [[ "$MODE" == "wallbash" ]]; then
    # Regenerate from the wallpaper wallpaper.sh last recorded. colorgen.sh
    # is cache-keyed on path+mtime, so this is near-instant unless the
    # image actually changed.
    WALL_SET="$cacheDir/wall.set"
    if [[ ! -f "$WALL_SET" ]]; then
        red "no current wallpaper recorded ($WALL_SET)"
        yellow "  run: wallpaper.sh <path>   first"
        exit 1
    fi
    WALL="$(<"$WALL_SET")"
    if [[ ! -f "$WALL" ]]; then
        red "recorded wallpaper is gone: $WALL"
        exit 1
    fi
    blue "==> wallbash palette from ${WALL##*/}"
    "$SCRIPT_DIR/colorgen.sh" "$WALL"
    PALETTE="$cacheDir/colors.dcol"
else
    THEME_DIR="$THEMES_DIR/$THEME"
    if [[ ! -d "$THEME_DIR" ]]; then
        red "no such theme: $THEME"
        mapfile -t THEMES < <(list_themes)
        [[ ${#THEMES[@]} -gt 0 ]] && yellow "  available: ${THEMES[*]}"
        exit 1
    fi
    PALETTE="$THEME_DIR/colors.dcol"
    if [[ ! -f "$PALETTE" ]]; then
        red "theme has no colors.dcol: $PALETTE"
        exit 1
    fi
    blue "==> static theme: $THEME"

    # theme.conf carries the non-colour parts of a theme (gtk/icon/cursor
    # theme names, font). Only reported here — templates in the theme/
    # group are what actually consume it, and applying gtk-theme settings
    # is sub-task 7's packaging work.
    if [[ -f "$THEME_DIR/theme.conf" ]]; then
        blue "    theme.conf:"
        sed 's/^/      /' "$THEME_DIR/theme.conf" | grep -v '^\s*#' | grep -v '^\s*$' || true
    fi
fi

# Both groups: theme/ templates only re-render on a theme switch, which is
# exactly what this is.
"$SCRIPT_DIR/apply-templates.sh" --palette "$PALETTE" all
"$SCRIPT_DIR/reload.sh"

if [[ "$MODE" == "wallbash" ]]; then
    notify "Theme applied" "wallbash (from wallpaper)"
    green "✓ wallbash theme applied"
else
    # Remember the active theme so a future session can report it.
    mkdir -p "$cacheDir"
    printf '%s\n' "$THEME" >"$cacheDir/theme.set"
    notify "Theme applied" "$THEME"
    green "✓ theme applied: $THEME"
fi
