#!/usr/bin/env bash
# Set the wallpaper and re-theme the desktop from it.
#
#   wallpaper.sh <path>       use a specific image
#   wallpaper.sh --random     pick one at random from the wallpaper dir
#   wallpaper.sh --select     pick one from a dmenu list (NOT rofi)
#   wallpaper.sh --initial    pick one at random from the dots collection only
#   wallpaper.sh --login-random on|off|status   a new random one at every login
#
# Pipeline: feh --bg-fill -> colorgen.sh -> apply-templates.sh always ->
# reload.sh. Every stage is a separate script so each is testable and
# replaceable on its own; this is just the user-facing front door.
#
# Wallpaper directory: wallpapers/ inside the XDG pictures dir (`xdg-user-dir
# PICTURES`, so a localised or moved one is honoured; else ~/Pictures),
# overridable with DOTS_WALLPAPER_DIR. The default one is created on first use
# and seeded with the theme's generated wallpaper, so --select and --random
# always have something. The dots collection (install-restore-wallpapers.sh)
# is cloned into a subdirectory of it. --initial is what the installer and the
# first login run: with no collection it does nothing, leaving the theme's
# generated wallpaper in place. --login-random only sets a flag; ~/.xinitrc
# reads it, because a re-theme must happen before dwm starts. Run from a key (sxhkd discards stderr), so every
# failure is also a notification — it used to fail with no visible sign.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# xdg_dir is shared with dwm-screenshot / dwm-record; a missing helper (a
# partial install, or a test's copy of scripts/ alone) means ~/Pictures.
# shellcheck source=../../config/dwm/bin/dwm-lib-xdg.sh
source "$SCRIPT_DIR/../../config/dwm/bin/dwm-lib-xdg.sh" 2>/dev/null || xdg_dir() { printf '%s' "$2"; }
WALLPAPER_DIR="${DOTS_WALLPAPER_DIR:-$(xdg_dir PICTURES "$HOME/Pictures")/wallpapers}"
# For wallpaper_collection_dir alone; its top level only assigns.
# shellcheck source=../install-restore-wallpapers.sh
source "$SCRIPT_DIR/../install-restore-wallpapers.sh" 2>/dev/null \
    || wallpaper_collection_dir() { printf '%s/wallpapers/dots' "$(xdg_dir PICTURES "$HOME/Pictures")"; }
# Must match the path ~/.xinitrc tests (session_xinitrc_template_theme in
# install-session.sh); tests/wallpaper-collection.sh checks the two agree.
LOGIN_RANDOM_FLAG="${XDG_CONFIG_HOME:-$HOME/.config}/dots/random-wallpaper"
cacheDir="${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme"
# shellcheck source=theme-lock.sh # one wallpaper/theme change at a time
source "$SCRIPT_DIR/theme-lock.sh" "${BASH_SOURCE[0]}" "$@"

# Usage text lives in this file's header (lines 4-8), not in a string here, so
# there is one copy. The trailing swap renames it to however it was invoked —
# see the same comment in theme-apply.sh.
usage() {
    sed -n '4,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' \
        | sed "s|wallpaper\.sh|${DOTS_CMD:-wallpaper.sh}|g"
}

notify() {
    # Notifications are a nicety, never a dependency.
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a "dots-theme" -i preferences-desktop-wallpaper "$@" || true
}

# fail <message> [hint] — stderr for a terminal, a notification for a key.
fail() {
    red "$1"
    [[ -z "${2:-}" ]] || yellow "  $2"
    notify -u normal "Wallpaper" "$1${2:+
$2}"
    exit 1
}

