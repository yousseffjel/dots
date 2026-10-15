#!/usr/bin/env bash
# Exercises config/dwm/bin/dwm-power (scope-h slot 5) against a fake gdbus on
# a sealed PATH — never the real system bus, where a Set would change this
# machine's power profile.
#
# What is asserted:
#   * get/available read ActiveProfile from the power-profiles API;
#   * with no service (a desktop) the menu explains instead of failing
#     silently, and opens no dmenu;
#   * the menu marks the current profile, sets the chosen one with the right
#     GVariant, and leaves an unchanged choice or Escape alone;
#   * an unknown profile is rejected with no Set, and a refused Set (polkit,
#     no seat) is an error and a critical notification.
#
# The fake's output copies real gdbus: a property Get prints `(<'value'>,)`
# (captured from org.freedesktop.hostname1's Chassis on the dev host), and a
# missing service prints `Error: GDBus.Error:...ServiceUnknown` and fails.

# logged/not_logged are only called through check's "$@", which shellcheck
# cannot follow. Both codes, as in tests/pkg-repos.sh.
# shellcheck disable=SC2317,SC2329

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUT="$DOTS_DIR/config/dwm/bin/dwm-power"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"
LOG="$TMP/calls.log"
seal_path "$BIN" bash cat
# shellcheck disable=SC2016 # the bodies expand when the fakes run
{
    fake "$BIN" gdbus '
[[ -n "${FAKE_NO_PPD:-}" ]] && { echo "Error: GDBus.Error:org.freedesktop.DBus.Error.ServiceUnknown: The name is not activatable" >&2; exit 1; }
case "$*" in
*Properties.Get*) echo "(<'"'"'${FAKE_PROFILE:-balanced}'"'"'>,)" ;;
*Properties.Set*) echo "gdbus-set ${*: -1}" >>"$LOG"; [[ -n "${FAKE_REFUSE:-}" ]] && exit 1; echo "()" ;;
esac'
    fake "$BIN" dmenu 'echo "dmenu <$(tr "\n" "," 2>/dev/null </dev/stdin || cat)>" >>"$LOG"; [[ "${FAKE_PICK:-}" == ESC ]] && exit 1; echo "$FAKE_PICK"'
    fake "$BIN" notify-send 'echo "notify-send $*" >>"$LOG"'
}
seal_path "$BIN" tr

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}
# run [VAR=val...] -- <args> — sets OUT, ERR, RC; fresh log.
run() {
    local envs=()
    while [[ $# -gt 0 && "$1" != -- ]]; do
        envs+=("$1")
        shift
    done
    shift
    : >"$LOG"
    RC=0
    env -i PATH="$BIN" LOG="$LOG" "${envs[@]}" bash "$SUT" "$@" >"$TMP/out" 2>"$TMP/err" || RC=$?
    OUT="$(cat "$TMP/out")"
    ERR="$(cat "$TMP/err")"
}
logged() { grep -qF -- "$1" "$LOG"; }
not_logged() { ! logged "$1"; }

blue "==> reading"
run -- get
check "get: the active profile" test "$RC:$OUT" = "0:balanced"
run FAKE_PROFILE=power-saver -- available
check "available: exit 0 with a service" test "$RC" -eq 0
run FAKE_NO_PPD=1 -- available
check "available: exit 1 without one" test "$RC" -eq 1
run 'FAKE_PROFILE=x>,) junk (<' -- get
check "an unexpected gdbus shape is not passed off as a profile" test "$RC" -eq 1

blue "==> a desktop (no service)"
run FAKE_NO_PPD=1 -- menu
check "menu fails with a reason" test "$RC" -eq 1
check "...told to the user, laptops only" logged "power-profiles-daemon, which dots installs on laptops only"
check "...and opens no dmenu" not_logged "dmenu"

blue "==> the menu"
run 'FAKE_PICK=  power-saver' --
check "no argument means the menu" logged "dmenu <  power-saver,* balanced,  performance,>"
check "the chosen profile is set as a GVariant string" logged "gdbus-set <'power-saver'>"
check "...and announced" logged "notify-send -a dots -h string:x-dunst-stack-tag:power Power profile power-saver"
run 'FAKE_PICK=* balanced' -- menu
check "picking the current profile sets nothing" not_logged "gdbus-set"
run FAKE_PICK=ESC -- menu
check "Escape: exit 0, nothing set" test "$RC:$(grep -c gdbus-set "$LOG" || true)" = "0:0"

blue "==> set"
run -- set performance
check "set performance" logged "gdbus-set <'performance'>"
run -- set turbo
check "an unknown profile is rejected" test "$RC" -eq 1
check "...with no Set" not_logged "gdbus-set"
run FAKE_REFUSE=1 -- set power-saver
check "a refused Set (no seat) fails" test "$RC" -eq 1
check "...says why" grep -q "needs your session at the seat" <<<"$ERR"
check "...and notifies at critical urgency" logged "notify-send -a dots -h string:x-dunst-stack-tag:power -u critical"
run -- bogus
check "an unknown command is rejected" test "$RC" -eq 1

if [[ $FAILS -eq 0 ]]; then
    green "✓ dwm-power: reads, switches and refuses as it should"
else
    red "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
