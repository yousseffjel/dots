#!/usr/bin/env bash
# Exercises scripts/migrations/0.1.0-to-0.2.0.sh — the stale generated-header
# refresh — in a throwaway git repo, never this one.
#
# What is asserted (scope G decision 1):
#   * a header byte-identical to an OLD committed *.def.h is renamed to
#     <name>.pre-0.2.0, so the next build regenerates it — config.h and
#     dwmblocks' blocks.h alike (found by globbing, never a list);
#   * a header the user edited is kept, with the command to see what to merge;
#   * a header equal to the current *.def.h, or absent, is left alone;
#   * with no git history the header is kept and the user told why;
#   * an existing .pre-0.2.0 backup is never overwritten (exit 1);
#   * a re-run after a refresh is a no-op (idempotent).
# shellcheck disable=SC2016 # the bash -c bodies take $1/$2 as their own arguments
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
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

# A repo whose dwm/config.def.h and bar/blocks.def.h each have an old (v1) and
# a current (v2) committed version, with the migration at its real path.
mkrepo() {
    rm -rf "$R"
    mkdir -p "$R/scripts/migrations" "$R/suckless/dwm" "$R/suckless/bar" "$R/suckless/st"
    cp "$DOTS_DIR/scripts/migrations/0.1.0-to-0.2.0.sh" "$R/scripts/migrations/"
    git -C "$R" init -q
    echo v1 >"$R/suckless/dwm/config.def.h"
    echo blocks-v1 >"$R/suckless/bar/blocks.def.h"
    echo st-v1 >"$R/suckless/st/config.def.h"
    g add -A
    g commit -qm v1
    echo v2 >"$R/suckless/dwm/config.def.h"
    echo blocks-v2 >"$R/suckless/bar/blocks.def.h"
    g add -A
    g commit -qm v2
}
migrate() {
    RC=0
    OUT="$(env -i PATH="/usr/bin:/bin" HOME="$TMP" bash "$R/scripts/migrations/0.1.0-to-0.2.0.sh" 2>&1)" || RC=$?
}

blue "==> an unedited old header is refreshed"
mkrepo
echo v1 >"$R/suckless/dwm/config.h"
echo blocks-v1 >"$R/suckless/bar/blocks.h"
migrate
check "exit 0" test "$RC" -eq 0
check "config.h moved aside" test ! -e "$R/suckless/dwm/config.h"
check "...as config.h.pre-0.2.0, content intact" grep -qx v1 "$R/suckless/dwm/config.h.pre-0.2.0"
check "blocks.h too (found by glob, not a list)" test -f "$R/suckless/bar/blocks.h.pre-0.2.0"
check "says to rebuild" grep -q 'install-suckless.sh --skip-deps' <<<"$OUT"
migrate
check "a re-run is a no-op" bash -c '[[ $1 == 0 && $2 != *refresh* ]]' _ "$RC" "$OUT"

blue "==> an edited header is kept"
mkrepo
printf 'v1\n/* my key */\n' >"$R/suckless/dwm/config.h"
migrate
check "exit 0" test "$RC" -eq 0
check "kept, untouched" grep -q 'my key' "$R/suckless/dwm/config.h"
check "no backup made" test ! -e "$R/suckless/dwm/config.h.pre-0.2.0"
check "names what to merge" grep -q 'diff -u .*suckless/dwm/config.h' <<<"$OUT"

blue "==> current, absent, and no git history"
mkrepo
echo v2 >"$R/suckless/dwm/config.h"
migrate
check "already current: left alone" bash -c '[[ $(cat "$1") == v2 && ! -e "$1.pre-0.2.0" ]]' _ "$R/suckless/dwm/config.h"
check "absent st/config.h: nothing created" test ! -e "$R/suckless/st/config.h.pre-0.2.0"
echo v1 >"$R/suckless/dwm/config.h"
rm -rf "$R/.git"
migrate
check "no git: exit 0" test "$RC" -eq 0
check "...kept" grep -qx v1 "$R/suckless/dwm/config.h"
check "...and says why" grep -q 'no git history' <<<"$OUT"

blue "==> never overwrites a backup"
mkrepo
echo v1 >"$R/suckless/dwm/config.h"
echo older >"$R/suckless/dwm/config.h.pre-0.2.0"
migrate
check "exit 1 (migrate.sh then keeps the manifest at 0.1.0)" test "$RC" -eq 1
check "both files untouched" bash -c '[[ $(cat "$1") == v1 && $(cat "$1.pre-0.2.0") == older ]]' _ "$R/suckless/dwm/config.h"

if ((rc != 0)); then
    red "✗ migration 0.1.0 -> 0.2.0"
    exit 1
fi
green "✓ migration 0.1.0 -> 0.2.0: refresh unedited, keep edited, never overwrite"
