#!/usr/bin/env bash
# The live-ISO installer's disk layout and swap (scope J, J-3), against the
# REAL sfdisk, mkfs.vfat, mkfs.ext4 and mkswap, on sparse image files. No
# root and no block device needed: sfdisk writes a GPT into a file, and the
# mkfs tools and mkswap format files.
#
#   - live_part_create writes the table the scope's layout table says, per
#     firmware (start, size, type GUID and GPT name of each partition).
#   - live_part_mkfs's options are accepted, and give the type and label.
#   - live_swap_mib: RAM, capped at 8 GiB and at a tenth of root.
#   - live_swapfile_create converges: kept when right, remade when not.
#   - live_swap_configure: one fstab line however often it runs, zramen's
#     settings, and its service link.
#
# The real tools are skipped (with a note) where they are missing; CI's
# runners have util-linux, e2fsprogs and dosfstools. udevadm and mountpoint
# are fakes, and lsblk is a fake that reads the partitions back out of the
# image with the real `sfdisk -d`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
BIN="$SB/bin"
mkdir -p "$BIN"
printf '#!/bin/sh\nexit 0\n' >"$BIN/udevadm"
printf '#!/bin/sh\nexit 1\n' >"$BIN/mountpoint"
cat >"$BIN/lsblk" <<'EOF'
#!/usr/bin/env bash
# lsblk -nrpo NAME,PARTN,PARTLABEL <image>, from the real sfdisk -d.
[[ "$1 $2" == "-nrpo NAME,PARTN,PARTLABEL" ]] || { echo "fake lsblk: unexpected $*" >&2; exit 2; }
echo "${!#}  "
sfdisk -d "${!#}" | sed -n 's/^\([^ ]*[^0-9]\)\([0-9]\+\) : .*name="\([^"]*\)".*/\1\2 \2 \3/p'
EOF
chmod +x "$BIN"/*

failed=0
pass() { green "  ok: $1"; }
fail() {
    red "  FAIL: $1"
    printf '%s\n' "${2:-}" | sed 's/^/      /'
    failed=1
}
have() { command -v "$1" >/dev/null 2>&1; }
# in_live <code> — the modules sourced in a subshell, for real (DRY_RUN=0).
in_live() {
    (
        # Re-armed: bash clears set -e inside the caller's $().
        set -e
        PATH="$BIN:$PATH" LIVE_TARGET="$SB/tgt" DRY_RUN=0 LIVE_FIRMWARE=uefi
        # shellcheck source=../scripts/install-live-base.sh
        source "$DOTS_DIR/scripts/install-live-base.sh"
        # shellcheck source=../scripts/install-live-disk.sh
        source "$DOTS_DIR/scripts/install-live-disk.sh"
        # shellcheck source=../scripts/install-live-part.sh
        source "$DOTS_DIR/scripts/install-live-part.sh"
        # shellcheck source=../scripts/install-live-config.sh
        source "$DOTS_DIR/scripts/install-live-config.sh"
        # shellcheck source=../scripts/install-live-swap.sh
        source "$DOTS_DIR/scripts/install-live-swap.sh"
        # base.sh resets the firmware when sourced; the code may override it.
        LIVE_FIRMWARE=uefi
        eval "$1"
    ) 2>&1
    # The printed text is the verdict, not the status. `|| true` on the
    # subshell would switch set -e off inside it, unlike the installer's
    # plain calls, so the status is dropped here instead.
    true
}

blue "==> the GPT layout, written by the real sfdisk"
if have sfdisk; then
    for fw in uefi bios; do
        img="$SB/$fw.img"
        truncate -s 13G "$img"
        # mkfs is recorded, not run: an image file has no partition nodes.
        out="$(in_live "LIVE_FIRMWARE=$fw LIVE_DISK=$img; live_part_mkfs() { echo \"MKFS \$1 \$2\"; }; live_part_create")"
        table="$(sfdisk -d "$img" | sed -n 's/^[^ ]*\([0-9]\) : start= *\([0-9]*\), size= *\([0-9]*\), type=\([^,]*\),.*name="\([^"]*\)".*/\1 \2 \3 \4 \5/p')"
        if [[ $fw == uefi ]]; then
            want1="1 2048 2097152 C12A7328-F81F-11D2-BA4B-00A0C93EC93B dots-esp"
            mk="MKFS esp ${img}1"
        else
            want1="1 2048 2048 21686148-6449-6E6F-744E-656564454649 dots-bios"
            mk="MKFS boot ${img}2"
        fi
        if [[ "$(sed -n 1p <<<"$table")" == "$want1" && "$(sed -n 2p <<<"$table")" == *" 2097152 0FC63DAF-8483-4772-8E79-3D69D8477DE4 dots-boot" &&
        "$(sed -n 3p <<<"$table")" == *" 0FC63DAF-8483-4772-8E79-3D69D8477DE4 dots-root" && "$(wc -l <<<"$table")" -eq 3 ]]; then
            pass "$fw: partition 1, a 1 GiB /boot, root on the rest"
        else
            fail "$fw table" "$table"
        fi
        if [[ $out == *"$mk"* && $out == *"MKFS root ${img}3"* ]] && { [[ $fw == uefi ]] || [[ $out != *"MKFS esp"* ]]; }; then
            pass "$fw: the nodes read back by name are the ones formatted"
        else
            fail "$fw mkfs targets" "$out"
        fi
    done
else
    yellow "  skip: no sfdisk here"
fi

