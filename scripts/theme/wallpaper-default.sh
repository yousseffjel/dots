#!/usr/bin/env bash
# Give a static theme a wallpaper of its own, rendered from its palette.
#
#   wallpaper-default.sh <theme> <palette.dcol>
#
# Called by theme-apply.sh on every static-theme apply, BEFORE reload.sh —
# which then runs ~/.fehbg and so puts the result on screen. Not meant to be
# run by hand, but harmless if it is.
#
# WHY GENERATED. This repo deliberately commits no wallpaper images (large
# binaries, and redistribution licences are a question rather than a given —
# see themes/dark/wallpapers/README.md). Until 2026-10-05 that meant a fresh
# install came up on a plain black root window. A gradient rendered from the
# theme's own colours needs no binary in git, carries no licence, and matches
# whichever theme is active.
#
# NEVER OVERRIDES YOURS. ~/.fehbg is claimed only when it is absent, or when
# it already points at a wallpaper this script rendered (so a theme switch
# swaps one generated wallpaper for the next). A ~/.fehbg written by
# wallpaper.sh, or by hand, is left alone and this script does nothing.
set -euo pipefail

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# Rendered once and scaled by `feh --bg-fill`; a two-colour gradient has no
# detail to lose, so one size serves every screen up to 1440p and beyond.
WALLPAPER_SIZE="2560x1440"

THEME="${1:-}"
PALETTE="${2:-}"
if [[ -z "$THEME" || ! -f "$PALETTE" ]]; then
    red "usage: wallpaper-default.sh <theme> <palette.dcol>"
    exit 1
fi

cacheDir="${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme"
WALL_DIR="$cacheDir/wallpapers"
FEHBG="$HOME/.fehbg"

# Written into every ~/.fehbg this script produces. Ownership is decided by
# this line, not by grepping for the image path: the path is shell-quoted in
# the file, so a home directory containing a quote would never match itself.
# scripts/uninstall-theme.sh tests for the same line — keep the two in step.
FEHBG_MARKER="# dots: generated wallpaper"

# Whether ~/.fehbg is ours to (re)write: absent, or carrying the marker.
# wallpaper.sh's ~/.fehbg names an image the user picked and has no marker.
fehbg_is_ours() {
    [[ ! -e "$FEHBG" ]] && return 0
    grep -qxF "$FEHBG_MARKER" "$FEHBG"
}

if ! fehbg_is_ours; then
    blue "wall    ~/.fehbg is your own wallpaper — leaving it"
    exit 0
fi

# One dcol_* value, as the bare 6-digit hex the palette stores.
dcol() {
    local key="$1" val
    # First match only, by quitting sed — not `| head -n 1`, which under
    # pipefail can SIGPIPE sed and fail the whole substitution.
    val="$(sed -n "/^${key}=\"[0-9A-Fa-f]\{6\}\"$/{s/^${key}=\"\(.*\)\"$/\1/p;q;}" "$PALETTE")"
    [[ -n "$val" ]] || return 1
    printf '%s\n' "$val"
}

# pry1 is the theme's background; 1xa2 is a lifted tint of the same hue, so the
# gradient reads as depth rather than as a second colour fighting the bar.
if ! BG="$(dcol dcol_pry1)" || ! TINT="$(dcol dcol_1xa2)"; then
    yellow "wall    $PALETTE lacks dcol_pry1/dcol_1xa2 — no wallpaper generated"
    exit 1
fi

if command -v magick >/dev/null 2>&1; then
    MAGICK=(magick)
elif command -v convert >/dev/null 2>&1; then
    MAGICK=(convert)
else
    yellow "wall    ImageMagick not found — no wallpaper generated"
    exit 1
fi

mkdir -p "$WALL_DIR"
TARGET="$WALL_DIR/$THEME.png"
# Rendered beside the target and renamed into place, so a failed render never
# leaves a truncated PNG for ~/.fehbg to point at.
TMP="$WALL_DIR/.$THEME.png.tmp"
if ! "${MAGICK[@]}" -size "$WALLPAPER_SIZE" -define gradient:direction=SouthEast \
    "gradient:#$TINT-#$BG" "PNG:$TMP"; then
    rm -f "$TMP"
    yellow "wall    ImageMagick failed — no wallpaper generated"
    exit 1
fi
mv -f "$TMP" "$TARGET"

# Same command wallpaper.sh writes, so reload.sh treats both identically —
# but POSIX single-quoted rather than with bash's %q, which emits $'...' for
# unusual characters and that is not /bin/sh syntax (dash rejects it).
sq_target="'${TARGET//\'/\'\\\'\'}'"
printf '#!/bin/sh\n%s\nfeh --no-fehbg --bg-fill %s\n' "$FEHBG_MARKER" "$sq_target" >"$FEHBG"
chmod 755 "$FEHBG"
green "wall    generated $THEME wallpaper -> ${TARGET/#$HOME/\~}"
