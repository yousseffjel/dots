#!/usr/bin/env bash
# Exercises config/dwm/bin/dwm-audiowatch with fake pactl, pkill and pgrep on
# a sealed PATH.
#
# What is asserted:
#   * on connecting it redraws both blocks, then VOL for a sink event, MIC for
#     a source event, both for a server event, and nothing for the
#     per-application events (sink-input, source-output) or anything else;
#   * it reconnects when the server comes back within the grace window, and
#     redraws both again on reconnecting;
#   * it exits when the server stays gone, and when it never appears at login;
#   * it exits at once, signalling nothing, when another watcher runs (dwm
#     re-runs autostart.sh on every restart) or when pactl is missing;
#   * SIGTERM ends it promptly and takes its `pactl subscribe` with it.
#
# SAFETY: pkill is a fake — the real one would signal the tester's own bar.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

AW="$DOTS_DIR/config/dwm/bin/dwm-audiowatch"
SB="$(mktemp -d)"
WATCHER=""
# shellcheck disable=SC2329 # run by the EXIT trap
cleanup() {
    if [[ -n "$WATCHER" ]]; then kill "$WATCHER" 2>/dev/null || true; fi
    if [[ -f "$SB/sub.pid" ]]; then kill "$(cat "$SB/sub.pid")" 2>/dev/null || true; fi
    rm -rf "$SB"
}
trap cleanup EXIT

seal_path "$SB/real" bash cat rm id sleep
mkdir -p "$SB/fake" "$SB/nopactl"
export LOG="$SB/log" SB

# The server is up while $SB/up exists. Each `subscribe` replays the next
# events file ($SB/events.1, .2, ...) and then drops the server, as a
# PipeWire that stops would; a missing events file means stop at once.
# shellcheck disable=SC2016 # expanded by the fake, not here
fake "$SB/fake" pactl 'case "$1" in
info) [ -e "$SB/up" ] ;;
subscribe)
    n=$(( $(cat "$SB/subs" 2>/dev/null || echo 0) + 1 )); echo "$n" >"$SB/subs"
    if [ -e "$SB/block" ]; then echo $$ >"$SB/sub.pid"; exec "$SB/real/sleep" 30; fi
    [ -f "$SB/events.$n" ] && cat "$SB/events.$n"
    [ -e "$SB/events.$((n + 1))" ] || rm -f "$SB/up" ;;
esac'
# shellcheck disable=SC2016
fake "$SB/fake" pkill 'echo "${1#-RTMIN+}" >>"$LOG"'
# shellcheck disable=SC2016
fake "$SB/fake" pgrep '[ -n "${OTHER:-}" ] && echo "$OTHER"; exit 0'
for t in pkill pgrep; do ln -s "$SB/fake/$t" "$SB/nopactl/$t"; done

rc=0
check() {
    local name="$1" want="$2" got
    got="$({ tr '\n' ' ' <"$LOG"; } 2>/dev/null || true)"
    if [[ "$got" == "$want" ]]; then
        green "  ok: $name"
    else
        red "  $name: expected '$want', got '$got'"
        rc=1
    fi
}
reset() { rm -f "$LOG" "$SB"/up "$SB"/subs "$SB"/events.* "$SB"/block "$SB"/sub.pid; }
run() {
    PATH="${BIN:-$SB/fake}:$SB/real" DOTS_AUDIOWATCH_START_WAIT=2 DOTS_AUDIOWATCH_RECONNECT_WAIT=1 \
        "$(type -P bash)" "$AW" >/dev/null 2>&1
}

blue "==> dwm-audiowatch"
reset
touch "$SB/up"
printf '%s\n' "Event 'change' on sink #47" "Event 'change' on source #48" \
    "Event 'change' on server" "Event 'change' on sink-input #90" \
    "Event 'new' on source-output #91" "Event 'change' on card #40" >"$SB/events.1"
run
check "both on connect, then VOL / MIC / both, per-app events ignored" "8 7 8 7 8 7 "

reset
touch "$SB/up"
echo "Event 'new' on sink #50" >"$SB/events.1"
echo "Event 'change' on source #51" >"$SB/events.2"
run
check "reconnects within the grace window and redraws both again" "8 7 8 8 7 7 "

reset
run
check "the server never appears: exits, nothing signalled" ""

reset
touch "$SB/up"
OTHER=$$ run
check "another watcher is running: exits, nothing signalled" ""

reset
touch "$SB/up"
BIN="$SB/nopactl" run
check "no pactl: exits, nothing signalled" ""

reset
touch "$SB/up" "$SB/block"
PATH="$SB/fake:$SB/real" "$(type -P bash)" "$AW" >/dev/null 2>&1 &
WATCHER=$!
for _ in $(seq 50); do
    [[ -s "$SB/sub.pid" ]] && break
    "$SB/real/sleep" 0.1
done
kill -TERM "$WATCHER"
gone=0
for _ in $(seq 30); do
    if ! kill -0 "$WATCHER" 2>/dev/null && ! kill -0 "$(cat "$SB/sub.pid")" 2>/dev/null; then
        gone=1
        break
    fi
    "$SB/real/sleep" 0.1
done
wait "$WATCHER" 2>/dev/null || true
WATCHER=""
if ((gone)); then
    green "  ok: SIGTERM ends it and its pactl subscribe within 3 s"
else
    red "  SIGTERM left the watcher or its pactl subscribe running"
    rc=1
fi

if ((rc == 0)); then green "✓ dwm-audiowatch"; else red "✗ dwm-audiowatch"; fi
exit "$rc"
