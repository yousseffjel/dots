#!/usr/bin/env bash
# Exercises scripts/install-pre.sh, the installer's pre-flight stage, on a
# sealed PATH with fake xbps-install, xbps-uhelper and sudo.
#
# What is asserted:
#   * Void glibc (xbps-uhelper arch prints x86_64): passes, no musl note;
#   * Void musl (x86_64-musl, not the supported target): the note is printed
#     and the stage still passes — it warns, it does not refuse;
#   * not in wheel (and not root): a hard failure naming the fix, because
#     every later step runs through sudo (scope I, decision D4);
#   * no xbps-install: a hard failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUT="$DOTS_DIR/scripts/install-pre.sh"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
# dirname and HOME: the stage sources global_fn.sh for stop_on_interrupt, and
# rule 3's SCRIPT_DIR line and the manifest path there need them.
seal_path "$SB/bin" dirname
for t in xbps-install sudo; do fake "$SB/bin" "$t" 'exit 0'; done
# shellcheck disable=SC2016 # the body expands when the fake runs
fake "$SB/bin" id 'case "$1" in -un) echo ysf ;; -nG) echo "${FAKE_GROUPS:-ysf wheel audio video}" ;; -u) echo 1000 ;; esac'
# Real output, xbps-static 0.60.7: "x86_64", or "x86_64-musl" on musl.
# shellcheck disable=SC2016 # the body expands when the fake runs
fake "$SB/bin" xbps-uhelper '[[ "$1" == arch ]] || exit 1; echo "x86_64${FAKE_MUSL:+-musl}"'

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}
# Called only through check's "$@". See tests/pkg-repos.sh.
# shellcheck disable=SC2317,SC2329
no_musl_note() { ! grep -q musl <<<"$OUT"; }
run() {
    RC=0
    OUT="$(env -i HOME="$SB" PATH="$SB/bin" "${@}" "$(type -P bash)" "$SUT" 2>&1)" || RC=$?
}

run
check "Void glibc: passes" test "$RC" -eq 0
check "...with no musl note" no_musl_note
run FAKE_MUSL=1
check "Void musl: still passes (a note, not a refusal)" test "$RC" -eq 0
check "...naming the arch" grep -q "x86_64-musl" <<<"$OUT"
check "...and the supported target" grep -q "supported target is Void glibc" <<<"$OUT"
run FAKE_GROUPS="ysf audio video"
check "not in wheel: fails" test "$RC" -ne 0
check "...naming the fix" grep -q "usermod -aG wheel ysf" <<<"$OUT"
rm "$SB/bin/xbps-install"
run
check "no xbps-install: fails" test "$RC" -ne 0

if [[ $FAILS -eq 0 ]]; then
    green "✓ install-pre: glibc passes, musl is told, no xbps fails"
else
    red "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
