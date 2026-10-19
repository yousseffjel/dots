#!/usr/bin/env bash
# Theme the ly login screen from a static theme's palette.
#
# usage: ly-theme.sh [--dry-run] [<theme>]   write it (default: the active theme)
#        ly-theme.sh [--dry-run] --restore   put ly's original values back
#
# ly reads ONE root-owned file, /etc/ly/config.ini, so this needs sudo. It is
# run by the installer's services stage, by theme-apply.sh on every switch to
# a static theme, and by `dots uninstall` (--restore). Wallbash palettes are
# never written here: they change with every wallpaper, and each change would
# be another root write.
#
# WHAT is written — five keys, edited in place, nothing appended:
#   fg                   = the theme's txt1   (dwm.normfgcolor)     } as console
#   border_fg            = the theme's 1xa7   (dwm.selbordercolor)  } colours
#   bigclock             = en
#   hide_version_string  = true
#   default_input        = password
# default_input is not a colour, but this is the one script that writes ly's
# config. ly's own default, login, puts the cursor on the user line until a
# login has been saved, so on a fresh install's first boot a typed password
# went nowhere and Enter sent an empty one (scope J, J-5).
# The first time a key is changed its original line is saved to
# $XDG_STATE_HOME/dots/ly-config.orig, and --restore writes those lines back.
# A key added here later gets its original appended on the next run, so the
# saved lines never miss one.
# A key ly does not have (a future ly renaming it) is reported and skipped:
# appending an unknown key could stop ly parsing its config at all.
#
# The file is rewritten with `cp` onto the existing one, which keeps its owner
# and mode — `install` or `mv` would put a new file in its place.
#
# Never prompts without a terminal: from a keybinding there is nobody to type
# a password, so it uses `sudo -n` and, when that is refused, says what to run
# and exits 3. DOTS_LY_CONFIG overrides the path (tests).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Colour helpers, MANIFEST_DIR and manifest_append_row.
# shellcheck source=../global_fn.sh
source "$DOTS_DIR/scripts/global_fn.sh"

LY_CONFIG="${DOTS_LY_CONFIG:-/etc/ly/config.ini}"
ORIG="$MANIFEST_DIR/ly-config.orig"
THEME_SET="${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme/theme.set"
# Exit status when a write needs a password and there is no terminal to ask.
EXIT_NEEDS_SUDO=3

usage() {
    sed -n '4,5p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' \
        | sed "s|ly-theme\.sh|${DOTS_CMD:-ly-theme.sh}|g"
}

DRY_RUN=0
RESTORE=0
THEME=""
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --restore) RESTORE=1 ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*)
            red "unknown argument: $arg"
            exit 1
            ;;
        *) THEME="$arg" ;;
    esac
done

# dcol_value <palette> <key> — the bare hex of dcol_<key>.
dcol_value() {
    sed -n "s/^dcol_$2=\"\([0-9A-Fa-f]\{6\}\)\"$/\1/p" "$1"
}

