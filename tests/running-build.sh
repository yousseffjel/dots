#!/usr/bin/env bash
# Exercises scripts/running-build.sh against a fake proc root (DOTS_PROC):
# a running dwm or dwmblocks whose binary an install replaced.
#
# What is asserted:
#   * replaced AND different content is stale; an identical rebuild, a
#     binary never replaced, one removed outright, and a process with
#     another name are not;
#   * DOTS_PROC is read at call time (set after sourcing, as here);
#   * running_build_report prints the restart hint for each stale program
#     and nothing at all when none is;
#   * both installers end with the report (it is the last thing a
#     `dots update` prints, so a buried hint is no hint).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '%s\n' "$*"; }
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

# shellcheck source=../scripts/running-build.sh
source "$DOTS_DIR/scripts/running-build.sh"
DOTS_PROC="$TMP/proc"

# fakeproc <pid> <comm> <running content> [<content now at the path>|-]
# The exe link reads "... (deleted)" unless the 4th argument is "-", which
# models a binary never replaced (the link points at the live file).
fakeproc() {
    local dir="$DOTS_PROC/$1" bin="$TMP/bin/$2"
    mkdir -p "$dir" "$TMP/bin"
    echo "$2" >"$dir/comm"
    if [[ "${4:--}" == - ]]; then
        echo "$3" >"$bin"
        ln -sfn "$bin" "$dir/exe"
    else
        echo "$3" >"$bin (deleted)"
        echo "$4" >"$bin"
        ln -sfn "$bin (deleted)" "$dir/exe"
    fi
}
reset() { rm -rf "${DOTS_PROC:?}" "${TMP:?}/bin" && mkdir -p "$DOTS_PROC"; }
not() { ! "$@"; }

blue "==> running_build_stale"
reset
check "no processes: not stale" not running_build_stale dwm
fakeproc 100 dwm old new
check "replaced and different: stale" running_build_stale dwm
check "...only for its own name" not running_build_stale dwmblocks
reset
fakeproc 100 dwm same same
check "replaced but identical (unchanged sources): not stale" not running_build_stale dwm
reset
fakeproc 100 dwm current -
check "never replaced: not stale" not running_build_stale dwm
reset
fakeproc 100 dwmblocks old new
fakeproc 101 dwm current -
check "the stale one is found among others" running_build_stale dwmblocks
check "...and the current one is not" not running_build_stale dwm
reset
fakeproc 100 dwm old new
rm "$TMP/bin/dwm"
check "binary removed outright (uninstall): not stale, no restart into nothing" not running_build_stale dwm
reset
mkdir -p "$DOTS_PROC/self"
check "non-numeric proc entries are ignored" not running_build_stale dwm

blue "==> running_build_report"
reset
check "nothing stale: prints nothing" test -z "$(running_build_report)"
fakeproc 100 dwmblocks old new
out="$(running_build_report)"
check "names dwmblocks" grep -q 'dwmblocks is still running the build from before' <<<"$out"
check "...with its restart command" grep -qF 'pkill -x dwmblocks; setsid -f dwmblocks' <<<"$out"
check "...and nothing about dwm" not grep -q '^  - dwm ' <<<"$out"
fakeproc 101 dwm old new
out="$(running_build_report)"
check "both stale: dwm's in-place restart too" grep -qF 'pkill -HUP -x dwm' <<<"$out"

blue "==> the installers end with it"
for f in install-suckless.sh install-void.sh; do
    check "$f: running_build_report is its last command" \
        test "$(grep -v '^\s*\(#\|$\)' "$DOTS_DIR/scripts/$f" | tail -1)" == running_build_report
done

if ((rc != 0)); then
    red "✗ running build"
    exit 1
fi
green "✓ running build: a replaced dwm/dwmblocks is reported, an identical rebuild is not"
