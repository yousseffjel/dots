#!/usr/bin/env bash
# install-live.sh --dry-run (scope J, J-1), against fake block devices: the
# right packages and GRUB commands for UEFI and for BIOS, every refusal
# made before a command is printed, and nothing ever run or written.
#
# lsblk, findmnt and mountpoint are fakes on PATH that print the formats
# captured from the real tools (.claude/tasks/live-core/context.md, step 1).
# One cross-check runs the REAL findmnt and lsblk through live_disk_of on
# this host, so a format drift fails here, not on someone's disk.
# xbps-install, xchroot, xgenfstab and dialog are fakes that only record
# being called: a dry run must never call them.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
STATE="$SB/state" BIN="$SB/bin" T="$SB/mnt"
mkdir -p "$STATE" "$BIN" "$T"
export STATE

# State files: mounts ("DIR SOURCE FSTYPE" per line), pttype, parttypes.
cat >"$BIN/mountpoint" <<'EOF'
#!/usr/bin/env bash
awk -v d="${!#}" '$1 == d { f = 1 } END { exit !f }' "$STATE/mounts"
EOF
cat >"$BIN/findmnt" <<'EOF'
#!/usr/bin/env bash
# findmnt -nvo SOURCE|FSTYPE --mountpoint DIR; exit 1 when nothing is mounted.
col="$2" dir="$4"
awk -v d="$dir" -v c="$col" '$1 == d { print (c == "SOURCE" ? $2 : $3); f = 1 } END { exit !f }' "$STATE/mounts"
EOF
cat >"$BIN/lsblk" <<'EOF'
#!/usr/bin/env bash
dev="${!#}"
case "$1 $2" in
    "-nrspo NAME,TYPE") printf '%s part\n%s disk\n' "$dev" "${dev%[0-9]}" ;;
    "-ndrpo PTTYPE") cat "$STATE/pttype" ;;
    "-nrpo PARTTYPE") printf '\n'; cat "$STATE/parttypes" ;;
    *) echo "fake lsblk: unexpected $*" >&2; exit 2 ;;
esac
EOF
for c in xbps-install xchroot xgenfstab dialog; do
    # The $* and $STATE belong to the fake, expanded when it runs.
    # shellcheck disable=SC2016
    printf '#!/usr/bin/env bash\necho "%s $*" >>"$STATE/called"\n' "$c" >"$BIN/$c"
done
chmod +x "$BIN"/*

# Single-quoted so the $ fields stay literal (same hash as live-answers.sh).
# shellcheck disable=SC2016
H6='$6$dotsTEST1$hmwaRIQo9Gf15e0pP1zaFWg8J31000TkbvDkltXxWUhZJNkfvT6pbnQUxQsow95stlBOn44W9KusWc/vVmZW1/'
printf '%s\n' 'HOSTNAME=voidbox' 'USERNAME=ysf' "USER_PASSWORD_HASH=$H6" \
    'TIMEZONE=UTC' 'KEYMAP=us' 'LOCALE=en_US.UTF-8' >"$SB/answers"
chmod 600 "$SB/answers"
echo 'BOOT_IMAGE=/boot/vmlinuz root=live:CDLABEL=VOID_LIVE ro init=/sbin/init' >"$SB/cmdline-live"
echo 'BOOT_IMAGE=/boot/vmlinuz root=UUID=1234 ro' >"$SB/cmdline-installed"

# The answers' locale/keymap/zone are checked against these, as on the ISO.
mkdir -p "$SB/zi" "$SB/km"
: >"$SB/zi/UTC"
: >"$SB/km/us.map.gz"
echo '#en_US.UTF-8 UTF-8' >"$SB/locales"

# run <firmware> [args...] — a dry run with the current fake disk state.
run() {
    local efi="$SB/no-efi"
    [[ $1 == uefi ]] && {
        efi="$SB/efi"
        mkdir -p "$efi"
    }
    shift
    : >"$STATE/called"
    set +e
    out="$(PATH="$BIN:$PATH" LIVE_CMDLINE="${CMDLINE:-$SB/cmdline-live}" LIVE_EFI_DIR="$efi" \
        LIVE_ZONEINFO_DIR="$SB/zi" LIVE_KEYMAP_DIR="$SB/km" LIVE_LOCALES_FILE="$SB/locales" \
        bash "$DOTS_DIR/scripts/install-live.sh" --dry-run --target "$T" "$@" 2>&1)"
    status=$?
    set -e
}

rc=0
fail() {
    red "  FAIL: $1 (status $status)"
    printf '%s\n' "$out" | sed 's/^/      /'
    rc=1
}
# check <description> <expect-status: 0|1> <must-match...> [-- <must-not-match...>]
check() {
    local what="$1" want="$2" p miss=0
    shift 2
    [[ $want -eq 0 && $status -eq 0 || $want -ne 0 && $status -ne 0 ]] || miss=1
    while [[ $# -gt 0 && $1 != -- ]]; do
        grep -qF -- "$1" <<<"$out" || miss=1
        shift
    done
    [[ ${1:-} == -- ]] && shift
    for p in "$@"; do ! grep -qF -- "$p" <<<"$out" || miss=1; done
    [[ ! -s $STATE/called && -z "$(ls -A "$T")" ]] || miss=1
    if [[ $miss -eq 0 ]]; then green "  ok: $what"; else fail "$what"; fi
}

blue "==> UEFI"
printf '%s\n' "$T /dev/vda2 ext4" "$T/boot/efi /dev/vda1 vfat" >"$STATE/mounts"
echo gpt >"$STATE/pttype"
echo c12a7328-f81f-11d2-ba4b-00a0c93ec93b >"$STATE/parttypes"
run uefi --answers "$SB/answers"
check "both kernels, grub and the EFI modules into the target" 0 \
    "xbps-install -Sy -r $T -R https://repo-default.voidlinux.org/current base-system linux-lts grub grub-x86_64-efi" \
    "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Void" \
    "--efi-directory=/boot/efi --removable" "xchroot $T xbps-reconfigure -fa" \
    "would set the ysf password (hash, chpasswd on stdin)" "xchroot $T passwd -l root" \
    '%wheel ALL=(ALL:ALL) ALL' "(dry-run) would be: GRUB installed" "dry run complete" -- "$H6" "i386-pc" "ok      base system installed"

printf '%s\n' "$T /dev/vda2 ext4" >"$STATE/mounts"
run uefi --answers "$SB/answers"
check "UEFI without the ESP mounted is refused" 1 "needs the EFI system partition" -- "would run"

blue "==> BIOS"
printf '%s\n' "$T /dev/vda2 ext4" >"$STATE/mounts"
printf '%s\n' 21686148-6449-6e6f-744e-656564454649 0fc63daf-8483-4772-8e79-3d69d8477de4 >"$STATE/parttypes"
run bios --answers "$SB/answers"
check "GRUB's boot code goes to the whole disk, no EFI package" 0 \
    "xchroot $T grub-install --target=i386-pc /dev/vda" "boot code written to /dev/vda" \
    -- "grub-x86_64-efi" "efi-directory"

echo 0fc63daf-8483-4772-8e79-3d69d8477de4 >"$STATE/parttypes"
run bios --answers "$SB/answers"
check "a GPT disk without a bios_grub partition is refused" 1 "needs a 1 MiB bios_grub partition" -- "would run"

echo dos >"$STATE/pttype"
run bios --answers "$SB/answers"
check "an MBR disk needs no bios_grub partition" 0 "has an MBR table" "--target=i386-pc /dev/vda"

blue "==> refusals"
CMDLINE="$SB/cmdline-installed" run bios --answers "$SB/answers"
check "an installed system (no root=live:) is refused" 1 "Not the Void live ISO" -- "would run"
printf '%s\n' "/elsewhere /dev/vda2 ext4" >"$STATE/mounts"
run bios --answers "$SB/answers"
check "an unmounted target is refused" 1 "Mount the new root filesystem at $T first" -- "would run"
printf '%s\n' "$T /dev/vda2 ext4" >"$STATE/mounts"
sed 's/^KEYMAP=.*/KEYMAP=nope/' "$SB/answers" >"$SB/bad" && chmod 600 "$SB/bad"
run bios --answers "$SB/bad"
check "bad answers are refused before any command" 1 "invalid KEYMAP" -- "would run"

