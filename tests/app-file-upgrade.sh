#!/usr/bin/env bash
# Exercises deploy_app_file (scripts/install-restore-apps.sh): when a copied
# app config such as mimeapps.list may be replaced by a newer shipped version.
# Run against a throwaway git repository holding two committed versions of
# config/mimeapps.list, so "matches history" is real git, not a fake.
#
# What is asserted:
#   * absent target: written, and claimed with an APP row;
#   * ours (claimed) and identical to an OLDER committed version: replaced;
#   * ours but edited: kept, byte for byte;
#   * identical to an older version but NOT claimed: kept — not ours;
#   * ours and already current: untouched;
#   * no git history to compare against: kept, never guessed;
#   * --dry-run writes nothing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
R="$TMP/repo" DST="$TMP/home/.config/mimeapps.list"

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}

g() { git -C "$R" -c user.name=t -c user.email=t@t "$@"; }
mkrepo() {
    rm -rf "$R"
    mkdir -p "$R/config"
    git init -q "$R"
    echo "image/png=feh.desktop" >"$R/config/mimeapps.list"
    g add -A && g commit -qm v1
    echo "image/png=nsxiv.desktop" >"$R/config/mimeapps.list"
    g add -A && g commit -qm v2
}

# deploy [dry-run] — deploy_app_file as restore_apps calls it, in a sandboxed
# HOME/XDG tree (all four: HOME alone leaks into the real manifest).
deploy() {
    # shellcheck disable=SC2016 # expanded by the inner bash, not here
    OUT="$(env -i PATH="/usr/bin:/bin" HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" \
        XDG_CONFIG_HOME="$TMP/home/.config" XDG_DATA_HOME="$TMP/data" XDG_CACHE_HOME="$TMP/cache" \
        bash -c '
        set -euo pipefail
        DOTS_DIR="$1" DRY_RUN="$2"
        source "$3/scripts/global_fn.sh"
        source "$3/scripts/install-restore-apps.sh"
        deploy_app_file "$DOTS_DIR/config/mimeapps.list" "$4"
    ' _ "$R" "${1:-0}" "$DOTS_DIR" "$DST" 2>&1)"
}
claim() {
    mkdir -p "$TMP/state/dots"
    printf 'APP\tapp\t%s\n' "$DST" >>"$TMP/state/dots/manifest"
}
fresh() {
    rm -rf "${TMP:?}/home" "${TMP:?}/state"
    mkdir -p "$(dirname "$DST")"
}
# Called only through check's "$@" (both codes: SC2317 before shellcheck 0.10.0).
# shellcheck disable=SC2317,SC2329
is() { [[ "$(<"$DST")" == "$1" ]]; }

mkrepo

blue "==> absent target"
fresh
deploy
check "written" is "image/png=nsxiv.desktop"
check "claimed" grep -qF "$DST" "$TMP/state/dots/manifest"

blue "==> ours, unedited, older"
fresh
echo "image/png=feh.desktop" >"$DST"
claim
deploy 1
check "--dry-run leaves it alone" is "image/png=feh.desktop"
deploy
check "replaced with the current version" is "image/png=nsxiv.desktop"
check "says so" grep -q "updated" <<<"$OUT"

blue "==> ours, edited"
fresh
echo "image/png=gimp.desktop" >"$DST"
claim
deploy
check "kept" is "image/png=gimp.desktop"

blue "==> not ours"
fresh
echo "image/png=feh.desktop" >"$DST"
deploy
check "kept, though it matches an old version" is "image/png=feh.desktop"

blue "==> ours and current"
fresh
echo "image/png=nsxiv.desktop" >"$DST"
claim
deploy
check "reported as already deployed" grep -q "already deployed by us" <<<"$OUT"

blue "==> no history to compare with"
fresh
echo "image/png=feh.desktop" >"$DST"
claim
rm -rf "$R/.git"
deploy
check "kept" is "image/png=feh.desktop"

if [[ $FAILS -eq 0 ]]; then
    green "✓ app files: an unedited old copy is upgraded, anything else is kept"
else
    red "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
