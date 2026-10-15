#!/usr/bin/env bash
# The Arabic + English font stack (docs/FONTS.md):
#   * every font family the repo names — config/fontconfig/fonts.conf, the
#     dwm/dmenu fonts[] arrays, alacritty, st, and each theme.conf font= —
#     is installed by some packages/*.lst entry. A family nothing installs
#     fails silently everywhere: fontconfig skips a missing <prefer>, Xft
#     substitutes, GTK falls back, and no log anywhere says so;
#   * symlinks.sh links config/fontconfig;
#   * against the REAL fontconfig on this host, with the repo's fonts.conf as
#     the user config: it parses without a single warning, and the generics
#     resolve to the faces it prefers. Each resolution check runs only when
#     the expected family is installed here — the dev host is not Fedora.
#
# Families are read from their sources, never restated. The one hand-written
# table is FAMILY_PKG below, which is knowledge no source in the repo holds:
# which Fedora package registers each family name.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

PASS=0
FAIL=0
ok() {
    green "  ok: $*"
    PASS=$((PASS + 1))
}
bad() {
    red "  FAIL: $*"
    FAIL=$((FAIL + 1))
}

FONTS_CONF="$DOTS_DIR/config/fontconfig/fonts.conf"

# Family name (as fontconfig registers it) -> the Void package that ships
# it, read from the noto-fonts-ttf-2026.10.01_1 file list (2026-10-15):
# one package carries every Noto face below.
declare -A FAMILY_PKG=(
    ["Noto Sans"]="noto-fonts-ttf"
    ["Noto Serif"]="noto-fonts-ttf"
    ["Noto Sans Mono"]="noto-fonts-ttf"
    ["Noto Sans Arabic"]="noto-fonts-ttf"
    ["Noto Naskh Arabic"]="noto-fonts-ttf"
)
# Families no Void package ships and that are not vendored YET. Each one is
# a yellow line, never a pass. Delete an entry when its asset lands.
declare -A FAMILY_PENDING=(
    ["Cascadia Code NF"]="not packaged on Void; vendoring under assets/ is scope I sub-task I-2b (decision D3)"
)
GENERICS=" sans-serif serif monospace "

# --- where families are named -------------------------------------------------

# fonts.conf: every <family>, plus each <string> inside an <edit name="family">
# (the lang=ar prepends). <string>ar</string> sits in a <test>, not an edit.
families_fonts_conf() {
    sed -n 's:.*<family>\([^<]*\)</family>.*:\1:p' "$FONTS_CONF"
    awk '/<edit name="family"/ { e = 1 }
         e && /<string>/ { s = $0; sub(/.*<string>/, "", s); sub(/<\/string>.*/, "", s); print s }
         /<\/edit>/ { e = 0 }' "$FONTS_CONF"
}

# A suckless config.def.h: the quoted entries of fonts[] (one line in dwm,
# several in dmenu), dmenufont, and st's `font`. ":size=..." is dropped.
families_config_h() {
    awk '/fonts\[\][[:space:]]*=/ { a = 1 }
         a || /dmenufont\[\][[:space:]]*=/ || /^static char \*font[[:space:]]*=/ {
             line = $0
             while (match(line, /"[^"]*"/)) {
                 print substr(line, RSTART + 1, RLENGTH - 2)
                 line = substr(line, RSTART + RLENGTH)
             }
         }
         a && /}/ { a = 0 }' "$1" | sed 's/:.*//'
}

all_families() {
    families_fonts_conf
    local h
    for h in "$DOTS_DIR"/suckless/{dwm,dmenu,st}/config.def.h; do
        families_config_h "$h"
    done
    sed -n 's/^family = "\(.*\)"$/\1/p' "$DOTS_DIR/config/alacritty/alacritty.toml"
    # "Noto Sans 10" -> "Noto Sans": GTK font strings end in the point size.
    sed -n 's/^font=\(.*\) [0-9][0-9]*$/\1/p' "$DOTS_DIR"/themes/*/theme.conf
}

# Same parser as read_pkg_list() in scripts/install-pkg-tiers.sh.
declared_pkgs() {
    local f
    for f in "$DOTS_DIR"/packages/*.lst; do
        sed 's/#.*//' "$f" | tr -s '[:space:]' '\n' | grep -v '^$'
    done
}

