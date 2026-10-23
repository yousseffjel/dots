#!/usr/bin/env bash
# `dots doctor`'s Qt check (check_qt, scripts/doctor-desktop.sh), through the
# whole doctor in the sandbox of tests/doctor.sh. Checked:
#   * QT_QPA_PLATFORMTHEME is read from dwm's /proc environ (faked under
#     DOTS_PROC), never from the doctor's own environment;
#   * ok when it is qt5ct or qt6ct and both confs name an existing colour file
#     (a ~ in the path included);
#   * warns when the session lacks it, a conf is missing, or the colour file
#     is not rendered yet; skips when another desktop set its own value, or
#     no dwm process is found;
#   * a healthy install with it ok stays free of warnings.
# SEALED PATH: the fakes in tests/lib/doctor-sandbox.sh are all it can reach.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
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
row() { grep -qE "^$1	theme	qt	${2:-}" "$SB/out.tsv"; }
no_warnings() { ! grep -qE $'^(warn|fail)\t' "$SB/out.tsv"; }

# session_env <entries...> — a dwm of ours in the fake /proc, with exactly
# this environment (NUL-separated, as the kernel writes it).
session_env() {
    rm -rf "$SB/proc/4242" && mkdir -p "$SB/proc/4242"
    echo dwm >"$SB/proc/4242/comm"
    printf '%s\0' PATH=/usr/bin "$@" >"$SB/proc/4242/environ"
}
colours="$H/.cache/dots/theme/qt-colors.conf"
confs() {
    mkdir -p "$H/.config/qt5ct" "$H/.config/qt6ct" "$(dirname "$colours")"
    printf '[Appearance]\ncolor_scheme_path=%s\n' "$colours" >"$H/.config/qt5ct/qt5ct.conf"
    printf '[Appearance]\ncolor_scheme_path=~/.cache/dots/theme/qt-colors.conf\n' >"$H/.config/qt6ct/qt6ct.conf"
    : >"$colours"
}

blue "==> check_qt"
confs
session_env QT_QPA_PLATFORMTHEME=qt5ct
tsv
# run_doctor starts the doctor under env -i, so its OWN environment has no
# QT_QPA_PLATFORMTHEME: an ok here can only come from dwm's environ.
check "qt5ct in dwm's environ (none in the doctor's own), both confs resolve (one through ~): ok" row ok
check "...and the healthy install stays warning-free" no_warnings
session_env QT_QPA_PLATFORMTHEME=qt6ct
tsv
check "qt6ct is accepted too" row ok
session_env
tsv
check "the session lacks it: warns, log out and back in" row warn '.*no QT_QPA_PLATFORMTHEME.*log out'
session_env QT_QPA_PLATFORMTHEME=kde
tsv
check "another desktop's value: skipped, not overridden" row skip '.*is kde'
session_env QT_QPA_PLATFORMTHEME=qt5ct
rm "$colours"
tsv
check "colour file not rendered yet: warns with the command" row warn '.*dots wallpaper --random'
: >"$colours"
rm "$H/.config/qt6ct/qt6ct.conf"
tsv
check "a conf missing: warns, re-run the restore stage" row warn '.*qt6ct.conf.*--only-restore'
confs
rm -rf "$SB/proc/4242"
tsv
check "no dwm process to read: skipped" row skip

echo
if [[ $FAIL -eq 0 ]]; then
    green "doctor-qt: $PASS passed"
else
    red "doctor-qt: $FAIL failed, $PASS passed"
    exit 1
fi
