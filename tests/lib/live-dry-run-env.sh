#!/usr/bin/env bash
# rc and the fixture variables are read by the test that sources this.
# shellcheck disable=SC2034
# The sandbox for tests/live-dry-run*.sh — SOURCED, never run on its own
# (tests/lib/ is outside run-tests.sh's depth-1 glob). The caller has
# already set -euo pipefail, SCRIPT_DIR, DOTS_DIR and red/green/blue.
#
# It makes $SB (removed on exit), fakes for lsblk, findmnt and mountpoint
# that answer from $STATE (formats captured from the real tools, see
# .claude/tasks/archive/live-core/context.md), recording fakes for every
# tool a dry run must never call, an answers file and fixture trees, and
# the two helpers: run (a dry run of install-live.sh) and check.

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
    # The disk stage (J-3): one empty 20 GiB disk.
    "-dnrpbo NAME,TYPE,SIZE,RO") echo "/dev/vda disk 21474836480 0" ;;
    "-nrpo LABEL" | "-nrpo MOUNTPOINT") printf '\n\n' ;;
    *) echo "fake lsblk: unexpected $*" >&2; exit 2 ;;
esac
EOF
for c in xbps-install xchroot xgenfstab dialog sfdisk udevadm mkfs.ext4 mkfs.vfat fallocate mkswap blkid cryptsetup loadkeys; do
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
echo 'MemTotal:        4194304 kB' >"$SB/meminfo"

# run <firmware> [args...] — a dry run with the current fake disk state,
# onto the mounted $T (--target). TARGET="" runs the disk stage instead.
run() {
    local efi="$SB/no-efi"
    [[ $1 == uefi ]] && {
        efi="$SB/efi"
        mkdir -p "$efi"
    }
    shift
    : >"$STATE/called"
    local where=(--target "$T")
    [[ -n ${TARGET+set} && -z $TARGET ]] && where=()
    set +e
    out="$(PATH="$BIN:$PATH" LIVE_CMDLINE="${CMDLINE:-$SB/cmdline-live}" LIVE_EFI_DIR="$efi" \
        LIVE_ZONEINFO_DIR="$SB/zi" LIVE_KEYMAP_DIR="$SB/km" LIVE_LOCALES_FILE="$SB/locales" \
        LIVE_MEMINFO="$SB/meminfo" bash "$DOTS_DIR/scripts/install-live.sh" --dry-run \
        "${where[@]}" "$@" 2>&1)"
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
