#!/usr/bin/env bash
# Exercises uninstall_packages (scripts/uninstall_steps.sh) against fake
# xbps-query and xbps-remove on a sealed PATH.
#
# The fakes reproduce real xbps 0.60.7 (xbps-static, scratch root,
# 2026-10-15): `xbps-query <name>` exits 0 installed, 2 not; `xbps-remove`
# fails the WHOLE call, exit 2, "Package `x' is not currently installed.",
# on a single name that is already gone.
#
# What is asserted:
#   * only PACKAGE rows still installed reach xbps-remove, so one package the
#     user removed by hand cannot sink the rest;
#   * the call is `xbps-remove -Ry` (-R: dependencies nothing else needs go
#     too), with stdin off the terminal;
#   * nothing still installed: no xbps-remove at all;
#   * a failing removal is red and names what to remove by hand;
#   * --dry-run removes nothing.

# The predicates are only called through check's "$@". See tests/pkg-repos.sh.
# shellcheck disable=SC2317,SC2329

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
# All four XDG variables: HOME alone leaks into the real install manifest.
export HOME="$SB/home" XDG_STATE_HOME="$SB/state" XDG_CONFIG_HOME="$SB/config" \
    XDG_DATA_HOME="$SB/data" XDG_CACHE_HOME="$SB/cache" LOG="$SB/calls.log" DB="$SB/pkgdb"

seal_path "$SB/bin" bash grep awk sed mkdir touch cut sort cat mv rm tr wc readlink
# shellcheck disable=SC2016 # the bodies expand when the fakes run
{
    fake "$SB/bin" xbps-query 'grep -qx "$1" "$DB" || exit 2; echo "$1-1.0_1"'
    fake "$SB/bin" xbps-remove 'echo "xbps-remove $*" >>"$LOG"
[[ "$(readlink /proc/$$/fd/0)" == /dev/null ]] || echo "STDIN NOT NULL" >>"$LOG"
shift
for p in "$@"; do grep -qx "$p" "$DB" || { echo "Package \`$p'"'"' is not currently installed." >&2; exit 2; }; done
[[ -n "${FAKE_FAIL:-}" ]] && { echo "ERROR: $1 is required by other-1.0_1" >&2; exit 1; }
for p in "$@"; do sed -i "/^$p\$/d" "$DB"; done'
}
PATH="$SB/bin"

# No red/green/blue of its own (CLAUDE.md rule 2): it sources global_fn.sh and
# replaces them with plain ones, as tests/pkg-repos.sh does.
# shellcheck source=../scripts/global_fn.sh
source "$DOTS_DIR/scripts/global_fn.sh"
red() { printf 'RED %s\n' "$*"; }
green() { printf '%s\n' "$*"; }
yellow() { green "$@"; }
blue() { green "$@"; }
# shellcheck source=../scripts/uninstall_steps.sh
source "$DOTS_DIR/scripts/uninstall_steps.sh"
SUDO=() DRY_RUN=0 ASSUME_YES=1

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then printf '\033[32m  ok    %s\033[0m\n' "$what"; else
        printf '\033[31m  FAIL  %s\033[0m\n' "$what"
        FAILS=$((FAILS + 1))
    fi
}
said() { grep -qF -- "$1" <<<"$OUT"; }
logged() { grep -qxF -- "$1" "$LOG"; }
# setup <installed...> — rows for jq, fzf and tmux; only the named ones are
# still installed. stdin is a regular file, so a call that forgets to close
# its own is caught.
setup() {
    rm -rf "$SB/state"
    manifest_append_row PACKAGE jq
    manifest_append_row PACKAGE fzf
    manifest_append_row PACKAGE tmux
    printf '%s\n' "$@" >"$DB"
    : >"$LOG"
}
: >"$SB/stdin"
run() { OUT="$(uninstall_packages 2>&1 <"$SB/stdin")"; }

printf '\033[34m%s\033[0m\n' "==> one recorded package was already removed by hand"
setup jq tmux
run
check "only the two still installed reach xbps-remove, with -Ry" logged "xbps-remove -Ry jq tmux"
check "...stdin off the terminal" test "$(grep -c 'STDIN NOT NULL' "$LOG" || true)" -eq 0
check "...and they are gone" test ! -s "$DB"
check "said how many" said "removed 2 package(s)"

printf '\033[34m%s\033[0m\n' "==> nothing recorded is still installed"
setup
run
check "no xbps-remove call" test ! -s "$LOG"
check "said so" said "none of the 3 recorded package(s) is still installed"

printf '\033[34m%s\033[0m\n' "==> the removal fails"
setup jq fzf tmux
FAKE_FAIL=1 run
check "red, naming what to remove by hand" said "RED   xbps-remove failed — remove manually: fzf jq tmux"
check "nothing removed" test "$(wc -l <"$DB")" -eq 3

printf '\033[34m%s\033[0m\n' "==> --dry-run"
setup jq
DRY_RUN=1 run
check "no xbps-remove call" test ! -s "$LOG"
check "says what it would run" said "(dry-run) would run: xbps-remove -Ry jq"
DRY_RUN=0

if [[ $FAILS -eq 0 ]]; then
    printf '\033[32m%s\033[0m\n' "✓ uninstall-packages: removes only what is still ours and installed"
else
    printf '\033[31m%s\033[0m\n' "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
