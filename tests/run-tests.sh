#!/usr/bin/env bash
# The single owner of "run every test in tests/*.sh". CI's `tests` job and
# TESTING.md's quick-start both used to restate this loop by hand — the same
# "delete the copy, don't extend it" lesson rule 6/10 record for daemon and
# package lists. Both now invoke this script instead.
#
# Hardening ported from dwm-titus/scripts/run-tests (CLAUDE.md "Reference
# clones" -> dwm-titus, harvest item #6), MINUS its per-run token handshake
# and root/EUID branches — those back container-as-root tests this repo has
# none of (scope-d locked decision 2, .claude/tasks/scope-d-verification-harvest.md).
# What's kept: refuse an unsafe test-workspace root, mktemp a workspace
# cleaned on every exit path, run the suite under setsid so an interrupted
# run cannot orphan a child, and export TMPDIR into every test.
#
# usage: tests/run-tests.sh (no arguments)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export DOTS_DIR

red() { printf '\033[31m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# --- workspace root validation ----------------------------------------------
test_root="${DOTS_TEST_TMP_ROOT:-${XDG_CACHE_HOME:-$HOME/.cache}/dots-tests}"
if [[ -z "$test_root" ]]; then
    red "refusing empty test root"
    exit 2
fi
if [[ -L "$test_root" ]]; then
    red "refusing symlinked test root: $test_root"
    exit 2
fi
test_root="$(realpath -m -- "$test_root")"
if [[ "$test_root" == "/" || "$test_root" == "/tmp" ]]; then
    red "refusing unsafe test root: $test_root"
    exit 2
fi
mkdir -p -- "$test_root"

work="$(mktemp -d "$test_root/run-tests.XXXXXX")"
# Invoked only indirectly, via `trap ... EXIT` below — shellcheck's
# unreachable-body check (SC2317, split into SC2329 in 0.10.0, see
# tests/shellcheck-pin.sh) can't see that and flags it as dead code.
# shellcheck disable=SC2317,SC2329
cleanup() {
    local status=$?
    trap - EXIT HUP INT TERM
    rm -rf -- "$work"
    exit "$status"
}
trap cleanup EXIT

# --- process-group-aware child management -----------------------------------
child_pid=
child_group=false
child_alive() {
    if [[ "$child_group" == true ]]; then
        kill -0 -- "-$child_pid" 2>/dev/null
    else
        kill -0 "$child_pid" 2>/dev/null
    fi
}
stop_child() {
    local signal="$1" attempt
    [[ -n "$child_pid" ]] || return 0
    if [[ "$child_group" == true ]]; then
        kill -s "$signal" -- "-$child_pid" 2>/dev/null || true
    else
        kill -s "$signal" "$child_pid" 2>/dev/null || true
    fi
    for ((attempt = 0; attempt < 20; attempt++)); do
        child_alive || break
        sleep 0.05
    done
    if child_alive; then
        if [[ "$child_group" == true ]]; then
            kill -KILL -- "-$child_pid" 2>/dev/null || true
        else
            kill -KILL "$child_pid" 2>/dev/null || true
        fi
    fi
    wait "$child_pid" 2>/dev/null || true
}
# Invoked only indirectly, via the HUP/INT/TERM traps below — same
# false-positive as cleanup() above.
# shellcheck disable=SC2317,SC2329
interrupt() {
    local signal="$1" status="$2"
    trap - HUP INT TERM
    stop_child "$signal"
    child_pid=
    exit "$status"
}
trap 'interrupt HUP 129' HUP
trap 'interrupt INT 130' INT
trap 'interrupt TERM 143' TERM

export TMPDIR="$work"
blue "==> test workspace: $work"

# --- the actual suite loop, run as the hardened child -----------------------
# Two tests are skipped by default. Each needs an environment this runner
# does not have, and each is INVOKED by the job that does have it, never
# reimplemented there: build.sh needs the X11 build toolchain (run by
# build-suckless inside a Fedora container); lint.sh needs shellcheck/shfmt/
# markdownlint (run by the lint job as `tests/lint.sh --strict` once it has
# installed them). run-tests.sh excludes itself from its own glob.
run_suite() {
    local skip=" build.sh lint.sh run-tests.sh "
    local fail=0 name t
    for t in "$DOTS_DIR"/tests/*.sh; do
        name="$(basename "$t")"
        case "$skip" in
            *" $name "*)
                echo "skip: $name (covered by a dedicated job)"
                continue
                ;;
        esac
        echo "::group::$name"
        if bash "$t"; then
            echo "OK: $name"
        else
            echo "::error file=$t::$name failed"
            fail=1
        fi
        echo "::endgroup::"
    done
    exit "$fail"
}

if command -v setsid >/dev/null 2>&1; then
    child_group=true
    setsid bash -c "$(declare -f run_suite); run_suite" &
    child_pid=$!
else
    run_suite &
    child_pid=$!
fi

if wait "$child_pid"; then
    status=0
else
    status=$?
fi
if [[ "$child_group" == true ]] && child_alive; then
    stop_child TERM
fi
child_pid=
exit "$status"