blue "==> mkfs options, run for real"
if have mkfs.vfat && have mkfs.ext4 && have blkid; then
    truncate -s 300M "$SB/esp.img"
    truncate -s 64M "$SB/boot.img" "$SB/root.img"
    out="$(in_live "live_part_mkfs esp $SB/esp.img && live_part_mkfs boot $SB/boot.img && live_part_mkfs root $SB/root.img && echo MADE")"
    got="$(for f in esp boot root; do blkid -p -o value -s TYPE -s LABEL "$SB/$f.img" | tr '\n' ' '; done)"
    ver="$(blkid -p -o value -s VERSION "$SB/esp.img")"
    if [[ $out == *MADE* && $got == "EFI vfat boot ext4 void ext4 " && $ver == FAT32 ]]; then
        pass "a FAT32 ESP labelled EFI, ext4 /boot and root labelled boot and void"
    else
        fail "mkfs" "$out / $got / $ver"
    fi
else
    yellow "  skip: mkfs.vfat, mkfs.ext4 or blkid missing here"
fi

blue "==> swapfile size"
size() { # <ram-kib> <disk-GiB> <firmware>
    echo "MemTotal:       $1 kB" >"$SB/meminfo"
    in_live "LIVE_MEMINFO=$SB/meminfo LIVE_FIRMWARE=$3; live_swap_mib $(($2 * 1024 * 1024 * 1024))"
}
if [[ "$(size 4194304 64 uefi)" == 4096 ]]; then pass "4 GiB of RAM, a roomy disk: 4096 MiB"; else fail "RAM-sized" "$(size 4194304 64 uefi)"; fi
if [[ "$(size 33554432 500 uefi)" == 8192 ]]; then pass "32 GiB of RAM: capped at 8192 MiB"; else fail "8 GiB cap" "$(size 33554432 500 uefi)"; fi
if [[ "$(size 4194304 13 uefi)" == 1126 ]]; then pass "a 13 GiB disk, UEFI: a tenth of root (1126 MiB)"; else fail "tenth, uefi" "$(size 4194304 13 uefi)"; fi
if [[ "$(size 2097152 13 uefi)" == 1126 ]]; then pass "2 GiB of RAM, past a tenth but not a fifth of root: still 1126"; else fail "tenth vs RAM" "$(size 2097152 13 uefi)"; fi
if [[ "$(size 4194304 13 bios)" == 1228 ]]; then pass "the same disk on BIOS: root is 1 GiB bigger (1228 MiB)"; else fail "tenth, bios" "$(size 4194304 13 bios)"; fi

blue "==> the swapfile converges"
if have fallocate && have mkswap && have blkid; then
    mkdir -p "$SB/tgt"
    echo "MemTotal:       65536 kB" >"$SB/meminfo"
    mk() { in_live "LIVE_MEMINFO=$SB/meminfo LIVE_DISK_BYTES=$((64 * 1024 * 1024 * 1024)); live_swapfile_create"; }
    out="$(mk)"
    f="$SB/tgt/swapfile"
    ino="$(stat -c %i "$f" 2>/dev/null || true)"
    if [[ "$(stat -c '%s %a' "$f" 2>/dev/null)" == "67108864 600" && "$(blkid -p -o value -s TYPE "$f")" == swap ]]; then
        pass "64 MiB of RAM: a 64 MiB swapfile, mode 600, signed by mkswap"
    else
        fail "swapfile made" "$out"
    fi
    out="$(mk)"
    if [[ $out == *"already there"* && "$(stat -c %i "$f")" == "$ino" ]]; then pass "a re-run keeps it"; else fail "kept" "$out"; fi
    dd if=/dev/zero of="$f" bs=4096 count=2 conv=notrunc status=none
    out="$(mk)"
    if [[ $out != *"already there"* && "$(blkid -p -o value -s TYPE "$f")" == swap ]]; then
        pass "a file mkswap never signed is remade"
    else
        fail "unsigned" "$out"
    fi
    echo "MemTotal:       131072 kB" >"$SB/meminfo"
    out="$(mk)"
    if [[ "$(stat -c %s "$f")" == 134217728 ]]; then pass "a file of the wrong size is remade"; else fail "resized" "$out"; fi
else
    yellow "  skip: fallocate, mkswap or blkid missing here"
fi

blue "==> fstab, zramen and its service"
mkdir -p "$SB/tgt/etc/sv/zramen" "$SB/tgt/etc/runit/runsvdir/default"
echo 'UUID=abc / ext4 defaults 0 1' >"$SB/tgt/etc/fstab"
cfg() { in_live "LIVE_SWAP_MIB=$1; live_swap_configure; live_swap_configure"; }
out="$(cfg 2048)"
fstab="$SB/tgt/etc/fstab"
if [[ "$(grep -c '^/swapfile none swap defaults,pri=10 0 0$' "$fstab")" == 1 && "$(head -1 "$fstab")" == "UUID=abc / ext4 defaults 0 1" ]]; then
    pass "the swapfile line, once, at priority 10, after what was there"
else
    fail "fstab" "$(cat "$fstab")"
fi
conf="$SB/tgt/etc/sv/zramen/conf"
if grep -qx 'export ZRAM_SIZE=50' "$conf" && grep -qx 'export ZRAM_COMP_ALGORITHM=zstd' "$conf" \
    && [[ "$(readlink "$SB/tgt/etc/runit/runsvdir/default/zramen")" == /etc/sv/zramen ]]; then
    pass "zramen: half of RAM, zstd, service linked"
else
    fail "zramen" "$out"
fi
echo 'UUID=abc / ext4 defaults 0 1' >"$fstab"
out="$(cfg 0)"
if grep -q swapfile "$fstab"; then
    fail "--target wrote a swapfile line" "$(cat "$fstab")"
else
    pass "no swapfile (--target): no fstab line, zram only"
fi

exit "$failed"
