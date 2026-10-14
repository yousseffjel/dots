#!/usr/bin/env bash
# Exercises scripts/install-pre.sh, the installer's pre-flight stage, on a
# sealed PATH with fake dnf, sudo and systemctl.
#
# What is asserted:
#   * Fedora Server (no GDM): passes, no Workstation note;
#   * GDM enabled (Fedora Workstation, not a supported target since
#     2026-10-14): the note is printed and the stage still passes — it warns,
#     it does not refuse;
#   * no dnf: a hard failure, as before.

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
seal_path "$SB/bin"
for t in dnf sudo; do fake "$SB/bin" "$t" 'exit 0'; done
# shellcheck disable=SC2016 # the body expands when the fake runs
fake "$SB/bin" systemctl '[[ "$1 $2" == "is-enabled gdm.service" && -n "${FAKE_GDM:-}" ]] && { echo enabled; exit 0; }; echo disabled; exit 1'

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
no_gdm_note() { ! grep -q GDM <<<"$OUT"; }
run() {
    RC=0
    OUT="$(env -i PATH="$SB/bin" "${@}" "$(type -P bash)" "$SUT" 2>&1)" || RC=$?
}

run
check "Fedora Server: passes" test "$RC" -eq 0
check "...with no Workstation note" no_gdm_note
run FAKE_GDM=1
check "GDM enabled: still passes (a note, not a refusal)" test "$RC" -eq 0
check "...and says Workstation is not supported" grep -q "not a" <<<"$OUT"
check "...naming the supported target" grep -q "Fedora Server" <<<"$OUT"
rm "$SB/bin/dnf"
run
check "no dnf: fails" test "$RC" -ne 0

if [[ $FAILS -eq 0 ]]; then
    green "✓ install-pre: Server passes, Workstation is told, no dnf fails"
else
    red "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