# --- 1. every named family is packaged ------------------------------------------
blue "==> every font family the repo names is installed by packages/*.lst"
mapfile -t families < <(all_families | sort -u)
# A set, not `printf | grep -q`: under pipefail grep's early exit can SIGPIPE
# the printf and turn a match into a 141.
declare -A DECLARED=()
while IFS= read -r p; do DECLARED["$p"]=1; done < <(declared_pkgs)
if [[ ${#families[@]} -lt 5 ]]; then
    bad "found only ${#families[@]} families — an extractor has stopped matching its source"
fi
for fam in "${families[@]}"; do
    [[ "$GENERICS" == *" $fam "* ]] && continue
    pkg="${FAMILY_PKG[$fam]:-}"
    if [[ -n "${FAMILY_PENDING[$fam]:-}" ]]; then
        yellow "  pending: '$fam' — ${FAMILY_PENDING[$fam]}"
    elif [[ -z "$pkg" ]]; then
        bad "'$fam' has no FAMILY_PKG entry — which package ships it?"
    elif [[ -n "${DECLARED[$pkg]:-}" ]]; then
        ok "'$fam' <- $pkg"
    else
        bad "'$fam' needs $pkg, which no packages/*.lst declares"
    fi
done

# --- 2. deployment ---------------------------------------------------------------
blue "==> symlinks.sh links config/fontconfig"
# shellcheck disable=SC2016 # the literal source line, not an expansion
if grep -qF '"$CONFIG_DIR/fontconfig:$HOME/.config/fontconfig"' "$DOTS_DIR/scripts/symlinks.sh"; then
    ok "config/fontconfig is in LINKS"
else
    bad "config/fontconfig is missing from symlinks.sh's LINKS"
fi

# --- 3. the real fontconfig -------------------------------------------------------
blue "==> fonts.conf under this host's fontconfig"
if ! command -v fc-match >/dev/null 2>&1; then
    yellow "  skip: no fc-match on this host"
else
    SB="$(mktemp -d)"
    trap 'rm -rf "$SB"' EXIT
    mkdir -p "$SB/config" "$SB/cache"
    ln -s "$DOTS_DIR/config/fontconfig" "$SB/config/fontconfig"
    # Both XDG vars: fontconfig reads the user config from the first and
    # writes its cache to the second, which must not be the real one.
    fcm() { XDG_CONFIG_HOME="$SB/config" XDG_CACHE_HOME="$SB/cache" fc-match "$@"; }

    err="$(fcm sans-serif 2>&1 >/dev/null)"
    if [[ -z "$err" ]]; then
        ok "fonts.conf loads without a fontconfig warning"
    else
        bad "fontconfig complained: $err"
    fi

    installed() { [[ -n "$(fc-list "$1" family)" ]]; }
    expect() { # <pattern> <family>
        if ! installed "$2"; then
            yellow "  skip: '$1' -> '$2' ($2 is not installed here)"
            return 0
        fi
        local got
        got="$(fcm "$1" family)"
        if [[ "$got" == "$2" ]]; then
            ok "'$1' -> $2"
        else
            bad "'$1' resolved to '$got', expected '$2'"
        fi
    }
    expect 'sans-serif' 'Noto Sans'
    expect 'serif' 'Noto Serif'
    expect 'monospace' 'Cascadia Code NF'
    expect 'sans-serif:lang=ar' 'Noto Sans Arabic'
    expect 'sans-serif:lang=ar-eg' 'Noto Sans Arabic'
    expect 'serif:lang=ar' 'Noto Naskh Arabic'
    expect 'sans-serif:lang=en' 'Noto Sans'
    # U+0628 BEH is absent from Noto Sans: fallback must take the Arabic face
    # in the alias, not DejaVu Sans or whatever the system ranks next.
    expect 'sans-serif:charset=628' 'Noto Sans Arabic'
    # U+FE91 (BEH initial form) is what fribidi's shaping emits for dwm and
    # dmenu, and Cascadia does not carry it.
    expect 'monospace:charset=fe91' 'Noto Sans Arabic'
fi

echo
if [[ $FAIL -eq 0 ]]; then
    green "fontconfig-stack.sh: $PASS checks passed"
else
    red "fontconfig-stack.sh: $FAIL of $((PASS + FAIL)) checks failed"
    exit 1
fi
