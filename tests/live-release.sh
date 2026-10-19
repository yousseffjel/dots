#!/usr/bin/env bash
# live_dots_release (scripts/install-live-dots.sh): which processes the live
# installer stops before it removes the temporary sudo rule and unmounts.
# Split out of tests/live-dots.sh, which covers the stage around it.
#
# What is asserted:
#   * only a process whose /proc root is the target is stopped, never one
#     rooted elsewhere (uid 1000 can be the live ISO's own user);
#   * a loop that survives TERM and starts a new child each time the old one
#     dies is stopped with every child it started: one scan-then-kill would
#     miss the newest (the release rescans each round).
#
# Real processes, so kill has something to hit; a fake /proc (LIVE_PROC)
# decides which count as rooted in the target. Never the real /proc: a
# loosened filter would kill the host.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIVE_SCRIPTS="$DOTS_DIR/scripts"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/mnt" "$SB/proc"

failed=0
result() {
    if [[ $2 -eq 0 ]]; then
        green "  ok: $1"
    else
        red "  FAIL: $1"
        failed=1
    fi
}

# release — live_dots_release against the sandbox target and fake /proc.
release() {
    (
        DRY_RUN=0 LIVE_TARGET="$SB/mnt" LIVE_PROC="$SB/proc"
        # shellcheck source=../scripts/install-live-dots.sh
        source "$LIVE_SCRIPTS/install-live-dots.sh"
        live_dots_release
    ) >/dev/null
}

# stopped <pid> — true once <pid> is gone; KILLs a survivor so a failing
# case never leaves a process behind.
stopped() {
    kill -0 "$1" 2>/dev/null || return 0
    kill -KILL "$1" 2>/dev/null || true
    return 1
}

blue "==> a process left running in the target"
sleep 300 >/dev/null 2>&1 &
inside=$!
sleep 300 >/dev/null 2>&1 &
decoy=$!
mkdir -p "$SB/proc/$inside" "$SB/proc/$decoy"
ln -s "$SB/mnt" "$SB/proc/$inside/root"
ln -s / "$SB/proc/$decoy/root"
release
ok=0
wait "$inside" 2>/dev/null || true
stopped "$inside" || ok=1
kill -0 "$decoy" 2>/dev/null || ok=1
kill "$decoy" 2>/dev/null || true
result "only the process rooted in the target is stopped" "$ok"

blue "==> a loop that starts its next child after a kill"
rm -rf "${SB:?}/proc"
mkdir -p "$SB/proc"
# Started from $(...) so it is not this shell's job: init reaps it, and
# kill -0 below cannot be fooled by a zombie.
spawner="$(
    bash -c 'trap : TERM
        reg() { mkdir -p "$1/$2"; ln -s "$3" "$1/$2/root"; }
        reg "$1" "$$" "$2"
        while :; do sleep 300 & reg "$1" "$!" "$2"; echo "$!" >>"$3"; wait "$!" || true; done' \
        _ "$SB/proc" "$SB/mnt" "$SB/children" >/dev/null 2>&1 &
    echo "$!"
)"
for _ in $(seq 50); do
    [[ -s $SB/children ]] && break
    sleep 0.1
done
release
for _ in $(seq 20); do
    kill -0 "$spawner" 2>/dev/null || break
    sleep 0.1
done
ok=0
stopped "$spawner" || ok=1
while read -r child; do
    stopped "$child" || ok=1
done <"$SB/children"
[[ $(wc -l <"$SB/children") -ge 2 ]] || ok=1
result "the loop and every child it started are stopped ($(wc -l <"$SB/children") children)" "$ok"

exit "$failed"
