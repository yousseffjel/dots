#!/usr/bin/env bash
# The live-ISO installer's disk choice (scope J, J-3): which disks may be
# erased and why the others may not, the DISK= + WIPE= pair, the
# typed-name confirmation, and a target mounted from another disk. Nothing
# here touches a real disk: the fakes are in tests/lib/live-disk-env.sh.
# The partition read-back and the resume are tests/live-part-nodes.sh; the
# layout against the real sfdisk and mkfs is tests/live-part-swap.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
# Called by the sourced modules, through in_live's eval.
# shellcheck disable=SC2329
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/live-disk-env.sh
source "$SCRIPT_DIR/lib/live-disk-env.sh"

blue "==> which disks may be erased"
out="$(in_live 'live_disk_list')"
if [[ "$(awk '{print $1}' <<<"$out" | tr '\n' ' ')" == "/dev/vda /dev/vdb /dev/sda /dev/sdb /dev/vdc /dev/vdd /dev/nvme0n1 " ]]; then
    pass "zram, a CD-ROM and a read-only disk are never listed"
else
    fail "live_disk_list" "$out"
fi
check_disk() { # <disk> <expect: ok | reason substring> <what>
    local got
    got="$(in_live "live_disk_check $1 && echo ELIGIBLE")"
    if [[ $2 == ok && $got == ELIGIBLE ]] || [[ $2 != ok && $got != *ELIGIBLE* && $got == *"$2"* ]]; then
        pass "$3"
    else
        fail "$3" "$got"
    fi
}
check_disk /dev/vda ok "an empty 20 GiB disk"
check_disk /dev/vdb "under the 12G minimum" "an 8 GiB disk is too small"
check_disk /dev/sda "holds the live medium" "the disk carrying the ISO's VOID_LIVE label"
check_disk /dev/sdb "in use at /run/media/my stick" "a disk mounted elsewhere (lsblk's \\x20 decoded)"
check_disk /dev/vdc ok "a disk mounted only under the target (an earlier run)"
check_disk /dev/vdd "in use at [SWAP]" "a disk holding active swap"
check_disk /dev/vde "not a writable whole disk" "a read-only disk"
check_disk /dev/vdc3 "not a writable whole disk" "a partition"
echo 'root=live:LABEL=MYUSB ro' >"$SB/cmdline"
printf '\nMYUSB\n' | says -nrpo LABEL /dev/vda
check_disk /dev/vda "holds the live medium" "the live label is read from the kernel command line"
printf '\n\n' | says -nrpo LABEL /dev/vda
echo 'BOOT_IMAGE=/boot/vmlinuz root=live:CDLABEL=VOID_LIVE ro' >"$SB/cmdline"

blue "==> DISK= and WIPE= (answers file)"
choose() { in_live "LIVE_DISK_ANSWER='$1' LIVE_WIPE_ANSWER='$2'; live_disk_choose && echo \"CHOSEN \$LIVE_DISK \$LIVE_DISK_BYTES\""; }
out="$(choose /dev/vda /dev/vda)"
if [[ $out == *"CHOSEN /dev/vda $((20 * G))"* ]]; then pass "DISK and WIPE agree: chosen"; else fail "agreeing pair" "$out"; fi
out="$(choose /dev/vda "")"
if [[ $out == *"WIPE must repeat DISK"* && $out != *CHOSEN* ]]; then pass "no WIPE: refused"; else fail "missing WIPE" "$out"; fi
out="$(choose /dev/vda /dev/vdc)"
if [[ $out == *"WIPE must repeat DISK"* && $out != *CHOSEN* ]]; then pass "WIPE names another disk: refused"; else fail "WIPE mismatch" "$out"; fi
out="$(choose "" "")"
if [[ $out == *"missing DISK"* && $out != *CHOSEN* ]]; then pass "no DISK and no --target: refused"; else fail "missing DISK" "$out"; fi
out="$(choose /dev/sda /dev/sda)"
if [[ $out == *"holds the live medium"* && $out != *CHOSEN* ]]; then pass "a named disk is still checked"; else fail "check after answers" "$out"; fi
echo '/mnt /dev/sdb1' >"$STATE/mounts"
out="$(choose /dev/vda /dev/vda)"
if [[ $out == *"mounted from /dev/sdb"* && $out != *CHOSEN* ]]; then pass "a target mounted from another disk: refused"; else fail "foreign target" "$out"; fi
echo '/mnt /dev/vdc3' >"$STATE/mounts"
out="$(choose /dev/vdc /dev/vdc)"
if [[ $out == *"CHOSEN /dev/vdc"* ]]; then pass "a target mounted from the chosen disk is allowed (resume)"; else fail "own target" "$out"; fi
: >"$STATE/mounts"
out="$(in_live "LIVE_DISK_ANSWER=/dev/vda; live_disk_answers_unused && echo PASSED")"
if [[ $out == *"Drop one"* && $out != *PASSED* ]]; then pass "--target with DISK in the answers: refused"; else fail "--target + DISK" "$out"; fi

blue "==> the dialog path: pick, then type the name"
pick() {
    printf '%s\n' "$@" >"$STATE/replies"
    rm -f "$STATE/n" "$STATE/dialog-calls"
    # Single quotes on purpose: in_live expands it, after sourcing.
    # shellcheck disable=SC2016
    out="$(in_live 'LIVE_INTERACTIVE=1; clear() { :; }; live_disk_choose && echo "CHOSEN $LIVE_DISK"')"
}
pick /dev/nvme0n1 nvme0n1 /dev/nvme0n1
if [[ $out == *"CHOSEN /dev/nvme0n1"* ]] && grep -q "is not /dev/nvme0n1" "$STATE/dialog-calls"; then
    pass "a mistyped name is asked again, the exact one accepted"
else
    fail "typed confirmation" "$out"
fi
menu="$(cat "$STATE/dialog-calls")"
if [[ $menu == *"/dev/vda 20G  QEMU HARDDISK"* && $menu != *"/dev/sda 16G"* && $menu == *"holds the live medium"* ]]; then
    pass "the menu offers eligible disks with size and model, and says why others are not"
else
    fail "menu items" "$menu"
fi
pick /dev/vda CANCEL
if [[ $out == *"Cancelled. Nothing was written."* && $out != *CHOSEN* ]]; then pass "Cancel at the confirmation stops"; else fail "cancel" "$out"; fi

exit "$rc"
