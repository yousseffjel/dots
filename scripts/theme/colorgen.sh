#!/usr/bin/env bash
# Dark-mode-only wallpaper color extraction, ImageMagick only. Produces a
# HyDE-wallbash-compatible dcol palette (dcol_pry1-4, dcol_txt1-4,
# dcol_NxaJ accent shades J=1-9, every color's plain "R,G,B,255" *_rgba
# sibling). Algorithm follows HyDE-Project/HyDE's wallbash.sh (read as a
# design reference only — never sourced/shelled-out-to at runtime, see
# CLAUDE.md rule 9), simplified to one fixed dark-mode curve (no light/
# vibrant/pastel/mono/--custom profiles, no video wallpapers) and sorted
# by real perceptual luminance rather than upstream's hex-lexicographic
# sort. Full rationale: .claude/changes/2026-08-05-theming-colorgen.md
#
# Usage: colorgen.sh <wallpaper> [--force]
set -euo pipefail

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

usage() {
    echo "usage: colorgen.sh <wallpaper> [--force]"
    echo "  --force   regenerate even if the wallpaper+mtime cache matches"
}

WALLPAPER=""
FORCE=0
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*)
            red "unknown argument: $arg"
            usage
            exit 1
            ;;
        *) WALLPAPER="$arg" ;;
    esac
done

if [[ -z "$WALLPAPER" ]]; then
    red "no wallpaper given"
    usage
    exit 1
fi
if [[ ! -f "$WALLPAPER" ]]; then
    red "wallpaper not found: $WALLPAPER"
    exit 1
fi

MAGICK=""
if command -v magick >/dev/null 2>&1; then
    MAGICK="magick"
elif command -v convert >/dev/null 2>&1; then
    MAGICK="convert"
else
    red "ImageMagick not found (need 'magick' or 'convert' on PATH)"
    exit 1
fi

WALLPAPER="$(realpath "$WALLPAPER")"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme"
CACHE_FILE="$CACHE_DIR/colors.dcol"
mkdir -p "$CACHE_DIR"

# --- cache check -------------------------------------------------------------
# Key = sha256(wallpaper path + mtime) — any edit to the file, or pointing
# at a different file, invalidates the cache; re-running on the same
# unchanged wallpaper is instant.
WALL_MTIME="$(stat -c '%Y' "$WALLPAPER")"
CACHE_KEY="$(printf '%s:%s' "$WALLPAPER" "$WALL_MTIME" | sha256sum | cut -d' ' -f1)"

if [[ $FORCE -eq 0 && -f "$CACHE_FILE" ]]; then
    if grep -qxF "# dcol_cache_key=$CACHE_KEY" "$CACHE_FILE" 2>/dev/null; then
        green "cache hit — $CACHE_FILE already matches $WALLPAPER"
        exit 0
    fi
fi

blue "==> extracting colors from $WALLPAPER"

RAW_TMP="$(mktemp --suffix=.png)"
trap 'rm -f "$RAW_TMP"' EXIT

# Flatten to a plain sRGB working copy — strips alpha/animation frames so
# every later magick call sees one flat image.
"$MAGICK" -quiet -regard-warnings "${WALLPAPER}[0]" -alpha off +repage "$RAW_TMP"

# --- extract dominant colors --------------------------------------------------
NEEDED=4
FUZZ=70
extract_colors() {
    local n="$1"
    "$MAGICK" "$RAW_TMP" -depth 8 -fuzz "${FUZZ}%" +dither -kmeans "$n" -depth 8 \
        -format "%c" histogram:info: \
        | sed -n 's/^[[:space:]]*\([0-9]*\):.*#\([0-9A-Fa-f]\{6\}\).*$/\1,\2/p' \
        | sort -r -n -t, -k1
}

