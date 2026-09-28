#!/usr/bin/env bash
# Exercises config/dwm/bin/dwm-lock against faked xset/xss-lock/slock/logind.
#
# What is asserted, each a decision the script's header argues for:
#   * --daemon arms the screensaver BEFORE DPMS (LOCK_SECS < DPMS_OFF_SECS):
#     reversed, the monitor goes dark on a still-unlocked session;
#   * it hands off to `xss-lock -- slock` with NO --transfer-sleep-lock
#     (slock never closes that fd, adding up to 5s to every suspend);
#   * a second --daemon re-arms the timers but never starts a second xss-lock;
#   * a missing xss-lock or slock fails loudly; a missing xset only warns;
#   * a manual lock goes through `loginctl lock-session` while the daemon is
#     up, falls back to slock when that fails or the daemon is down, and
#     never calls loginctl when the daemon is down (a silent no-op);
#   * extra arguments are rejected before anything runs.
#
# SAFETY: every tool is a fake on a sealed PATH. A real slock would lock the
# tester's screen; a real xset would change their idle timers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SUT="$DOTS_DIR/config/dwm/bin/dwm-lock"
[[ -f "$SUT" ]] || {
    red "missing: $SUT"
    exit 1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
LOG="$TMP/calls.log"

rc=0
pass() { green "  ok: $1"; }
fail() {
    red "  FAIL: $1"
    rc=1
}
check() { # <description> <actual> <expected>
    if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1 — got [$2], want [$3]"; fi
}

# mkbin <name> <tool to leave out>... — a sealed bin dir with every fake
# except the omitted ones, so "not installed" really is not installed.
mkbin() {
    local dir="$TMP/$1" t
    shift
    seal_path "$dir" bash
    for t in xset xss-lock slock loginctl pgrep; do
        [[ " $* " == *" $t "* ]] && continue
        case "$t" in
            # pgrep answers "is xss-lock running?" from FAKE_RUNNING.
            pgrep) fake "$dir" pgrep "[[ \"\${FAKE_RUNNING:-0}\" == 1 ]]" ;;
            loginctl) fake "$dir" loginctl "echo \"loginctl \$*\" >>'$LOG'; exit \"\${FAKE_LOGIN_RC:-0}\"" ;;
            *) fake "$dir" "$t" "echo \"$t \$*\" >>'$LOG'" ;;
        esac
    done
}
mkbin all
mkbin no-xss xss-lock
mkbin no-slock slock
mkbin no-xset xset

# run <bin> [VAR=val...] -- <args...>; sets RC, ERR; the call log starts empty.
run() {
    local bin="$1" envs=()
    shift
    while [[ $# -gt 0 && "$1" != -- ]]; do
        envs+=("$1")
        shift
    done
    shift
    : >"$LOG"
    RC=0
    env -i PATH="$TMP/$bin" "${envs[@]}" bash "$SUT" "$@" >/dev/null 2>"$TMP/err" || RC=$?
    ERR="$(cat "$TMP/err")"
}
calls() { tr '\n' ';' <"$LOG"; }

blue "==> --daemon"
run all -- --daemon
check "arms screensaver, then DPMS, then hands off to xss-lock" "$(calls)" \
    "xset s 600 600;xset dpms 0 0 660;xss-lock -- slock;"
lock_secs="$(awk '$2 == "s" { print $3 }' "$LOG")"
dpms_secs="$(awk '$2 == "dpms" { print $5 }' "$LOG")"
if ((lock_secs < dpms_secs)); then
    pass "the screen locks ($lock_secs s) before the monitor powers off ($dpms_secs s)"
else
    fail "lock $lock_secs s is not before DPMS off $dpms_secs s"
fi
if grep -q 'transfer-sleep-lock' "$LOG"; then
    fail "xss-lock was given --transfer-sleep-lock"
else
    pass "no --transfer-sleep-lock"
fi
run all FAKE_RUNNING=1 -- --daemon
check "already running: timers re-armed, no second xss-lock" "$(calls)" "xset s 600 600;xset dpms 0 0 660;"
check "already running: exits 0" "$RC" 0
run no-xss -- --daemon
if [[ $RC -ne 0 && "$ERR" == *"xss-lock is not installed"* ]]; then pass "missing xss-lock fails loudly"; else fail "missing xss-lock: rc=$RC err=$ERR"; fi
run no-slock -- --daemon
if [[ $RC -ne 0 && "$ERR" == *"slock is not installed"* && "$(calls)" != *xss-lock* ]]; then
    pass "missing slock fails loudly, starts no daemon"
else
    fail "missing slock: rc=$RC calls=$(calls)"
fi
run no-xset -- --daemon
if [[ "$ERR" == *"xset not installed"* && "$(calls)" == "xss-lock -- slock;" ]]; then
    pass "missing xset only warns; the daemon still starts"
else
    fail "missing xset: err=$ERR calls=$(calls)"
fi

blue "==> manual lock"
run all FAKE_RUNNING=1 --
check "daemon up: locks through logind only" "$(calls)" "loginctl lock-session;"
run all FAKE_RUNNING=1 FAKE_LOGIN_RC=1 --
check "logind refuses: falls back to slock" "$(calls)" "loginctl lock-session;slock ;"
run all --
check "daemon down: slock directly, loginctl never called" "$(calls)" "slock ;"
run no-slock --
if [[ $RC -ne 0 && "$ERR" == *"slock is not installed"* ]]; then pass "no daemon, no slock: fails loudly"; else fail "no slock: rc=$RC"; fi

blue "==> arguments"
run all -- --daemon --transfer-sleep-lock
if [[ $RC -ne 0 && ! -s "$LOG" ]]; then pass "two arguments rejected before anything runs"; else fail "two args: rc=$RC calls=$(calls)"; fi
run all -- --bogus
if [[ $RC -ne 0 && ! -s "$LOG" ]]; then pass "unknown argument rejected"; else fail "bogus: rc=$RC calls=$(calls)"; fi

if ((rc != 0)); then
    red "✗ dwm-lock is broken"
    exit 1
fi
green "✓ dwm-lock: timer order, daemon hand-off and lock routing all hold"
