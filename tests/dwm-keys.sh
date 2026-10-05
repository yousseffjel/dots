#!/usr/bin/env bash
# Exercises config/dwm/bin/dwm-keys with a fake dmenu that records the menu,
# against the REAL KEYBINDINGS.md — and through it, guards that document.
#
# What is asserted:
#   * the list holds rows from both owners (dwm and sxhkd), Mod shown as Alt,
#     with their section names, and nothing from the status-bar table;
#   * EVERY binding in config/sxhkd/sxhkdrc appears in the list. dwm-keys
#     reads KEYBINDINGS.md at runtime, so a key added to sxhkdrc without a
#     row there would silently be missing from the cheat sheet — this is the
#     check that makes the document, which nothing generates, trustworthy;
#   * a missing document is exit 1, never an empty menu.
#
# Not covered: the same completeness check for dwm's config.def.h, whose keys
# are XK_ names inside C arrays and TAGKEYS macros.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SUT="$DOTS_DIR/config/dwm/bin/dwm-keys"
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
MENU="$SB/menu.txt"
export MENU

seal_path "$SB/real" readlink awk cat
mkdir -p "$SB/fake"
# shellcheck disable=SC2016
fake "$SB/fake" dmenu 'cat >"$MENU"'
fake "$SB/fake" notify-send ':'

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}
listed() { grep -qE "$1" "$MENU"; }

blue "the menu"
PATH="$SB/fake:$SB/real" "$(type -P bash)" "$SUT"
check "the menu is not empty (the negative checks below need rows)" test -s "$MENU"
check "a dwm row, Mod shown as Alt" listed '^Alt\+p +dmenu_run'
check "an sxhkd row with its section" listed '^Super\+w .*\[Theming engine\]$'
check "a mouse row" listed '^Alt\+left-drag '
# The status-bar table's first column is a block number (or '#'): that is
# what would leak in as a "key" if a table were not closed at its end.
unlisted() { ! grep -qE "$1" "$MENU"; }
check "no status-bar rows" unlisted '^[0-9#]+ '
check "no table syntax leaks" unlisted '[|`]'

blue "every sxhkdrc binding is listed"
# sxhkd key line -> the spelling KEYBINDINGS.md uses: modifiers capitalised,
# ' + ' joined, keysym names for punctuation turned into the character.
norm() {
    local out="" part
    IFS='+' read -ra parts <<<"${1// /}"
    for part in "${parts[@]}"; do
        case "$part" in
            super | shift | ctrl | alt) part="${part^}" ;;
            slash) part="/" ;;
            period) part="." ;;
            comma) part="," ;;
            minus) part="-" ;;
            equal) part="=" ;;
        esac
        out+="${out:++}$part"
    done
    printf '%s' "$out"
}
n=0
while IFS= read -r key; do
    n=$((n + 1))
    want="$(norm "$key")"
    if ! grep -qF -- "$want " "$MENU"; then
        red "  FAIL  sxhkdrc binds '$key' but KEYBINDINGS.md has no '$want' row"
        FAILS=$((FAILS + 1))
    fi
done < <(grep -E '^[^#[:space:]]' "$DOTS_DIR/config/sxhkd/sxhkdrc")
check "found the sxhkdrc bindings to compare ($n)" test "$n" -ge 20
check "Super+/ (this list) is itself listed" listed '^Super\+/ '

blue "missing document"
rc=0
DWM_KEYS_DOC="$SB/nope.md" PATH="$SB/fake:$SB/real" "$(type -P bash)" "$SUT" 2>/dev/null || rc=$?
check "exit 1" test "$rc" -eq 1

if [[ $FAILS -gt 0 ]]; then
    red "$FAILS check(s) failed"
    exit 1
fi
green "✓ dwm-keys: every sxhkd binding is in the cheat sheet"