mapfile -t RAW_COLORS < <(extract_colors "$NEEDED")
if [[ ${#RAW_COLORS[@]} -lt $NEEDED ]]; then
    yellow "  only ${#RAW_COLORS[@]} distinct colors at kmeans=$NEEDED, retrying with $((NEEDED + 2))"
    mapfile -t RAW_COLORS < <(extract_colors "$((NEEDED + 2))")
fi

CANDIDATES=()
for entry in "${RAW_COLORS[@]}"; do
    CANDIDATES+=("${entry#*,}")
done

# Pad with brightness-shifted variants of the last candidate if the
# wallpaper is too flat (e.g. a solid color) to yield 4 distinct clusters.
while [[ ${#CANDIDATES[@]} -lt $NEEDED ]]; do
    last="${CANDIDATES[-1]:-1E1E2E}"
    shift_pct=$((30 + 15 * ${#CANDIDATES[@]}))
    padded="$("$MAGICK" xc:"#$last" -depth 8 -modulate "$shift_pct",100,100 -depth 8 \
        -format "%c" histogram:info: \
        | sed -n 's/^[[:space:]]*[0-9]*:.*#\([0-9A-Fa-f]\{6\}\).*$/\1/p')"
    CANDIDATES+=("${padded:-$last}")
done
CANDIDATES=("${CANDIDATES[@]:0:$NEEDED}")

# --- sort by real perceptual luminance, darkest first -------------------------
luminance() {
    "$MAGICK" xc:"#$1" -colorspace gray -format "%[fx:mean]" info:
}

SORT_INPUT=""
for hex in "${CANDIDATES[@]}"; do
    SORT_INPUT+="$(luminance "$hex") $hex"$'\n'
done
mapfile -t PRY < <(printf '%s' "$SORT_INPUT" | sort -n | awk '{print $2}')

# --- dark-mode floor on dcol_pry1 ---------------------------------------------
# Never ship a light background: if the darkest extracted candidate is
# still above the threshold (a light-dominant wallpaper), darken it in
# place. Bounded loop — each pass multiplies brightness by 60%, so this
# always converges (pure white -> ~7% of original after 4 passes).
DARK_LUMINANCE_THRESHOLD="0.35"
pass=0
while awk -v l="$(luminance "${PRY[0]}")" -v t="$DARK_LUMINANCE_THRESHOLD" 'BEGIN{exit !(l>t)}' && [[ $pass -lt 4 ]]; do
    yellow "  dcol_pry1 (#${PRY[0]}) is too light for dark mode — darkening"
    PRY[0]="$("$MAGICK" xc:"#${PRY[0]}" -depth 8 -modulate 60,100,100 -depth 8 \
        -format "%c" histogram:info: \
        | sed -n 's/^[[:space:]]*[0-9]*:.*#\([0-9A-Fa-f]\{6\}\).*$/\1/p')"
    pass=$((pass + 1))
done

# --- monochrome check (flat curve if the wallpaper has ~no saturation) -------
GREY_MEAN="$("$MAGICK" "$RAW_TMP" -colorspace HSL -channel g -separate +channel -format "%[fx:mean]" info:)"
if awk -v g="$GREY_MEAN" 'BEGIN{exit !(g<0.12)}'; then
    yellow "  near-monochrome wallpaper — accent shades desaturated"
    ACCENT_CURVE="10 0
17 0
24 0
39 0
51 0
58 0
72 0
84 0
99 0"
else
    ACCENT_CURVE="32 50
42 46
49 40
56 39
64 38
76 37
90 33
94 29
100 20"
fi

# --- helpers -------------------------------------------------------------------
hex_negative() {
    local hex="$1"
    printf '%02X%02X%02X' \
        $((255 - 16#${hex:0:2})) \
        $((255 - 16#${hex:2:2})) \
        $((255 - 16#${hex:4:2}))
}

rgba_line() {
    local hex="$1"
    printf '%d,%d,%d,255' "$((16#${hex:0:2}))" "$((16#${hex:2:2}))" "$((16#${hex:4:2}))"
}

hsb_color() {
    local hue="$1" sat="$2" bri="$3"
    "$MAGICK" xc:"hsb($hue,$sat%,$bri%)" -depth 8 -format "%c" histogram:info: \
        | sed -n 's/^[[:space:]]*[0-9]*:.*#\([0-9A-Fa-f]\{6\}\).*$/\1/p'
}

# --- build the palette ---------------------------------------------------------
OUT_TMP="$(mktemp)"
{
    echo "# dcol_cache_key=$CACHE_KEY"
    echo "dcol_mode=\"dark\""

    for i in 0 1 2 3; do
        idx=$((i + 1))
        pry="${PRY[$i]}"
        echo "dcol_pry${idx}=\"$pry\""
        echo "dcol_pry${idx}_rgba=\"$(rgba_line "$pry")\""

        # Text color: invert the primary, then brightness-boost — every
        # primary here is dark by construction, so this always lightens.
        txt="$("$MAGICK" xc:"#$(hex_negative "$pry")" -depth 8 -modulate 188,10,100 -depth 8 \
            -format "%c" histogram:info: \
            | sed -n 's/^[[:space:]]*[0-9]*:.*#\([0-9A-Fa-f]\{6\}\).*$/\1/p')"
        # Safety floor beyond upstream: force a known-readable light gray
        # if the derived text color still isn't light enough to read.
        if awk -v l="$(luminance "$txt")" 'BEGIN{exit !(l<0.5)}'; then
            txt="E8E8E8"
        fi
        echo "dcol_txt${idx}=\"$txt\""
        echo "dcol_txt${idx}_rgba=\"$(rgba_line "$txt")\""

        hue="$("$MAGICK" xc:"#$pry" -colorspace HSB -format "%c" histogram:info: \
            | awk -F '[hsb(,]' '{print $2}')"
        acnt=1
        while read -r xbri xsat; do
            [[ -z "$xbri" ]] && continue
            acol="$(hsb_color "$hue" "$xsat" "$xbri")"
            echo "dcol_${idx}xa${acnt}=\"$acol\""
            echo "dcol_${idx}xa${acnt}_rgba=\"$(rgba_line "$acol")\""
            acnt=$((acnt + 1))
        done <<<"$ACCENT_CURVE"
    done
} >"$OUT_TMP"

mv "$OUT_TMP" "$CACHE_FILE"
green "✓ wrote $CACHE_FILE (dcol_pry1=#${PRY[0]} .. dcol_pry4=#${PRY[3]})"