# The default dir only: create it and copy in the newest wallpaper the theme
# engine generated (wallpaper-default.sh), if there is one. Never a dir the
# user named with DOTS_WALLPAPER_DIR, never into a dir that already existed.
seed_wallpaper_dir() {
    local f newest=""
    mkdir -p "$WALLPAPER_DIR"
    for f in "$cacheDir"/wallpapers/*.png; do
        [[ -f "$f" ]] || continue
        if [[ -z "$newest" || "$f" -nt "$newest" ]]; then newest="$f"; fi
    done
    [[ -z "$newest" ]] || cp -n "$newest" "$WALLPAPER_DIR/"
}

# Only formats feh can actually set as a background.
list_wallpapers() {
    find -L "$WALLPAPER_DIR" -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
        -o -iname '*.webp' -o -iname '*.bmp' \) 2>/dev/null | sort
}

# --login-random on|off|status. The flag is a file, not a setting inside one,
# so the /bin/sh ~/.xinitrc can test it with [ -e ].
login_random() {
    case "$1" in
        on)
            mkdir -p "$(dirname "$LOGIN_RANDOM_FLAG")"
            : >"$LOGIN_RANDOM_FLAG"
            green "on      a random wallpaper at every login"
            login_random_hint
            ;;
        off)
            rm -f "$LOGIN_RANDOM_FLAG"
            green "off     the last wallpaper is kept at login"
            ;;
        status)
            if [[ -e "$LOGIN_RANDOM_FLAG" ]]; then echo on; else echo off; fi
            ;;
        *)
            red "--login-random takes on, off or status, not: $1"
            exit 1
            ;;
    esac
}

# An ~/.xinitrc from before 2026-10-13 never reads the flag, and the
# installer never rewrites one that exists. Same lines as the template.
# shellcheck disable=SC2016
login_random_hint() {
    grep -qs 'dots/random-wallpaper' "$HOME/.xinitrc" && return 0
    yellow "        ~/.xinitrc does not read it yet. Replace its ~/.fehbg line with:"
    yellow '          if [ -e "${XDG_CONFIG_HOME:-$HOME/.config}/dots/random-wallpaper" ] &&'
    yellow '            timeout 120 "$HOME/.local/bin/dots" wallpaper --random; then :'
    yellow '          elif [ -x "$HOME/.fehbg" ]; then "$HOME/.fehbg"; fi'
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
    --initial) MODE=initial ;;
    --login-random)
        login_random "${2:-status}"
        exit 0
        ;;
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

# The collection only, and quietly absent: the installer and the first login
# call this unconditionally, and without a collection the theme's generated
# wallpaper is the right answer, not an error.
if [[ "$MODE" == "initial" ]]; then
    WALLPAPER_DIR="$(wallpaper_collection_dir)"
    mapfile -t WALLS < <(list_wallpapers)
    if [[ ${#WALLS[@]} -eq 0 ]]; then
        blue "skip    no wallpaper collection at $WALLPAPER_DIR"
        exit 0
    fi
    MODE=random
fi

if [[ "$MODE" != "path" && ! -d "$WALLPAPER_DIR" ]]; then
    if [[ -n "${DOTS_WALLPAPER_DIR:-}" ]]; then
        fail "wallpaper directory not found: $WALLPAPER_DIR" "create it, or unset DOTS_WALLPAPER_DIR"
    fi
    seed_wallpaper_dir
fi

case "$MODE" in
    random)
        mapfile -t WALLS < <(list_wallpapers)
        if [[ ${#WALLS[@]} -eq 0 ]]; then
            fail "no images in $WALLPAPER_DIR" "add some — .jpg .png .webp .bmp"
        fi
        TARGET="${WALLS[RANDOM % ${#WALLS[@]}]}"
        ;;
    select)
        if ! command -v dmenu >/dev/null 2>&1; then
            fail "dmenu not installed — cannot use --select"
        fi
        mapfile -t WALLS < <(list_wallpapers)
        if [[ ${#WALLS[@]} -eq 0 ]]; then
            fail "no images in $WALLPAPER_DIR" "add some — .jpg .png .webp .bmp"
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
            fail "no wallpaper matched: $choice"
        fi
        ;;
esac

if [[ ! -f "$TARGET" ]]; then
    fail "not a file: $TARGET"
fi
TARGET="$(realpath "$TARGET")"

if ! command -v feh >/dev/null 2>&1; then
    fail "feh not installed — cannot set the wallpaper"
fi

blue "==> $TARGET"

# feh writes ~/.fehbg as a side effect; reload.sh re-runs it later to
# repaint the root window after the compositor restarts.
if ! feh --no-fehbg --bg-fill "$TARGET"; then
    fail "feh failed to set the wallpaper"
fi
# --no-fehbg above, then write ~/.fehbg ourselves: feh's own version
# embeds the absolute path with no quoting robustness, and reload.sh
# executes this file on every reload.
#
# POSIX single quotes, not bash's %q: for a control character %q emits
# $'...', which /bin/sh (dash) cannot parse. Same form as
# wallpaper-default.sh, minus its "# dots: generated wallpaper" marker — a
# wallpaper picked here is the user's own and must never be regenerated over.
sq_target="'${TARGET//\'/\'\\\'\'}'"
printf '#!/bin/sh\nfeh --no-fehbg --bg-fill %s\n' "$sq_target" >"$HOME/.fehbg"
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
