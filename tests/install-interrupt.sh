#!/usr/bin/env bash
# Ctrl-C ends an install (2026-10-19). On the VM, a Ctrl-C that landed while
# xbps-install verified signatures was swallowed whole: xbps exited 0, and
# bash carries on when the command it waited on exits normally after SIGINT,
# so the package stage, install-void.sh and the rest of the run all went on.
# stop_on_interrupt (scripts/global_fn.sh) traps INT and TERM, and a trap
# runs once that command returns, whatever its status.
#
# What is asserted:
#   * a script that calls stop_on_interrupt stops at the interrupted command
#     with status 130, even though that command exits 0;
#   * the same script without the call carries on (the bug, reproduced, so
#     the first check cannot pass by accident);
#   * install-void.sh and every script it runs call stop_on_interrupt right
#     after sourcing global_fn.sh. The list is read from install-void.sh.
#
# The interrupt is a real SIGINT to a process group of our own (setsid),
# never to the test runner's. `env --default-signal=INT` undoes the SIG_IGN
# a background job of a non-interactive shell starts with: bash cannot trap
# a signal that was ignored when it started.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

failed=0
check() {
    if [[ $2 == "$3" ]]; then
        green "  ok: $1"
    else
        red "  FAIL: $1"
        printf '      want: %s\n      got:  %s\n' "$2" "$3"
        failed=1
    fi
}

# The interrupted command, as xbps-install behaves: it takes the SIGINT and
# exits 0. It says when it is waiting, so the signal never comes early.
cat >"$SB/xbps" <<'EOF'
#!/usr/bin/env bash
trap 'exit 0' INT
: >"$1"
while :; do sleep 0.1; done
EOF
chmod +x "$SB/xbps"

# stage <call> — a stage-like script; <call> is stop_on_interrupt or `:`.
stage() {
    cat >"$SB/stage" <<EOF
#!/usr/bin/env bash
set -euo pipefail
source "$DOTS_DIR/scripts/global_fn.sh"
$1
"$SB/xbps" "$SB/ready"
echo carried-on >"$SB/after"
EOF
    chmod +x "$SB/stage"
}

# interrupt — run the stage in its own process group, Ctrl-C it once the
# fake xbps waits, and print "<status> <what ran after>".
interrupt() {
    local pid status=0
    rm -f "$SB/ready" "$SB/after"
    env --default-signal=INT setsid "$SB/stage" &
    pid=$!
    for _ in $(seq 50); do
        [[ -e $SB/ready ]] && break
        sleep 0.1
    done
    kill -INT -- "-$pid"
    for _ in $(seq 50); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
    done
    kill -0 "$pid" 2>/dev/null && kill -KILL -- "-$pid"
    wait "$pid" || status=$?
    printf '%s %s\n' "$status" "$(cat "$SB/after" 2>/dev/null || echo nothing)"
}

blue "==> Ctrl-C while a command that swallows it runs"
stage stop_on_interrupt
check "with stop_on_interrupt: exit 130, nothing after it runs" "130 nothing" "$(interrupt)"
stage :
check "without it: the script carries on (the 2026-10-19 bug)" "0 carried-on" "$(interrupt)"

blue "==> every script install-void.sh runs calls it"
# The scripts install-void.sh runs, read from its own lines, plus itself.
# shellcheck disable=SC2016 # a literal $SCRIPT_DIR, as install-void.sh spells it
mapfile -t scripts < <(sed -n 's|^ *"\$SCRIPT_DIR/\([a-z-]*\.sh\)".*|\1|p' "$DOTS_DIR/scripts/install-void.sh")
[[ ${#scripts[@]} -ge 6 ]] || {
    red "  FAIL: found only ${#scripts[@]} script(s) run by install-void.sh"
    exit 1
}
for s in install-void.sh "${scripts[@]}"; do
    # The call must follow the source line: it is defined there.
    # shellcheck disable=SC2016 # the literal source line
    got="$(grep -A1 -x 'source "$SCRIPT_DIR/global_fn.sh"' "$DOTS_DIR/scripts/$s" | grep -cx stop_on_interrupt || true)"
    check "$s calls stop_on_interrupt after sourcing global_fn.sh" 1 "$got"
done

exit "$failed"
