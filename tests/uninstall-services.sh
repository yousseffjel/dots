#!/usr/bin/env bash
# Exercises uninstall_services (scripts/uninstall_steps.sh) against a fake
# systemctl on a sealed PATH: the SERVICE rows the installer writes (ly) and
# `dots drivers` writes on a laptop (tuned.service, tuned-ppd.service).
#
# What is asserted:
#   * a recorded unit that still exists is disabled;
#   * a unit whose package uninstall_packages already removed is reported as
#     gone, not as a red "failed to disable";
#   * a genuine disable failure is still red;
#   * --dry-run disables nothing.

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
    XDG_DATA_HOME="$SB/data" XDG_CACHE_HOME="$SB/cache" LOG="$SB/calls.log"

seal_path "$SB/bin" bash grep awk sed mkdir touch cut sort cat mv rm tr wc
# shellcheck disable=SC2016 # the body expands when the fake runs
fake "$SB/bin" systemctl 'echo "systemctl $*" >>"$LOG"
case "$1" in
cat) [[ " ${FAKE_GONE:-} " != *" $2 "* ]] ;;
disable) [[ " ${FAKE_FAIL:-} " != *" $2 "* ]] ;;
esac'
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
not_said() { ! said "$1"; }
logged() { grep -qxF -- "$1" "$LOG"; }
not_in_log() { ! grep -q -- "$1" "$LOG"; }
run() {
    : >"$LOG"
    OUT="$(uninstall_services 2>&1)"
}

manifest_append_row SERVICE ly@tty2.service
manifest_append_row SERVICE tuned.service
manifest_append_row SERVICE tuned-ppd.service

printf '\033[34m%s\033[0m\n' "==> units still installed"
run
check "ly disabled" logged "systemctl disable ly@tty2.service"
check "tuned disabled" logged "systemctl disable tuned.service"
check "no red at all" not_said "RED"

printf '\033[34m%s\033[0m\n' "==> units gone with their package"
FAKE_GONE="tuned.service tuned-ppd.service" run
check "a removed unit is reported as gone" said "tuned.service is gone with its package"
check "...not as a failure" not_said "RED"
check "...and no disable is attempted" not_in_log "disable tuned"
check "ly is still disabled" logged "systemctl disable ly@tty2.service"

printf '\033[34m%s\033[0m\n' "==> a real failure stays red"
FAKE_FAIL=ly@tty2.service run
check "failed disable is red" said "RED   failed to disable ly@tty2.service"

printf '\033[34m%s\033[0m\n' "==> dry run"
DRY_RUN=1 run
check "dry run: nothing disabled" not_in_log "systemctl disable"
check "dry run: says what it would do" said "(dry-run) would run: systemctl disable tuned.service"

if [[ $FAILS -eq 0 ]]; then
    printf '\033[32m%s\033[0m\n' "✓ uninstall-services: disables what remains, reports what is gone"
else
    printf '\033[31m%s\033[0m\n' "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
