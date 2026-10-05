#!/usr/bin/env bash
# Runs the compositor block of the generated autostart.sh against fake GL
# stacks and asserts which picom backend it picks.
#
# WHY. picom's glx backend froze the screen on the first real install (Fedora
# 44 VM, virtio GPU without 3D acceleration, 2026-10-05): dwm and every client
# kept running, the display never repainted. The fix is a glxinfo probe in
# session_autostart_compositor; this test is what stops a later edit turning
# "glx only on a real GPU" back into "glx unless proven otherwise".
#
# HOW. The block is RUN, by /bin/sh, with PATH holding nothing but fakes — so
# `command -v glxinfo` can be made to fail, and no real picom, glxinfo or
# pgrep on this machine is ever touched. Only the compositor part is called,
# not the whole template: the other parts launch daemons that a PATH-only
# sandbox would still find by absolute path (dwm-lock), and
# tests/autostart-daemons.sh already covers the full file.
#
# The fake glxinfo output follows the layout mesa-demos' glxinfo.c prints for
# -B ("direct rendering: Yes|No", "OpenGL renderer string: ..."). It is taken
# from that source, not captured live: the dev host has no glxinfo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=../scripts/install-session-template.sh
source "$DOTS_DIR/scripts/install-session-template.sh"
# shellcheck source=../scripts/install-session-report.sh
source "$DOTS_DIR/scripts/install-session-report.sh"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

# `wait` so the backgrounded fake picom has written its log before we read it.
{
    session_autostart_compositor
    echo wait
} >"$SB/compositor.sh"

glx_output() {
    local direct="$1" renderer="$2"
    printf 'name of display: :0\ndisplay: :0  screen: 0\ndirect rendering: %s\n' "$direct"
    printf 'Extended renderer info (GLX_MESA_query_renderer):\n'
    printf '    Vendor: Mesa (0xffffffff)\n    Device: %s (0xffffffff)\n' "$renderer"
    printf 'OpenGL vendor string: Mesa\nOpenGL renderer string: %s\n' "$renderer"
}

# $1 case name; $2 glxinfo mode: absent | fail | <file with its stdout>;
# $3 "notimeout" to leave timeout off PATH; $4 "running" to make pgrep match.
run_case() {
    local fake="$SB/$1"
    mkdir -p "$fake"
    printf '#!/bin/sh\necho "$*" >>"%s/picom.log"\n' "$fake" >"$fake/picom"
    if [[ "${4:-}" == running ]]; then
        printf '#!/bin/sh\nexit 0\n' >"$fake/pgrep"
    else
        printf '#!/bin/sh\nexit 1\n' >"$fake/pgrep"
    fi
    [[ "${3:-}" == notimeout ]] || printf '#!/bin/sh\nshift\nexec "$@"\n' >"$fake/timeout"
    # The fake glxinfo reads its output with a loop, not cat: PATH holds only
    # fakes, so cat is not on it. Its $l belongs to the fake being written.
    # shellcheck disable=SC2016
    case "$2" in
        absent) ;;
        fail) printf '#!/bin/sh\necho "Error: unable to open display" >&2\nexit 1\n' >"$fake/glxinfo" ;;
        *) printf '#!/bin/sh\nwhile IFS= read -r l; do printf "%%s\\n" "$l"; done <"%s"\n' "$2" >"$fake/glxinfo" ;;
    esac
    chmod +x "$fake"/*
    env -i PATH="$fake" /bin/sh "$SB/compositor.sh"
    cat "$fake/picom.log" 2>/dev/null || true
}

rc=0
expect() {
    local name="$1" want="$2" got="$3"
    if [[ "$got" == "$want" ]]; then
        green "  ok: $name -> ${want:-<not launched>}"
    else
        red "  $name: expected '${want:-<not launched>}', got '${got:-<not launched>}'"
        rc=1
    fi
}

blue "==> picom backend chosen by the generated autostart.sh"
glx_output Yes 'llvmpipe (LLVM 19.1.7, 256 bits)' >"$SB/llvmpipe.out"
glx_output Yes 'softpipe' >"$SB/softpipe.out"
glx_output Yes 'AMD Radeon RX 6700 XT (radeonsi, navi22, LLVM 19.1.7, DRM 3.59)' >"$SB/radeon.out"
glx_output Yes 'virgl (AMD Radeon RX 6700 XT)' >"$SB/virgl.out"
glx_output No 'Mesa Intel(R) UHD Graphics 620 (KBL GT2)' >"$SB/indirect.out"

expect "llvmpipe (VM, no 3D accel)" "--backend xrender" "$(run_case llvmpipe "$SB/llvmpipe.out")"
expect "softpipe" "--backend xrender" "$(run_case softpipe "$SB/softpipe.out")"
expect "real GPU, direct" "--backend glx" "$(run_case radeon "$SB/radeon.out")"
expect "virgl (VM WITH 3D accel)" "--backend glx" "$(run_case virgl "$SB/virgl.out")"
expect "indirect rendering" "--backend xrender" "$(run_case indirect "$SB/indirect.out")"
expect "glxinfo not installed" "--backend xrender" "$(run_case absent absent)"
expect "glxinfo fails" "--backend xrender" "$(run_case fail fail)"
expect "timeout not installed" "--backend xrender" "$(run_case notimeout "$SB/radeon.out" notimeout)"
expect "picom already running" "" "$(run_case running "$SB/radeon.out" '' running)"

blue "==> report on an existing autostart.sh"
report() {
    (
        # Called indirectly from session_report_picom_probe. Both codes are
        # disabled for the 0.10.0 rename - see tests/autostart-daemons.sh.
        # shellcheck disable=SC2317,SC2329
        yellow() { printf '%s\n' "$*"; }
        session_report_picom_probe "$1"
    )
}
printf 'picom &\n' >"$SB/old-autostart.sh"
if grep -q -- 'without choosing a backend' <<<"$(report "$SB/old-autostart.sh")"; then
    green "  ok: a pre-probe picom line is reported"
else
    red "  a picom line with no --backend was NOT reported"
    rc=1
fi
if [[ -z "$(report "$SB/compositor.sh")" ]]; then
    green "  ok: the generated file is not reported"
else
    red "  the generated autostart.sh is reported as missing the probe"
    rc=1
fi
: >"$SB/no-picom.sh"
if [[ -z "$(report "$SB/no-picom.sh")" ]]; then
    green "  ok: a file without picom is left to session_report_daemon"
else
    red "  a file that never mentions picom got the probe warning too"
    rc=1
fi

if ((rc != 0)); then
    red "✗ picom backend probe"
    exit 1
fi
green "✓ picom backend probe"
