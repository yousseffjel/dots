#!/usr/bin/env bash
# config/dwm/bin/dwm-xdg-autostart against a fake dex, on a sealed PATH.
# Checked:
#   * every ~/.config/autostart entry reaches dex alone (its -s directory holds
#     that one file), so one entry dex chokes on loses only itself, and says so;
#   * X-GNOME-Autostart-enabled=false is skipped (dex ignores it), but only in
#     [Desktop Entry] — the same key in an action group counts for nothing;
#   * once per session: the same bus address (a dwm restart re-running
#     autostart.sh) starts nothing, a new one (a new login) starts all again;
#     with no bus, dwm's PID and start time are the session instead;
#   * --force runs again; --list passes -d and leaves the session record alone;
#   * no dex, or no autostart directory: exit 0, nothing started.
# The fake prints what dex 0.10.1 printed in a probe (2026-10-23, the Void
# .xbps run on the dev host): one "Executing command:" line per entry, and a
# traceback that ends the run for a non-boolean Hidden. The real dex is then
# run on the same entries when one is installed (not in CI).
# SEALED PATH: tests/lib/sealed-path.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

PASS=0
FAIL=0
ok() {
    green "  ok: $*"
    PASS=$((PASS + 1))
}
bad() {
    red "  FAIL: $*"
    FAIL=$((FAIL + 1))
}
check() {
    local what="$1"
    shift
    if "$@"; then ok "$what"; else bad "$what"; fi
}

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"
SCRIPT="$DOTS_DIR/config/dwm/bin/dwm-xdg-autostart"
BIN="$SB/bin"
LOG="$SB/dex.log"
seal_path "$BIN" bash sed grep cut mkdir mktemp rm ln id dirname cat
# shellcheck disable=SC2016 # the bodies expand when the fakes run
{
    # dex -a [-d] -s DIR: a line per entry in DIR, logged as "<run|dry> <file>".
    fake "$BIN" dex 'mode=run; [[ " $* " == *" -d "* ]] && mode=dry
dir="${@: -1}"
for f in "$dir"/*.desktop; do
    if grep -q "^Hidden=maybe" "$f"; then
        echo "ValueError: '"'"'Hidden'"'"'s value '"'"'maybe'"'"' in group '"'"'Desktop Entry'"'"' is not a boolean value." >&2
        exit 1
    fi
    echo "$mode ${f##*/}" >>"$LOG"
    echo "Executing command: $(sed -n "s/^Exec=//p" "$f")"
done'
    fake "$BIN" pgrep '[[ -n "${FAKE_DWM:-}" ]] || exit 1; echo "$FAKE_DWM"'
}

H="$SB/home"
A="$H/.config/autostart"
mkdir -p "$A" "$SB/run" "$SB/proc/4242"
entry() { printf '[Desktop Entry]\nType=Application\nName=%s\nExec=%s\n%b' "$1" "app-$1" "${2:-}" >"$A/$1.desktop"; }
entry alpha
entry broken 'Hidden=maybe\n'
entry gnomeoff 'X-GNOME-Autostart-enabled=false\n'
entry actionkey '\n[Desktop Action x]\nX-GNOME-Autostart-enabled=false\n'
entry zulu

# run [args...] — the script with DBUS / FAKE_DWM from the caller.
run() {
    : >"$LOG"
    env -i PATH="$BIN" HOME="$H" XDG_CONFIG_HOME="$H/.config" XDG_RUNTIME_DIR="$SB/run" \
        XDG_CACHE_HOME="$H/.cache" DBUS_SESSION_BUS_ADDRESS="${BUS:-}" FAKE_DWM="${FAKE_DWM:-}" \
        DOTS_PROC="$SB/proc" LOG="$LOG" "$(type -P bash)" "$SCRIPT" "$@" >"$SB/out" 2>&1
}
started() { grep -qx "run $1.desktop" "$LOG"; }
not_started() { ! grep -q " $1.desktop$" "$LOG"; }
nothing() { [[ ! -s "$LOG" ]]; }
not_in_out() { ! grep -q "$1" "$SB/out"; }

blue "==> a new session"
BUS=unix:path=/tmp/dbus-A,guid=1
rc=0
run || rc=$?
goods_started() { started alpha && started zulu && started actionkey; }
check "good entries start, each through its own dex run" goods_started
check "the broken entry costs only itself" not_started broken
check "...and is reported, by name" grep -q 'could not start .*broken.desktop' "$SB/out"
check "...with a non-zero exit" test "$rc" -ne 0
check "X-GNOME-Autostart-enabled=false is skipped" not_started gnomeoff
check "the session is recorded under XDG_RUNTIME_DIR" grep -qx "bus $BUS" "$SB/run/dots/xdg-autostart.session"

blue "==> the same session again (a dwm restart re-ran autostart.sh)"
run || true
check "nothing starts twice" nothing
blue "==> a new login (new bus)"
BUS=unix:path=/tmp/dbus-B,guid=2
run || true
check "everything starts again" goods_started
run --force || true
check "--force runs even in the same session" started alpha
run --list || true
dry_only() { grep -qx "dry alpha.desktop" "$LOG" && ! grep -q "^run " "$LOG"; }
check "--list asks dex for a dry run only" dry_only
check "...shows the GNOME-disabled skip" grep -q 'Skipping (X-GNOME-Autostart-enabled=false)' "$SB/out"
check "...and leaves the session record alone" grep -qx "bus $BUS" "$SB/run/dots/xdg-autostart.session"

blue "==> no bus: dwm's PID and start time"
BUS=""
FAKE_DWM=4242
printf '4242 (dwm) S 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 777 19\n' >"$SB/proc/4242/stat"
run || true
check "first run starts" started alpha
check "...recording pid and start time" grep -qx 'dwm 4242 777' "$SB/run/dots/xdg-autostart.session"
run || true
check "the same dwm (restarted by exec) starts nothing" nothing
sed -i 's/ 777 / 778 /' "$SB/proc/4242/stat"
run || true
check "a new dwm with a recycled PID starts again" started alpha
FAKE_DWM=""

blue "==> nothing to do"
rm "$BIN/dex"
run
check "no dex: exits 0 and says why" grep -q 'dex is not installed' "$SB/out"
# shellcheck disable=SC2016 # expands when the fake runs
fake "$BIN" dex 'echo "$*" >>"$LOG"'
rm -rf "$A"
run
check "no autostart directory: dex is never called" nothing
rc=0
run --bogus || rc=$?
check "an unknown argument exits 2" test "$rc" -eq 2

blue "==> the real dex (where installed)"
if REAL="$(type -P dex)"; then
    mkdir -p "$A" && entry alpha && entry gnomeonly 'OnlyShowIn=GNOME;\n'
    ln -sf "$REAL" "$BIN/dex"
    run --list || true
    check "real dex: a plain entry is listed" grep -q 'Executing command: app-alpha' "$SB/out"
    check "real dex: an OnlyShowIn=GNOME entry is not" not_in_out app-gnomeonly
else
    yellow "  skip: dex is not installed here"
fi

echo
if [[ $FAIL -eq 0 ]]; then
    green "xdg-autostart: $PASS passed"
else
    red "xdg-autostart: $FAIL failed, $PASS passed"
    exit 1
fi