blue "==> a password that did not land is caught"
# Plain chpasswd once exited 0 and set nothing (the BIOS VM run,
# 2026-10-16). live_check_password reads the shadow entry back instead.
mkdir -p "$SB/tgt/etc"
printf '%s\n' 'root:!x:20742::::::' 'ysf:!:20742:0:99999:7:::' "kept:$H6:20742::::::" >"$SB/tgt/etc/shadow"
check_pw() {
    (
        # Local to this subshell on purpose: each check sources afresh.
        # shellcheck disable=SC2030
        LIVE_TARGET="$SB/tgt"
        # shellcheck source=../scripts/install-live-config.sh
        source "$DOTS_DIR/scripts/install-live-config.sh"
        live_check_password "$1"
    ) >/dev/null 2>&1
}
if ! check_pw ysf && ! check_pw root && ! check_pw nobody && check_pw kept; then
    green "  ok: '!', a locked root and a missing user fail; a crypt hash passes"
else
    red "  FAIL: live_check_password"
    rc=1
fi

blue "==> the real host"
: >"$STATE/called"
set +e
out="$(bash "$DOTS_DIR/scripts/install-live.sh" --dry-run --target "$T" --answers "$SB/answers" 2>&1)"
status=$?
set -e
if grep -q 'root=live:' /proc/cmdline 2>/dev/null; then
    green "  skip: this host IS a live ISO"
else
    check "this host (not a live ISO) is refused with no overrides" 1 "Not the Void live ISO"
fi
root_src="$(findmnt -nvo SOURCE --mountpoint / 2>/dev/null || true)"
# Only where lsblk knows the root device: GitHub's ubuntu runners mount
# root from /dev/root, a name lsblk cannot resolve.
if [[ $root_src == /dev/* ]] && command -v lsblk >/dev/null && lsblk -n "$root_src" >/dev/null 2>&1; then
    disk="$(
        DRY_RUN=1
        # shellcheck source=../scripts/install-live-base.sh
        source "$DOTS_DIR/scripts/install-live-base.sh"
        live_disk_of /
    )"
    if [[ $disk == /dev/* && "$(lsblk -ndo TYPE "$disk")" == disk ]]; then
        green "  ok: the real findmnt/lsblk resolve / to a disk ($disk)"
    else
        red "  FAIL: live_disk_of / with the real tools gave '$disk' for $root_src"
        rc=1
    fi
else
    green "  skip: lsblk does not know / here ($root_src)"
fi

exit "$rc"
