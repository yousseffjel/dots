#!/usr/bin/env bash
# Exercises picom's backend choice: config/dwm/bin/dwm-picom against fake GL
# stacks and fake hypervisors, the autostart.sh block that runs it, and the
# report an existing autostart.sh gets.
#
# WHY. picom's glx backend froze the screen on the first real install (Fedora
# 44 VM, virtio GPU without 3D acceleration, 2026-10-05): dwm and every client
# kept running, the display never repainted. Since 2026-10-14 the decision
# lives in dwm-picom — VM -> xrender always; glx only on bare-metal hardware
# 3D. This test is what stops a later edit turning that back into "glx unless
# proven otherwise".
#
# HOW. dwm-picom runs under `env -i` with PATH holding nothing but fakes and
# the few real tools it needs (sed, grep) — so `command -v glxinfo` can be
# made to fail, and no real picom, glxinfo, pgrep or systemd-detect-virt on
# this machine is touched. The autostart block is RUN by /bin/sh the same way.
#
# The fake glxinfo output follows the layout mesa-demos' glxinfo.c prints for
# -B ("direct rendering: Yes|No", "OpenGL renderer string: ..."). It is taken
# from that source, not captured live: the dev host has no glxinfo. The fake
# systemd-detect-virt mirrors `--vm`: the hypervisor's name and exit 0, or
# "none" and exit 1.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUT="$DOTS_DIR/config/dwm/bin/dwm-picom"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"
# shellcheck source=../scripts/install-session-template.sh
source "$DOTS_DIR/scripts/install-session-template.sh"
# shellcheck source=../scripts/install-session-report.sh
source "$DOTS_DIR/scripts/install-session-report.sh"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

glx_output() {
    local direct="$1" renderer="$2"
    printf 'name of display: :0\ndisplay: :0  screen: 0\ndirect rendering: %s\n' "$direct"
    printf 'Extended renderer info (GLX_MESA_query_renderer):\n'
    printf '    Vendor: Mesa (0xffffffff)\n    Device: %s (0xffffffff)\n' "$renderer"
    printf 'OpenGL vendor string: Mesa\nOpenGL renderer string: %s\n' "$renderer"
}
glx_output Yes 'llvmpipe (LLVM 19.1.7, 256 bits)' >"$SB/llvmpipe.out"
glx_output Yes 'softpipe' >"$SB/softpipe.out"
glx_output Yes 'AMD Radeon RX 6700 XT (radeonsi, navi22, LLVM 19.1.7, DRM 3.59)' >"$SB/radeon.out"
glx_output Yes 'virgl (AMD Radeon RX 6700 XT)' >"$SB/virgl.out"
glx_output No 'Mesa Intel(R) UHD Graphics 620 (KBL GT2)' >"$SB/indirect.out"

# box <name> <glxinfo: absent|fail|hang|file> <virt: none|kvm|...> [notimeout] [running]
# — a fake machine; prints its directory.
box() {
    local d="$SB/box-$1"
    rm -rf "$d"
    # bash: dwm-picom's `#!/usr/bin/env bash` looks it up on PATH.
    seal_path "$d" sed grep cat bash
    # shellcheck disable=SC2016 # the bodies expand when the fakes run
    {
        fake "$d" picom 'echo "$*" >>"'"$d"'/picom.log"'
        fake "$d" pgrep "exit $([[ "${5:-}" == running ]] && echo 0 || echo 1)"
        [[ "${4:-}" == notimeout ]] || fake "$d" timeout 'shift; exec "$@"'
        if [[ "$3" == none ]]; then
            fake "$d" systemd-detect-virt 'echo none; exit 1'
        else
            fake "$d" systemd-detect-virt "echo $3"
        fi
        case "$2" in
            absent) ;;
            fail) fake "$d" glxinfo 'echo "Error: unable to open display" >&2; exit 1' ;;
            *) fake "$d" glxinfo "cat '$2'" ;;
        esac
    }
    printf '%s\n' "$d"
}
# pick <box dir> — dwm-picom's backend line.
pick() { env -i PATH="$1" "$(type -P bash)" "$SUT" backend 2>&1; }
# launched <box dir> — what `dwm-picom` (start) ran picom with.
launched() {
    env -i PATH="$1" "$(type -P bash)" "$SUT" >/dev/null 2>&1 || true
    cat "$1/picom.log" 2>/dev/null || true
}

