#!/usr/bin/env bash
# Apply a colour theme to the desktop.
#
#   theme-apply.sh <name>       use the static palette in themes/<name>/
#   theme-apply.sh --wallbash   re-derive the palette from the current
#                               wallpaper instead of a static theme
#   theme-apply.sh --list       list available themes
#
# Unlike wallpaper.sh this processes BOTH template groups, and additionally
# renders the theme's *identity* — GTK theme name, icons, cursor, font — which
# a wallpaper change cannot touch. That part is not a template: none of it is
# palette-derived, so a .dcol would re-render an identical file on every
# wallpaper change. See apply_identity below and the writers it calls in
# scripts/install-restore-theme-identity.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
THEMES_DIR="$DOTS_DIR/themes"

# manifest_has_path / manifest_append_row for the identity writers below. Same
# arrangement every install-*.sh stage uses, including the ordering: source
# first, define the inline colour helpers after, so this file's definitions are
# the live ones rather than dead code shadowed by global_fn.sh's identical pair
# (see global_fn.sh's own header, and shellcheck SC2329).
# shellcheck source=../global_fn.sh
source "$DOTS_DIR/scripts/global_fn.sh"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# The identity writers are shared with the installer rather than reimplemented:
# one renderer, two entry points. Sourcing it here fixes THEME_CONF_REL at its
# themes/dark default, which apply_identity overrides per switch.
DRY_RUN=0
CONF_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
# shellcheck source=../install-restore-theme-identity.sh
source "$DOTS_DIR/scripts/install-restore-theme-identity.sh"

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

# Render the theme's non-colour half — GTK theme name, icons, cursor, font —
# into settings.ini and xsettingsd.conf, before apply-templates/reload run so
# the reload's `pkill -HUP xsettingsd` serves the new values.
#
# CLOBBER=1 is the only difference from the installer's call: an install must
# not replace a file the user has since edited, whereas a theme switch is
# precisely a request to replace it. The writers still refuse any path the
# manifest does not claim as ours, so a hand-written settings.ini survives
# either caller — it just gets a yellow line saying the identity did not apply.
#
# A theme with no theme.conf is legal: it themes colours only, and the identity
# stays whatever the last theme (or the installer) left.
apply_identity() {
    local theme="$1"
    if [[ ! -f "$THEMES_DIR/$theme/theme.conf" ]]; then
        blue "    no theme.conf — colours only, identity unchanged"
        return 0
    fi
    THEME_CONF_REL="themes/$theme/theme.conf"
    THEME_IDENTITY_CLOBBER=1
    theme_write_gtk_ini
    theme_write_xsettingsd_conf
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
    # theme names, font). Rendered, not just reported — see apply_identity.
    apply_identity "$THEME"
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
