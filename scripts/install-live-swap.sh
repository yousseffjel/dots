#!/usr/bin/env bash
# The live-ISO installer's swap (scope J, decision 7, sized in J-3): zram
# first, a swapfile on root behind it.
#
#   zram      zramen's service, set to half of RAM with zstd (its own
#             defaults are a quarter and lz4), at zramen's priority 32767.
#   swapfile  /swapfile, the size of RAM, capped at 8 GiB and at a tenth of
#             the root partition; in fstab at priority 10, so it only takes
#             what zram cannot. Made only when this installer laid the disk
#             out: with --target the layout, and its swap, are the user's.
#
# Sourced by install-live.sh after install-live-base.sh (live_run, live_ok,
# LIVE_FIRMWARE), install-live-disk.sh (LIVE_DISK_BYTES) and
# install-live-config.sh (live_write). Never standalone.
#
# usage: source "$SCRIPT_DIR/install-live-swap.sh"
#
# LIVE_MEMINFO (/proc/meminfo) is read at call time, for tests. Both steps
# converge: a swapfile of the right size that mkswap already signed is
# kept, and fstab is regenerated on every run before the line is added.

LIVE_SWAP_CAP_MIB=8192
LIVE_SWAP_MIB=0
LIVE_SWAP_FSTAB="/swapfile none swap defaults,pri=10 0 0"

# live_swap_mib <disk-bytes> — the swapfile size in MiB. The root partition
# is the disk less partition 1, /boot and GPT's 1 MiB at each end.
live_swap_mib() {
    local ram_kib first=1024 tenth n
    ram_kib="$(awk '$1 == "MemTotal:" { print $2 }' "${LIVE_MEMINFO:-/proc/meminfo}")"
    [[ $LIVE_FIRMWARE == uefi ]] || first=1
    tenth=$((($1 / 1048576 - first - 1024 - 2) / 10))
    n=$((${ram_kib:-0} / 1024))
    if [[ $n -gt $LIVE_SWAP_CAP_MIB ]]; then n=$LIVE_SWAP_CAP_MIB; fi
    if [[ $n -gt $tenth ]]; then n=$tenth; fi
    echo "$n"
}

# live_swapfile_create — /swapfile in the mounted target. fallocate is safe
# for swap on ext4 (no holes); mkswap refuses a file that has any.
live_swapfile_create() {
    local f="$LIVE_TARGET/swapfile" bytes
    LIVE_SWAP_MIB="$(live_swap_mib "$LIVE_DISK_BYTES")"
    bytes=$((LIVE_SWAP_MIB * 1048576))
    if [[ $DRY_RUN -eq 0 && -f $f ]]; then
        if [[ "$(stat -c %s "$f")" -eq $bytes && "$(blkid -p -o value -s TYPE "$f" 2>/dev/null)" == swap ]]; then
            green "ok      swapfile ($LIVE_SWAP_MIB MiB) already there"
            return 0
        fi
        rm -f "$f"
    fi
    live_run fallocate -l "$bytes" "$f"
    live_run chmod 600 "$f"
    live_run mkswap -q "$f"
    live_ok "swapfile, $LIVE_SWAP_MIB MiB"
}

# live_swap_configure — after live_configure_system has written fstab: the
# swapfile's line (when there is one), zramen's settings and its service.
live_swap_configure() {
    local fstab="$LIVE_TARGET/etc/fstab" what="zram (half of RAM, zstd)"
    blue "==> swap"
    if [[ $LIVE_SWAP_MIB -gt 0 ]]; then
        what+=", then the $LIVE_SWAP_MIB MiB swapfile"
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would add to $fstab: $LIVE_SWAP_FSTAB"
        elif ! grep -qxF "$LIVE_SWAP_FSTAB" "$fstab"; then
            printf '%s\n' "$LIVE_SWAP_FSTAB" >>"$fstab"
        fi
    fi
    printf '%s\n' '# Written by the dots live installer (scope J, J-3): half of RAM, zstd.' \
        'export ZRAM_SIZE=50' 'export ZRAM_COMP_ALGORITHM=zstd' | live_write /etc/sv/zramen/conf 644
    live_run ln -sfn /etc/sv/zramen "$LIVE_TARGET/etc/runit/runsvdir/default/zramen"
    live_ok "$what"
}
