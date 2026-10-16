#!/usr/bin/env bash
# rc and the fixture variables are read by the test that sources this.
# shellcheck disable=SC2034
# The sandbox for tests/live-disk.sh and tests/live-part-nodes.sh — SOURCED,
# never run on its own (tests/lib/ is outside run-tests.sh's depth-1 glob).
# The caller has already set -euo pipefail, SCRIPT_DIR, DOTS_DIR and the
# colour helpers.
#
# lsblk, findmnt, mountpoint and dialog are fakes on PATH. The lsblk fake
# answers each exact argument list from a file under $STATE/lsblk (written
# with `says`), and fails loudly on any other, so a changed lsblk call
# cannot pass on stale fixtures. The formats are the real tool's
# (util-linux 2.40.2 on the 20250202 ISO, 2.42 on the dev host). Every
# mutating tool only records its call. in_live runs code with the
# installer's modules sourced.

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
STATE="$SB/state" BIN="$SB/bin"
mkdir -p "$STATE/lsblk" "$BIN"
export STATE

cat >"$BIN/lsblk" <<'EOF'
#!/usr/bin/env bash
f="$STATE/lsblk/$(printf '%s' "$*" | tr '/ ' '_+')"
[[ -f $f ]] || { echo "fake lsblk: unexpected $*" >&2; exit 2; }
cat "$f"
EOF
cat >"$BIN/findmnt" <<'EOF'
#!/usr/bin/env bash
# findmnt -nvo SOURCE --mountpoint DIR, from "DIR SOURCE" lines.
awk -v d="${!#}" '$1 == d { print $2; f = 1 } END { exit !f }' "$STATE/mounts"
EOF
cat >"$BIN/dialog" <<'EOF'
#!/usr/bin/env bash
# Replies, one per call, from $STATE/replies; "CANCEL" exits 1.
n="$(cat "$STATE/n" 2>/dev/null || echo 0)"; n=$((n + 1)); echo "$n" >"$STATE/n"
r="$(sed -n "${n}p" "$STATE/replies")"
echo "$*" >>"$STATE/dialog-calls"
[[ $r == CANCEL ]] && exit 1
printf '%s' "$r"
EOF
cat >"$BIN/mountpoint" <<'EOF'
#!/usr/bin/env bash
awk -v d="${!#}" '$1 == d { f = 1 } END { exit !f }' "$STATE/mounts"
EOF
# Mutating tools only record. sfdisk also swaps in the table it "wrote",
# so the read-back after it sees the new layout.
for c in sfdisk udevadm mkfs.ext4 mkfs.vfat; do
    # The $* and $STATE belong to the fake, expanded when it runs.
    # shellcheck disable=SC2016
    printf '#!/usr/bin/env bash\necho "%s $*" >>"$STATE/called"\n' "$c" >"$BIN/$c"
done
# shellcheck disable=SC2016
echo 'cp "$STATE/after-sfdisk" "$STATE/lsblk/-nrpo+NAME,PARTN,PARTLABEL+_dev_vdc"' >>"$BIN/sfdisk"
# mount and umount -R record too, and keep the fake mount table true, as
# the real ones do: with a stale table the root mount would be skipped.
cat >"$BIN/mount" <<'EOF'
#!/usr/bin/env bash
echo "mount $*" >>"$STATE/called"
echo "$2 $1" >>"$STATE/mounts"
EOF
cat >"$BIN/umount" <<'EOF'
#!/usr/bin/env bash
echo "umount $*" >>"$STATE/called"
awk -v d="${!#}" '$1 != d && index($1, d "/") != 1' "$STATE/mounts" >"$STATE/m"
mv "$STATE/m" "$STATE/mounts"
EOF
chmod +x "$BIN"/*
: >"$STATE/mounts"

# says <lsblk args> — stdin becomes lsblk's answer to exactly those args.
says() { cat >"$STATE/lsblk/$(printf '%s' "$*" | tr '/ ' '_+')"; }

G=$((1024 * 1024 * 1024))
printf '%s\n' "/dev/vda disk $((20 * G)) 0" "/dev/vdb disk $((8 * G)) 0" "/dev/sda disk $((16 * G)) 0" \
    "/dev/sdb disk $((64 * G)) 0" "/dev/vdc disk $((20 * G)) 0" "/dev/vdd disk $((20 * G)) 0" \
    "/dev/vde disk $((20 * G)) 1" "/dev/zram0 disk $((4 * G)) 0" "/dev/sr0 rom $G 0" \
    "/dev/nvme0n1 disk $((500 * G)) 0" | says -dnrpbo NAME,TYPE,SIZE,RO
for d in vda vdc vdd sdb nvme0n1; do printf '\n\n' | says -nrpo LABEL "/dev/$d"; done
printf '\nVOID_LIVE\n' | says -nrpo LABEL /dev/sda
printf '\n\n' | says -nrpo MOUNTPOINT /dev/vda
printf '\n/run/media/my\\x20stick\n' | says -nrpo MOUNTPOINT /dev/sdb
printf '\n/mnt\n/mnt/boot\n' | says -nrpo MOUNTPOINT /dev/vdc
printf '\n[SWAP]\n' | says -nrpo MOUNTPOINT /dev/vdd
printf '\n\n' | says -nrpo MOUNTPOINT /dev/nvme0n1
for d in vda vdc nvme0n1; do echo 'QEMU HARDDISK   ' | says -dno MODEL "/dev/$d"; done
printf '/dev/vdc3 part\n/dev/vdc disk\n' | says -nrspo NAME,TYPE /dev/vdc3
printf '/dev/sdb1 part\n/dev/sdb disk\n' | says -nrspo NAME,TYPE /dev/sdb1
echo 'BOOT_IMAGE=/boot/vmlinuz root=live:CDLABEL=VOID_LIVE ro' >"$SB/cmdline"

rc=0
pass() { green "  ok: $1"; }
fail() {
    red "  FAIL: $1"
    printf '%s\n' "${2:-}" | sed 's/^/      /'
    rc=1
}
# in_live <code> — run code with the modules sourced, the fakes first on
# PATH, and the answers non-interactive unless the code says otherwise.
in_live() {
    (
        # Re-armed: bash clears set -e inside the caller's $().
        set -e
        PATH="$BIN:$PATH" LIVE_CMDLINE="$SB/cmdline" LIVE_TARGET=/mnt LIVE_INTERACTIVE=0 \
            LIVE_FIRMWARE=uefi DRY_RUN=1 LIVE_DISK_ANSWER="" LIVE_WIPE_ANSWER=""
        # shellcheck source=../../scripts/install-live-base.sh
        source "$DOTS_DIR/scripts/install-live-base.sh"
        # shellcheck source=../../scripts/install-live-disk.sh
        source "$DOTS_DIR/scripts/install-live-disk.sh"
        # shellcheck source=../../scripts/install-live-part.sh
        source "$DOTS_DIR/scripts/install-live-part.sh"
        # base.sh resets the firmware when sourced; the code may override it.
        LIVE_FIRMWARE=uefi
        eval "$1"
    ) 2>&1
    # The printed text is the verdict, not the status. `|| true` on the
    # subshell would switch set -e off inside it, unlike the installer's
    # plain calls, so the status is dropped here instead.
    true
}
