#!/usr/bin/env bash
# Every stop line in the shipped ~/.xinitrc's dots_session_end, and
# autostart.sh's "already running?" guard for clipmenud, find the process
# they are meant to — started the way it really runs.
#
# WHY. A shell script whose shebang is `#!/usr/bin/env bash` runs as a
# process named "bash": env execs bash, and the kernel names the process
# after what was exec'd last. Void's /usr/sbin/clipmenud is one, so
# `pkill -x clipmenud` matched nothing and clipmenud outlived the session,
# holding ly's tty2 as its stderr (Void VM, 2026-10-21) — the TTY flood
# dots_session_end exists to prevent. autostart's `pgrep -x clipmenud`
# guard never saw a running copy either. dwm-nightlight learned the same
# lesson on 2026-10-07 and is matched with -f.
#
# HOW. Fakes in a temp dir: each program the stops name is started as what
# it is — a script for the names in ENV_SCRIPTS, a binary (a renamed copy
# of sleep) for the rest. Each stop line then runs with pkill replaced by
# pgrep and must list its fake's pid. Nothing is ever killed by pattern:
# pkill -u "$(id -u)" -x dwmblocks here would stop the bar of the session
# this runs in.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# install-session.sh only defines functions, so sourcing it runs nothing.
# shellcheck source=../scripts/install-session.sh
source "$DOTS_DIR/scripts/install-session.sh"

SB="$(mktemp -d)"
# Each fake leads its own session (setsid), so killing the group also stops
# a script fake's sleep. The pids go in a file: start() runs in $(...).
cleanup() {
    local p
    while read -r p; do kill -- "-$p" 2>/dev/null || true; done <"$SB/pids"
    rm -rf "$SB"
}
: >"$SB/pids"
trap cleanup EXIT
rc=0
check() {
    local name="$1"
    shift
    if "$@"; then
        green "  ok: $name"
    else
        red "  FAIL: $name"
        rc=1
    fi
}

# Programs that run as `#!/usr/bin/env bash` scripts on Void: clipmenud
# (clipmenu 6.2.0_1's /usr/sbin/clipmenud, read on the VM 2026-10-21) and
# dwm-nightlight (this repo's own; its shebang is checked below).
ENV_SCRIPTS=(clipmenud dwm-nightlight)
check "dwm-nightlight is an env-bash script, as ENV_SCRIPTS says" \
    test "$(head -1 "$DOTS_DIR/config/dwm/bin/dwm-nightlight")" == '#!/usr/bin/env bash'

session_xinitrc_template >"$SB/xinitrc"
session_autostart_template >"$SB/autostart.sh"
mapfile -t STOPS < <(sed -n '/^dots_session_end() {$/,/^}$/{/pkill/p}' "$SB/xinitrc")
check "dots_session_end has stop lines (${#STOPS[@]})" test "${#STOPS[@]}" -ge 5

mkdir -p "$SB/bin"
# start <name> [arg] — the fake, from $SB/bin, as the real one would run.
start() {
    local name="$1" kind=binary s
    for s in "${ENV_SCRIPTS[@]}"; do [[ $s == "$name" ]] && kind=script; done
    if [[ $kind == script ]]; then
        printf '#!/usr/bin/env bash\nsleep 300\n' >"$SB/bin/$name"
    else
        cp "$(command -v sleep)" "$SB/bin/$name"
    fi
    chmod 755 "$SB/bin/$name"
    if [[ $kind == script ]]; then
        PATH="$SB/bin:$PATH" setsid "$name" "${@:2}" </dev/null >/dev/null 2>&1 &
    else
        PATH="$SB/bin:$PATH" setsid "$name" 300 </dev/null >/dev/null 2>&1 &
    fi
    echo "$!" >>"$SB/pids"
    echo "$!"
}

# finds <pid> <pgrep command> — the command lists pid within 3 s (a fake
# is named after its program only once setsid has exec'd it).
finds() {
    local i
    for ((i = 0; i < 30; i++)); do
        grep -qx "$1" <<<"$(bash -c "$2" || true)" && return 0
        sleep 0.1
    done
    return 1
}

blue "==> every dots_session_end stop finds its program"
for line in "${STOPS[@]}"; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line% >/dev/null 2>&1}"
    if [[ $line =~ -x\ ([A-Za-z0-9_.-]+)$ ]]; then
        pid="$(start "${BASH_REMATCH[1]}")"
    elif [[ $line == *"dwm-nightlight daemon"* ]]; then
        pid="$(start dwm-nightlight daemon)"
    elif [[ $line =~ -f\ \'/([A-Za-z0-9_.-]+)\$\'$ ]]; then
        pid="$(start "${BASH_REMATCH[1]}")"
    else
        check "a stop line this test understands: $line" false
        continue
    fi
    check "${line#pkill -u \"\$(id -u)\" }" finds "$pid" "${line/pkill/pgrep}"
done

blue "==> autostart's guard sees a running clipmenud"
guard="$(grep -oE '! pgrep [^;&]*clipmenud[^;&]*' "$SB/autostart.sh" | head -1)"
check "autostart.sh guards clipmenud with pgrep" test -n "$guard"
guard="${guard#! }"
guard="${guard%% >*}"
check "...and that pgrep finds it" bash -c "$guard >/dev/null"

if ((rc != 0)); then
    red "✗ session-end match"
    exit 1
fi
green "✓ session-end match: every stop and the clipmenud guard find a real-shaped process"
