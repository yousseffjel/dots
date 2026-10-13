#!/usr/bin/env bash
# Exercises scripts/install-suckless-headers.sh — the build-time refresh of a
# generated suckless header (config.h, blocks.h) that is stale but unedited —
# in a throwaway git repo, never this one.
#
# What is asserted (scope G decision 1's rule, run on every build):
#   * a header byte-identical to an OLD committed *.def.h is renamed to
#     <name>.pre-<timestamp>, content intact, so make regenerates it;
#   * every *.def.h in the program dir is covered (config.h and blocks.h);
#   * a header the user edited is kept, with the diff command to merge by;
#   * a header equal to the current *.def.h, or absent, is left alone;
#   * --dry-run reports the refresh and renames nothing;
#   * with no git history the header is kept and the user told why;
#   * a second run after a refresh is a no-op;
#   * install-suckless.sh calls it inside the build loop, before make.
# shellcheck disable=SC2016 # the bash -c bodies take $1 as their own argument
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUT="$DOTS_DIR/scripts/install-suckless-headers.sh"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

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

R="$TMP/repo"
g() { git -C "$R" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@" >/dev/null; }

# dwm/ has config.def.h and blocks.def.h, each committed as v1 then v2.
mkrepo() {
    rm -rf "$R"
    mkdir -p "$R/suckless/dwm"
    git -C "$R" init -q
    echo v1 >"$R/suckless/dwm/config.def.h"
    echo blocks-v1 >"$R/suckless/dwm/blocks.def.h"
    g add -A
    g commit -qm v1
    echo v2 >"$R/suckless/dwm/config.def.h"
    echo blocks-v2 >"$R/suckless/dwm/blocks.def.h"
    g add -A
    g commit -qm v2
}
# refresh [dry-run 0|1] — the function as install-suckless.sh calls it, in a
# subshell so its `exit` and globals stay there. HOME is pointed away so no
# user git config can change what git reports.
refresh() {
    OUT="$(env -i PATH="/usr/bin:/bin" HOME="$TMP" bash -c '
        set -euo pipefail
        DOTS_DIR="$1" DRY_RUN="$2"
        # global_fn.sh for file_matches_history; its colour helpers are then
        # replaced by plain ones so the assertions match uncoloured text.
        source "$4"
        red() { printf "%s\n" "$*"; }; green() { red "$@"; }
        yellow() { red "$@"; }; blue() { red "$@"; }
        source "$3"
        refresh_generated_headers "$DOTS_DIR/suckless/dwm"
    ' _ "$R" "${1:-0}" "$SUT" "$DOTS_DIR/scripts/global_fn.sh" 2>&1)"
}
backups() { compgen -G "$R/suckless/dwm/$1.pre-*" || true; }

blue "==> unedited and stale: refreshed"
mkrepo
echo v1 >"$R/suckless/dwm/config.h"
echo blocks-v1 >"$R/suckless/dwm/blocks.h"
refresh 1
check "--dry-run says it would refresh" grep -q "would refresh suckless/dwm/config.h" <<<"$OUT"
check "--dry-run renamed nothing" bash -c '[[ -f "$1/config.h" && -z $(compgen -G "$1/config.h.pre-*") ]]' _ "$R/suckless/dwm"
refresh
check "config.h moved aside" test ! -e "$R/suckless/dwm/config.h"
check "...as config.h.pre-<timestamp>, content intact" grep -qx v1 "$(backups config.h)"
check "blocks.h too (every *.def.h, by glob)" grep -qx blocks-v1 "$(backups blocks.h)"
refresh
check "a second run is a no-op" test -z "$OUT"

blue "==> edited: kept"
mkrepo
echo mine >"$R/suckless/dwm/config.h"
refresh
check "kept in place" grep -qx mine "$R/suckless/dwm/config.h"
check "no backup made" test -z "$(backups config.h)"
check "the merge command is printed" grep -q "diff -u $R/suckless/dwm/config.h" <<<"$OUT"

blue "==> current, or absent: untouched"
mkrepo
echo v2 >"$R/suckless/dwm/config.h"
refresh
check "already current: left alone, silently" bash -c '[[ $(cat "$1") == v2 && -z $(compgen -G "$1.pre-*") ]]' _ "$R/suckless/dwm/config.h"
check "absent blocks.h: nothing created" test ! -e "$R/suckless/dwm/blocks.h"
check "nothing printed" test -z "$OUT"

blue "==> no git history: kept, and said why"
mkrepo
rm -rf "$R/.git"
echo v1 >"$R/suckless/dwm/config.h"
refresh
check "kept" grep -qx v1 "$R/suckless/dwm/config.h"
check "told there is no history" grep -q "no git history" <<<"$OUT"

blue "==> wired into the build loop, before make"
INSTALL="$DOTS_DIR/scripts/install-suckless.sh"
call="$(grep -n 'refresh_generated_headers "$dir"' "$INSTALL" | cut -d: -f1)"
make_line="$(grep -n 'make -C "$dir"$' "$INSTALL" | cut -d: -f1)"
loop="$(grep -n 'for prog in "${PROGRAMS\[@\]}"' "$INSTALL" | cut -d: -f1)"
check "install-suckless.sh calls it after the loop starts and before make" \
    test -n "$call" -a -n "$make_line" -a -n "$loop" -a "${loop:-0}" -lt "${call:-0}" -a "${call:-0}" -lt "${make_line:-0}"

if ((rc)); then
    red "✗ suckless header refresh"
    exit 1
fi
green "✓ suckless header refresh: refresh unedited, keep edited, dry-run renames nothing"
