#!/usr/bin/env bash
# Exercises groups_add (scripts/install-services-groups.sh) against fake id,
# getent and usermod on a sealed PATH.
#
# What is asserted:
#   * the missing groups are added in ONE usermod -aG, comma-separated;
#   * a group the user is already in is not re-added;
#   * a group that does not exist (bluez not installed) is skipped with a
#     reason, never passed to usermod (it would fail the whole call);
#   * the re-login reminder appears only when something was added;
#   * a usermod failure is a yellow line, never fatal;
#   * --dry-run runs no usermod.

# The predicates are only called through check's "$@". See tests/pkg-repos.sh.
# shellcheck disable=SC2317,SC2329

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
export LOG="$SB/calls.log"

seal_path "$SB/bin" bash grep sed tr cat rm
# shellcheck disable=SC2016 # the bodies expand when the fakes run
{
    fake "$SB/bin" id '[[ "$1" == -nG ]] && echo "${FAKE_GROUPS:-ysf wheel}"'
    fake "$SB/bin" getent '[[ "$1" == group ]] || exit 2
[[ " ${FAKE_NOGROUP:-} " == *" $2 "* ]] && exit 2; echo "$2:x:1:"'
    fake "$SB/bin" usermod 'echo "usermod $*" >>"$LOG"; [[ -z "${FAKE_FAIL:-}" ]]'
}
PATH="$SB/bin"

red() { printf 'RED %s\n' "$*"; }
green() { printf '%s\n' "$*"; }
yellow() { green "$@"; }
blue() { green "$@"; }
# shellcheck source=../scripts/install-services-groups.sh
source "$DOTS_DIR/scripts/install-services-groups.sh"
SUDO=() DRY_RUN=0

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then printf '\033[32m  ok    %s\033[0m\n' "$what"; else
        printf '\033[31m  FAIL  %s\033[0m\n' "$what"
        FAILS=$((FAILS + 1))
    fi
}
said() { grep -qF -- "$1" "$SB/out"; }
not_said() { ! said "$1"; }
run() {
    : >"$LOG"
    groups_add ysf >"$SB/out" 2>&1
}

printf '\033[34m%s\033[0m\n' "==> a fresh user (install-live.sh: wheel only)"
run
check "one usermod for all four" test "$(cat "$LOG")" = "usermod -aG network,bluetooth,kvm,video ysf"
check "re-login reminder" said "log out and back in"

printf '\033[34m%s\033[0m\n' "==> already in some"
FAKE_GROUPS="ysf wheel network kvm video" run
check "only the missing one" test "$(cat "$LOG")" = "usermod -aG bluetooth ysf"

printf '\033[34m%s\033[0m\n' "==> already in all"
FAKE_GROUPS="ysf wheel network bluetooth kvm video" run
check "no usermod" test ! -s "$LOG"
check "no reminder" not_said "log out and back in"

printf '\033[34m%s\033[0m\n' "==> bluez not installed: no bluetooth group"
FAKE_NOGROUP=bluetooth run
check "skipped with a reason" said "skip    group bluetooth does not exist"
check "never passed to usermod" test "$(cat "$LOG")" = "usermod -aG network,kvm,video ysf"

printf '\033[34m%s\033[0m\n' "==> usermod fails"
rc=0
FAKE_FAIL=1 run || rc=$?
check "not fatal" test "$rc" -eq 0
check "says what to run" said "run:  sudo usermod -aG network,bluetooth,kvm,video ysf"

printf '\033[34m%s\033[0m\n' "==> --dry-run"
DRY_RUN=1 run
check "no usermod" test ! -s "$LOG"
check "says what it would run" said "(dry-run) would run: usermod -aG network,bluetooth,kvm,video ysf"

if [[ $FAILS -eq 0 ]]; then
    printf '\033[32m%s\033[0m\n' "✓ user groups: added once, together, never fatal"
else
    printf '\033[31m%s\033[0m\n' "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