# console_colour <RRGGBB> — the console colour nearest in hue, as the RGB the
# kernel maps exactly to its bright variant.
#
# WHY. ly draws on a Linux VT, which has 16 colours. vt.c's rgb_foreground()
# sets each of red/green/blue only when that component exceeds half the
# largest one, so a soft accent like #9A9AE6 sets all three and is drawn
# WHITE — every shipped theme's border was, on the VM (2026-10-12). Choosing
# by hue keeps the theme's colour family; each value below has exactly one
# component above half the maximum (two for yellow/cyan/magenta) and a
# maximum above 0xAA, which is what vt.c reads as "that colour, bright".
# A colour with little saturation (under 1/5) is white, as the eye sees it.
console_colour() {
    local r=$((16#${1:0:2})) g=$((16#${1:2:2})) b=$((16#${1:4:2})) max min d h
    max=$((r > g ? (r > b ? r : b) : (g > b ? g : b)))
    min=$((r < g ? (r < b ? r : b) : (g < b ? g : b)))
    d=$((max - min))
    if ((d * 5 < max || max == 0)); then
        printf 'FFFFFF\n'
        return 0
    fi
    if ((max == r)); then
        h=$(((60 * (g - b) / d + 360) % 360))
    elif ((max == g)); then
        h=$((120 + 60 * (b - r) / d))
    else
        h=$((240 + 60 * (r - g) / d))
    fi
    # Nearest of the six hues, 60 degrees apart, red first.
    local -a hues=(FF5555 FFFF55 55FF55 55FFFF 5555FF FF55FF)
    printf '%s\n' "${hues[$((((h + 30) / 60) % 6))]}"
}

# set_key <file> <key> <line> — replace the key's line; 1 if ly has no such key.
set_key() {
    grep -q "^$2[[:space:]]*=" "$1" || return 1
    # Escaped for a sed replacement: backslash first, then & and the delimiter.
    local line="${3//\\/\\\\}"
    line="${line//&/\\&}"
    sed -i "s|^$2[[:space:]]*=.*|${line//|/\\|}|" "$1"
}

# pick_sudo — fills SUDO, or returns 1 when nobody can be asked for a password.
pick_sudo() {
    SUDO=()
    if [[ -w "$LY_CONFIG" || $EUID -eq 0 ]]; then
        return 0
    elif [[ -t 0 ]]; then
        SUDO=(sudo)
    elif sudo -n true 2>/dev/null; then
        SUDO=(sudo -n)
    else
        return 1
    fi
}

# save_originals — add to ORIG each ORIGINALS line whose key it lacks. A key
# already there keeps its first line: by now LY_CONFIG holds our own value.
save_originals() {
    local line
    [[ ${#ORIGINALS[@]} -gt 0 ]] || return 0
    mkdir -p "$MANIFEST_DIR"
    for line in "${ORIGINALS[@]}"; do
        grep -q "^${line%%[[:space:]=]*}[[:space:]]*=" "$ORIG" 2>/dev/null \
            || printf '%s\n' "$line" >>"$ORIG"
    done
}

# write_config <rendered> <what> — replace LY_CONFIG with the rendered copy.
write_config() {
    if [[ "$(<"$1")" == "$(<"$LY_CONFIG")" ]]; then
        green "ok      $LY_CONFIG already has $2"
        return 0
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would write $2 to $LY_CONFIG"
        return 0
    fi
    if ! pick_sudo; then
        yellow "login screen not changed: writing $LY_CONFIG needs sudo, and there is no"
        yellow "  terminal to ask in. Run in a terminal:  dots login-theme ${THEME:---restore}"
        exit "$EXIT_NEEDS_SUDO"
    fi
    # Only now, with the write certain: a refused write must not leave an
    # originals file that no manifest row claims.
    save_originals
    "${SUDO[@]}" cp "$1" "$LY_CONFIG"
    green "wrote   $2 -> $LY_CONFIG"
}

if [[ ! -f "$LY_CONFIG" ]]; then
    yellow "no $LY_CONFIG — ly is not installed, nothing to theme"
    exit 0
fi
# The lines a theme replaces, as they were — set below, saved by write_config.
ORIGINALS=()
RENDERED="$(mktemp)"
trap 'rm -f "$RENDERED"' EXIT
cp "$LY_CONFIG" "$RENDERED"

if ((RESTORE)); then
    if [[ ! -f "$ORIG" ]]; then
        blue "no saved ly values ($ORIG) — nothing to restore"
        exit 0
    fi
    while IFS= read -r line; do
        set_key "$RENDERED" "${line%%[[:space:]=]*}" "$line" || true
    done <"$ORIG"
    write_config "$RENDERED" "ly's original values"
    if [[ $DRY_RUN -eq 0 ]]; then rm -f "$ORIG"; fi
    exit 0
fi

if [[ -z "$THEME" ]]; then
    THEME="$(cat "$THEME_SET" 2>/dev/null || true)"
    THEME="${THEME:-dark}"
fi
PALETTE="$DOTS_DIR/themes/$THEME/colors.dcol"
if [[ ! -f "$PALETTE" ]]; then
    red "no palette for theme '$THEME' ($PALETTE)"
    exit 1
fi
fg="$(dcol_value "$PALETTE" txt1)"
border="$(dcol_value "$PALETTE" 1xa7)"
if [[ -z "$fg" || -z "$border" ]]; then
    red "$PALETTE has no dcol_txt1 / dcol_1xa7"
    exit 1
fi
fg="$(console_colour "$fg")"
border="$(console_colour "$border")"

# write_config saves each key's line before its FIRST change only, so a later
# switch never records our own values as "the original". Only keys ly has are kept.
WANT=("fg = 0x00$fg" "border_fg = 0x00$border" "bigclock = en" "hide_version_string = true"
    "default_input = password")
for line in "${WANT[@]}"; do
    key="${line%% *}"
    found="$(grep -m1 "^${key}[[:space:]]*=" "$LY_CONFIG" || true)"
    [[ -n "$found" ]] && ORIGINALS+=("$found")
    set_key "$RENDERED" "$key" "$line" || yellow "skip    '$key' — this ly has no such setting"
done
write_config "$RENDERED" "theme $THEME"
if [[ $DRY_RUN -eq 0 && -f "$ORIG" ]]; then
    manifest_append_row LY "$LY_CONFIG" "$ORIG"
fi
