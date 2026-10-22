#!/usr/bin/env bash
# tests/lib/dwm-build-fresh.sh: dwm-runtime.sh and dwm-multimon.sh run the
# BUILT suckless/dwm/dwm, and nothing rebuilds it between a source change and
# a local test run. On 2026-10-22 main's binary was three days older than
# dwm.c (the statusallmons and replug slots had built their own in their
# worktrees), and dwm-multimon.sh failed five checks against code that was
# correct. The same stale binary would PASS a regression made to dwm.c after
# it was built. CI is unaffected (it builds first); this guards local runs.
#
# dwm_build_stale is exercised on a fake build directory with set mtimes:
# no compiler, no X.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }

# shellcheck source=lib/dwm-build-fresh.sh
source "$SCRIPT_DIR/lib/dwm-build-fresh.sh"

TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
rc=0
check() {
    local name="$1" want="$2" got="$3"
    if [[ "$got" == "$want" ]]; then green "  ok: $name"; else
        red "  FAIL: $name"
        red "        want: $want"
        red "        got:  $got"
        rc=1
    fi
}

D="$TMP/dwm"
# A build as `make` leaves it: sources, then config.h, then the binary.
fresh() {
    rm -rf -- "$D"
    mkdir -p "$D"
    local f
    for f in dwm.c drw.c drw.h util.c config.def.h config.mk Makefile; do
        : >"$D/$f"
        touch -d '2026-10-01 10:00' "$D/$f"
    done
    : >"$D/config.h" && touch -d '2026-10-01 10:01' "$D/config.h"
    : >"$D/dwm" && touch -d '2026-10-01 10:02' "$D/dwm"
}
# stale_of: the helper's output and status, as one string.
stale_of() {
    local out st=0
    out="$(dwm_build_stale "$D/dwm")" || st=$?
    printf '%s|%s' "$st" "$out"
}

fresh
check "a fresh build is not stale" "1|" "$(stale_of)"

fresh
touch -d '2026-10-02 10:00' "$D/dwm.c"
check "dwm.c newer than the binary: rebuild" "0|dwm.c is newer than the built dwm: run  make -C $D" "$(stale_of)"

fresh
touch -d '2026-10-02 10:00' "$D/drw.h"
check "a header too" "0|drw.h is newer than the built dwm: run  make -C $D" "$(stale_of)"

fresh
touch -d '2026-10-02 10:00' "$D/config.mk"
check "config.mk too" "0|config.mk is newer than the built dwm: run  make -C $D" "$(stale_of)"

fresh
touch -d '2026-10-02 10:00' "$D/Makefile"
check "the Makefile too" "0|Makefile is newer than the built dwm: run  make -C $D" "$(stale_of)"

# make never regenerates config.h (its rule has no prerequisite), so a
# rebuild alone would compile the old config.
fresh
touch -d '2026-10-02 10:00' "$D/config.def.h"
check "config.def.h newer than config.h: remove it first" \
    "0|config.def.h is newer than config.h, which make never regenerates: run  rm $D/config.h && make -C $D" "$(stale_of)"

fresh
rm "$D/config.h"
touch -d '2026-10-02 10:00' "$D/config.def.h"
check "no config.h: make creates it, a rebuild is enough" \
    "0|config.def.h is newer than the built dwm: run  make -C $D" "$(stale_of)"

# Built objects and backups beside the sources are not sources.
fresh
: >"$D/dwm.o" && touch -d '2026-10-02 10:00' "$D/dwm.o"
: >"$D/config.h.pre-0.2.0" && touch -d '2026-10-02 10:00' "$D/config.h.pre-0.2.0"
check "an object file or a backup is not a source" "1|" "$(stale_of)"

# Only the build directory itself is built: a subdirectory (patches/ is a
# record, CLAUDE.md rule 5) holds no source of this binary.
fresh
mkdir -p "$D/patches/upstream" && : >"$D/patches/upstream/dwm.c" && touch -d '2026-10-02 10:00' "$D/patches/upstream/dwm.c"
check "a .c in a subdirectory is not a source" "1|" "$(stale_of)"

if [[ $rc -eq 0 ]]; then
    green "✓ dwm build freshness: a binary older than its sources or config is named, with the rebuild"
fi
exit "$rc"
