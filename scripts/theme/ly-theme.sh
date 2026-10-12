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
# WHAT is written — four keys, edited in place, nothing appended:
#   fg                   = the theme's txt1   (dwm.normfgcolor)
#   border_fg            = the theme's 1xa7   (dwm.selbordercolor)
#   bigclock             = en
#   hide_version_string  = true
# The first time a key is changed its original line is saved to
# $XDG_STATE_HOME/dots/ly-config.orig, and --restore writes those lines back.
# A key ly does not have (a future ly renaming it) is reported and skipped:
# appending an unknown key could stop ly parsing its config at all.
#
# The file is rewritten with `cp` onto the existing one, which keeps its owner,
# mode and SELinux label — `install` or `mv` would replace the label.
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
    if [[ ${#ORIGINALS[@]} -gt 0 && ! -f "$ORIG" ]]; then
        mkdir -p "$MANIFEST_DIR"
        printf '%s\n' "${ORIGINALS[@]}" >"$ORIG"
    fi
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

# write_config saves these before the FIRST change only, so a later switch
# never records our own values as "the original". Only keys ly has are kept.
WANT=("fg = 0x00$fg" "border_fg = 0x00$border" "bigclock = en" "hide_version_string = true")
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
