#!/usr/bin/env bash
# scripts/theme/wallpaper-default.sh — the wallpaper a static theme renders
# from its own palette (added 2026-10-05; a fresh install used to come up on a
# black root window, because this repo commits no wallpaper images).
#
# The property that matters most is the negative one: a ~/.fehbg the user set
# themselves is NEVER replaced. Then: the gradient comes from the palette's
# own keys, a theme switch swaps one generated wallpaper for the next, a
# failed render leaves nothing half-written, and theme-apply.sh calls it
# before reload.sh (which is what puts ~/.fehbg on screen).
#
# HOW. The script is RUN on a sealed PATH (tests/lib/sealed-path.sh) with a
# fake magick/convert that logs its arguments and writes the output file, in a
# sandbox HOME with all four XDG variables set. When a real ImageMagick is
# present, one extra case renders for real and checks the PNG's size. The
# theme-apply.sh case runs a sandbox COPY of scripts/ whose apply-templates.sh
# and reload.sh are fakes: the real ones pkill daemons on the live desktop.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SRC="$DOTS_DIR/scripts/theme/wallpaper-default.sh"
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

TOOLS=(bash sed grep mkdir mv rm chmod)
seal_path "$SB/base" "${TOOLS[@]}"

rc=0
check() {
    local name="$1"
    shift
    if "$@"; then
        green "  ok: $name"
    else
        red "  FAIL: $name"
        rc=1
    fi
}

# Inverts a command in THIS shell, so it can wrap the run() function.
fails() { ! "$@"; }
no_tmp() {
    local f
    for f in "$1"/.*.tmp; do
        [[ -e "$f" ]] && return 1
    done
    return 0
}
dir_empty() { [[ -z "$(ls -A "$1" 2>/dev/null)" ]]; }
# Reads geometry with the identify the real-render case selected (ID).
is_png_2560() { [[ "$("${ID[@]}" -format '%m %wx%h' "$1")" == "PNG 2560x1440" ]]; }

# new_case <name> <magick mode: magick|convert|fail|none> — a fresh HOME and
# bin dir. Sets H (home), BIN, LOG.
new_case() {
    H="$SB/$1/home"
    BIN="$SB/$1/bin"
    LOG="$SB/$1/calls.log"
    mkdir -p "$H" "$BIN"
    : >"$LOG"
    cp -P "$SB/base"/* "$BIN/"
    # The fake writes its LAST argument ("PNG:<path>") as the output file,
    # the way the real one does.
    local body
    # shellcheck disable=SC2016
    body='echo "${0##*/} $*" >>"'"$LOG"'"; out="${*: -1}"; printf PNG >"${out#PNG:}"'
    # The fakes' own $-expressions belong to them, not to this script.
    # shellcheck disable=SC2016
    case "$2" in
        magick) fake "$BIN" magick "$body" ;;
        convert) fake "$BIN" convert "$body" ;;
        # Fails MIDWAY, leaving a partial file, as a real render can.
        fail) fake "$BIN" magick 'out="${*: -1}"; printf PN >"${out#PNG:}"; echo "magick: unable to render" >&2; exit 1' ;;
        none) ;;
    esac
}

run() {
    env -i PATH="$BIN" HOME="$H" XDG_CACHE_HOME="$H/.cache" \
        XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
        XDG_DATA_HOME="$H/.local/share" bash "$SRC" "$@" >/dev/null 2>&1
}

WALLS=".cache/dots/theme/wallpapers"
DARK="$DOTS_DIR/themes/dark/colors.dcol"
NORD="$DOTS_DIR/themes/nord/colors.dcol"
pry1() { sed -n 's/^dcol_pry1="\(.*\)"$/\1/p' "$1"; }
xa2() { sed -n 's/^dcol_1xa2="\(.*\)"$/\1/p' "$1"; }

blue "==> no wallpaper yet: generate and claim ~/.fehbg"
new_case fresh magick
check "exits 0" run dark "$DARK"
check "renders the palette's 1xa2 -> pry1 gradient" \
    grep -qF "gradient:#$(xa2 "$DARK")-#$(pry1 "$DARK")" "$LOG"
check "writes the target" test -s "$H/$WALLS/dark.png"
check ".fehbg points at it" grep -qF "$H/$WALLS/dark.png" "$H/.fehbg"
check ".fehbg is executable" test -x "$H/.fehbg"
check "no temp file left" no_tmp "$H/$WALLS"

blue "==> theme switch: a generated wallpaper is replaced by the next"
check "exits 0" run nord "$NORD"
check ".fehbg now points at nord" grep -qF "$H/$WALLS/nord.png" "$H/.fehbg"
check "renders nord's colours" grep -qF "gradient:#$(xa2 "$NORD")-#$(pry1 "$NORD")" "$LOG"