rc=0
expect() {
    local name="$1" want="$2" got="$3"
    # $want is a glob on purpose: renderer strings carry version details.
    # shellcheck disable=SC2053
    if [[ "$got" == $want ]]; then
        green "  ok: $name -> ${got%%$'\n'*}"
    else
        red "  $name: expected '$want', got '${got:-<not launched>}'"
        rc=1
    fi
}
TAB=$'\t'

blue "==> dwm-picom backend: bare metal"
expect "real GPU, direct" "glx${TAB}hardware 3D (AMD Radeon*" "$(pick "$(box radeon "$SB/radeon.out" none)")"
expect "llvmpipe" "xrender${TAB}software rendering only (llvmpipe*" "$(pick "$(box llvm "$SB/llvmpipe.out" none)")"
expect "softpipe" "xrender${TAB}software rendering only*" "$(pick "$(box soft "$SB/softpipe.out" none)")"
expect "indirect rendering" "xrender${TAB}no direct rendering*" "$(pick "$(box indirect "$SB/indirect.out" none)")"
expect "glxinfo not installed" "xrender${TAB}glxinfo*missing*" "$(pick "$(box absent absent none)")"
expect "glxinfo fails" "xrender${TAB}no direct rendering" "$(pick "$(box fail fail none)")"
expect "timeout not installed" "xrender${TAB}*timeout*" "$(pick "$(box nt "$SB/radeon.out" none notimeout)")"

blue "==> dwm-picom backend: virtual machines"
expect "KVM with virgl 3D (glx froze the screen here)" "xrender${TAB}virtual machine (kvm)" \
    "$(pick "$(box virgl "$SB/virgl.out" kvm)")"
expect "VMware even with a hardware-looking renderer" "xrender${TAB}virtual machine (vmware)" \
    "$(pick "$(box vmw "$SB/radeon.out" vmware)")"
expect "KVM without 3D" "xrender${TAB}virtual machine (kvm)" "$(pick "$(box kvm "$SB/llvmpipe.out" kvm)")"
d="$(box over "$SB/radeon.out" kvm)"
expect "DOTS_VIRT=none overrides detection" "glx${TAB}*" "$(env -i PATH="$d" DOTS_VIRT=none "$(type -P bash)" "$SUT" backend)"

blue "==> dwm-picom start"
expect "real GPU: picom --backend glx" "--backend glx" "$(launched "$(box s1 "$SB/radeon.out" none)")"
expect "VM: picom --backend xrender" "--backend xrender" "$(launched "$(box s2 "$SB/virgl.out" kvm)")"
expect "picom already running: nothing launched" "" "$(launched "$(box s3 "$SB/radeon.out" none '' running)")"

blue "==> the autostart.sh block"
session_autostart_compositor >"$SB/compositor.sh"
echo wait >>"$SB/compositor.sh"
d="$(box blk "$SB/radeon.out" kvm)"
ln -s "$SUT" "$d/dwm-picom"
env -i PATH="$d" /bin/sh "$SB/compositor.sh" 2>/dev/null || true
expect "runs dwm-picom (a VM gets xrender)" "--backend xrender" "$(cat "$d/picom.log" 2>/dev/null || true)"
d="$(box nodwm "$SB/radeon.out" none)"
env -i PATH="$d" /bin/sh "$SB/compositor.sh" 2>/dev/null || true
expect "without dwm-picom on PATH: plain xrender, never glx" "--backend xrender" "$(cat "$d/picom.log" 2>/dev/null || true)"

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
out="$(report "$SB/old-autostart.sh")"
expect "pre-probe picom line: told about the freeze" "*freezes*" "$out"
expect "...and to switch to dwm-picom" "*dwm-picom &*" "$out"
# The inline probe's shape, literally — the $ is the file's, not ours.
# shellcheck disable=SC2016
printf 'picom_backend=xrender\npicom --backend "$picom_backend" &\n' >"$SB/probe-autostart.sh"
out="$(report "$SB/probe-autostart.sh")"
expect "inline-probe autostart (2026-10-05..13): told to switch" "*dwm-picom &*" "$out"
if [[ "$out" == *freezes* ]]; then
    red "  an inline probe already chooses a backend: no freeze warning expected"
    rc=1
fi
expect "the generated file is not reported" "" "$(report "$SB/compositor.sh")"
: >"$SB/no-picom.sh"
expect "a file without picom is left to session_report_daemon" "" "$(report "$SB/no-picom.sh")"

if ((rc != 0)); then
    red "✗ picom backend probe"
    exit 1
fi
green "✓ picom backend probe"
