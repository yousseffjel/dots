#!/usr/bin/env bash
# `dots doctor`'s keyring check (scripts/doctor-keyring.sh). Its own file
# because tests/doctor.sh is at the 250-line cap. Checked:
#   * through the whole doctor, in the sandbox of tests/doctor.sh: unlocked
#     is ok; locked, no login keyring yet and no Secret Service each warn with
#     their own advice; no dwm or no bus asks nothing; no gdbus skips;
#   * the reply texts those fakes print are the REAL ones: check_keyring runs
#     against a real gnome-keyring-daemon on a private bus, started the way
#     ly's pam_gnome_keyring.so starts it (--login, password on stdin), with
#     the secrets component reached by D-Bus activation as an app reaches it.
#     Skipped where gnome-keyring or dbus-run-session is not installed (CI's
#     tests job); every branch is a real reply there, none is faked.
# SEALED PATH for the first half; the second half's HOME, XDG dirs and
# XDG_RUNTIME_DIR are all under the test's own temp dir.

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
# shellcheck source=lib/doctor-sandbox.sh
source "$SCRIPT_DIR/lib/doctor-sandbox.sh"

mapfile -t DAEMONS < <(daemon_names)
make_fakes
make_home

tsv() { run_doctor --tsv >"$SB/out.tsv" 2>&1 || true; }
row() { grep -qE "^$1	session	keyring	${2:-}" "$SB/out.tsv"; }
no_row() { ! grep -qE $'^[a-z]+\tsession\tkeyring\t' "$SB/out.tsv"; }
no_warnings() { ! grep -qE $'^(warn|fail)\t' "$SB/out.tsv"; }

blue "==> through the doctor (sandbox fakes)"
FAKE_KEYRING=unlocked tsv
check "unlocked: ok" row ok
check "...and the healthy install stays warning-free" no_warnings
FAKE_KEYRING=locked tsv
check "locked: warns, pointing at the login password" row warn '.*LOCKED.*login password'
FAKE_KEYRING=empty tsv
check "no login keyring yet: warns, log out and back in" row warn '.*no login keyring yet'
FAKE_KEYRING=absent tsv
check "no Secret Service: warns with the package to install" row warn '.*xbps-install gnome-keyring'
FAKE_NO_DWM=1 tsv
check "outside dwm: nothing asked" no_row
FAKE_NOBUS=1 tsv
check "no session bus: nothing asked (check_portal reports the bus)" no_row
rm "$BIN/gdbus"
tsv
check "no gdbus: skips" row skip
make_fakes

# real_check — check_keyring once, inside the private bus, as "status<TAB>text".
real_check() {
    (
        report() { printf '%s\t%s\n' "$1" "$4"; }
        pgrep() { return 0; } # "dwm is running"
        # shellcheck source=../scripts/doctor-keyring.sh
        source "$DOTS_DIR/scripts/doctor-keyring.sh"
        KEYRING_DEST="${1:-$KEYRING_DEST}"
        DISPLAY=:9 check_keyring
    )
}

# keyring_up <pid> — wait (5 s at most) for the daemon to open its control
# socket. A fixed sleep raced it: a query that came first made the bus
# activate a fresh daemon with no --login keyring, and "unlocked" read "empty".
keyring_up() {
    local _
    for _ in $(seq 50); do
        [[ -S "$XDG_RUNTIME_DIR/keyring/control" ]] && return 0
        kill -0 "$1" 2>/dev/null || return 1
        sleep 0.1
    done
    return 1
}

# keyring_down <pid> — stop it; one that already exited is not an error.
keyring_down() {
    kill "$1" 2>/dev/null || true
    wait "$1" 2>/dev/null || true
}

# The probe that runs inside dbus-run-session. Each line of its output is
# "<case><TAB><status><TAB><text>".
real_probe() {
    local pid
    real_check org.example.nosuchname | sed 's/^/absent\t/'
    # A daemon with no --login: the secrets component, no keyring at all.
    gnome-keyring-daemon --foreground --components=secrets >/dev/null 2>&1 &
    pid=$!
    keyring_up "$pid" || echo "empty	error	daemon did not start"
    real_check | sed 's/^/empty\t/'
    keyring_down "$pid"
    rm -rf "$XDG_RUNTIME_DIR/keyring"
    # What pam_gnome_keyring does: --login, the password on stdin. Then no
    # --start: the bus activates org.freedesktop.secrets, as for an app.
    printf 'pw' | gnome-keyring-daemon --foreground --login >/dev/null 2>&1 &
    pid=$!
    keyring_up "$pid" || echo "unlocked	error	daemon did not start"
    real_check | sed 's/^/unlocked\t/'
    timeout 10 gdbus call --session --dest org.freedesktop.secrets --object-path /org/freedesktop/secrets \
        --method org.freedesktop.Secret.Service.Lock "[objectpath '/org/freedesktop/secrets/aliases/default']" >/dev/null 2>&1 || true
    real_check | sed 's/^/locked\t/'
    keyring_down "$pid"
}

blue "==> against a real gnome-keyring (private bus)"
if ! command -v gnome-keyring-daemon >/dev/null 2>&1 || ! command -v dbus-run-session >/dev/null 2>&1; then
    yellow "  skip: gnome-keyring-daemon or dbus-run-session not installed"
else
    R="$SB/real"
    mkdir -p "$R/home" "$R/run"
    chmod 700 "$R/run"
    # No DISPLAY or WAYLAND_DISPLAY: no unlock prompt can reach a real screen.
    env -i PATH="$PATH" HOME="$R/home" XDG_RUNTIME_DIR="$R/run" XDG_CONFIG_HOME="$R/home/.config" \
        XDG_DATA_HOME="$R/home/.local/share" XDG_CACHE_HOME="$R/home/.cache" XDG_STATE_HOME="$R/home/.local/state" \
        DOTS_DIR="$DOTS_DIR" dbus-run-session -- bash -c "set -euo pipefail
            $(declare -f real_check keyring_up keyring_down real_probe); real_probe" >"$R/out" 2>"$R/err" || true
    # Each case must reach its OWN branch: every warn but "unlocked" would
    # also pass on the catch-all "does not answer" if only the status were read.
    check "real unlocked: ok — the activated daemon found the --login one" \
        grep -qE "^unlocked	ok	the keyring answers and is unlocked" "$R/out"
    check "real locked: the LOCKED warning" grep -qE "^locked	warn	the keyring is LOCKED" "$R/out"
    check "real empty: the no-login-keyring warning" grep -qE "^empty	warn	.*no login keyring yet" "$R/out"
    check "real absent: the no-Secret-Service warning" grep -qE "^absent	warn	no Secret Service on the bus" "$R/out"
fi

echo
if [[ $FAIL -eq 0 ]]; then
    green "doctor-keyring: $PASS passed"
else
    red "doctor-keyring: $FAIL failed, $PASS passed"
    exit 1
fi