blue "==> a home path with a space, a quote, a dollar sign and a tab"
new_case "odd it's \$x$(printf '\t')tab" magick
check "exits 0" run dark "$DARK"
check "no bash-only \$'...' quoting in .fehbg" fails grep -qF "\$'" "$H/.fehbg"
# The fake's own $@ belongs to it, not to this script.
# shellcheck disable=SC2016
fake "$BIN" feh 'printf "%s\n" "${@: -1}" >"'"$SB/feh.arg"'"'
check ".fehbg runs under /bin/sh" env -i PATH="$BIN" HOME="$H" /bin/sh "$H/.fehbg"
check "feh receives the exact path" grep -qxF "$H/$WALLS/dark.png" "$SB/feh.arg"
check "a re-run still recognises it as generated" run nord "$NORD"
check ".fehbg moved on to nord" grep -qF "nord.png" "$H/.fehbg"

blue "==> the user's own wallpaper is never replaced"
new_case own magick
printf '#!/bin/sh\nfeh --no-fehbg --bg-fill %s\n' "$H/Pictures/mine.jpg" >"$H/.fehbg"
cp "$H/.fehbg" "$SB/own.fehbg"
check "exits 0" run dark "$DARK"
check ".fehbg unchanged" cmp -s "$H/.fehbg" "$SB/own.fehbg"
check "ImageMagick never called" test ! -s "$LOG"
printf '#!/bin/sh\nfeh --no-fehbg --bg-fill %s\n' "'$H/$WALLS/dark.png'" >"$H/.fehbg"
cp "$H/.fehbg" "$SB/own.fehbg"
check "even one naming a generated image, without the marker" run nord "$NORD"
check ".fehbg still unchanged" cmp -s "$H/.fehbg" "$SB/own.fehbg"

blue "==> failures leave nothing behind"
new_case fail fail
check "render failure exits non-zero" fails run dark "$DARK"
check "no .fehbg written" test ! -e "$H/.fehbg"
check "no target or temp file" dir_empty "$H/$WALLS"
new_case none none
check "no ImageMagick exits non-zero" fails run dark "$DARK"
check "no .fehbg written" test ! -e "$H/.fehbg"
new_case badpal magick
printf 'dcol_mode="dark"\n' >"$SB/bad.dcol"
check "palette without the keys exits non-zero" fails run dark "$SB/bad.dcol"
check "ImageMagick never called" test ! -s "$LOG"

blue "==> IM6 fallback"
new_case im6 convert
check "uses convert when magick is absent" run dark "$DARK"
check "convert was the one called" grep -q '^convert ' "$LOG"

blue "==> theme-apply.sh generates it before reload.sh runs ~/.fehbg"
REPO="$SB/repo"
mkdir -p "$REPO"
cp -r "$DOTS_DIR/scripts" "$DOTS_DIR/themes" "$REPO/"
# shellcheck disable=SC2016
printf '#!/bin/sh\necho "apply-templates $*" >>"$LOG"\n' >"$REPO/scripts/theme/apply-templates.sh"
# The fake reload records whether ~/.fehbg already exists when it runs.
# shellcheck disable=SC2016
printf '#!/bin/sh\nif [ -x "$HOME/.fehbg" ]; then echo "reload fehbg=yes" >>"$LOG"; else echo "reload fehbg=no" >>"$LOG"; fi\n' \
    >"$REPO/scripts/theme/reload.sh"
new_case apply magick
fake "$BIN" notify-send ':'
check "theme-apply.sh dark exits 0" env -i PATH="$BIN:/usr/bin:/bin" LOG="$LOG" HOME="$H" \
    XDG_CACHE_HOME="$H/.cache" XDG_CONFIG_HOME="$H/.config" \
    XDG_STATE_HOME="$H/.local/state" XDG_DATA_HOME="$H/.local/share" \
    bash "$REPO/scripts/theme/theme-apply.sh" dark
check "reload.sh found .fehbg already written" grep -qx 'reload fehbg=yes' "$LOG"
check "the wallpaper is the dark one" grep -qF "$H/$WALLS/dark.png" "$H/.fehbg"

if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
    blue "==> real ImageMagick render"
    new_case real none
    for t in magick convert; do
        real="$(type -P "$t" || true)"
        if [[ -n "$real" ]]; then ln -sf "$real" "$BIN/$t"; fi
    done
    # IM7 reads geometry with `magick identify`; IM6 ships a separate identify.
    if [[ -e "$BIN/magick" ]]; then ID=("$BIN/magick" identify); else ID=("$(type -P identify)"); fi
    check "renders with the real binary" run dark "$DARK"
    check "is a 2560x1440 PNG" is_png_2560 "$H/$WALLS/dark.png"
else
    blue "==> real ImageMagick render: SKIPPED (not installed)"
fi

if ((rc != 0)); then
    red "✗ wallpaper-default"
    exit 1
fi
green "✓ wallpaper-default"
