#!/usr/bin/env bash
# System upkeep for the services stage (2026-10-28): a weekly SSD TRIM, and
# swap tuning where swap is on zram. Sourced by install-services.sh, never
# standalone: assumes `set -euo pipefail`, DRY_RUN, SUDO, DOTS_DIR,
# global_fn.sh, the colour helpers and install-services-runit.sh
# (runit_enable).
#
#   TRIM   /etc/cron.weekly/fstrim (config/system/cron.weekly/fstrim), run by
#          snooze's snooze-weekly runit service (snooze is in desktop.lst).
#          Void schedules no TRIM and runs no cron by default, so an SSD
#          never learned which blocks were free. snooze-weekly keeps a
#          timestamp and runs a week the machine was off at the next boot,
#          which suits a laptop better than a fixed cron time.
#   zram   /etc/sysctl.d/99-dots-zram.conf (config/system/sysctl.d/), only
#          when /proc/swaps lists a zram device: swappiness 180 on a disk
#          swap would page out to the disk far too eagerly. Applied at once
#          as well as at boot, so it needs no reboot.
#
# Both files follow the SYSFILE contract (sysfile-lib.sh): an edited copy is
# kept, and uninstall-sysfiles.sh removes an unedited one. The service link
# is a SERVICE row, reverted by uninstall-runit.sh. A live sysctl value is
# not reverted; it lasts until the next boot.
#
# DOTS_ETC (/etc), DOTS_PROC_SWAPS (/proc/swaps) and DOTS_PROC_SYS
# (/proc/sys) are read at call time, for tests.

# shellcheck source=sysfile-lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/sysfile-lib.sh"

MAINT_TRIM_REL=config/system/cron.weekly/fstrim
MAINT_ZRAM_REL=config/system/sysctl.d/99-dots-zram.conf

services_maintenance() {
    blue "==> system upkeep"
    maint_trim
    maint_zram
}

maint_trim() {
    sysfile_install cron "$MAINT_TRIM_REL" "${DOTS_ETC:-/etc}/cron.weekly/fstrim" \
        "weekly SSD TRIM" \
        "the SSDs are trimmed once a week" \
        "no SSD TRIM runs: writes slow down as the drive fills" 755 || true
    runit_enable snooze-weekly || true
}

maint_zram() {
    local dst="${DOTS_ETC:-/etc}/sysctl.d/${MAINT_ZRAM_REL##*/}" want now
    if ! grep -q '^/dev/zram' "${DOTS_PROC_SWAPS:-/proc/swaps}" 2>/dev/null; then
        blue "  no swap on zram — swappiness left at the kernel's default"
        return 0
    fi
    sysfile_install sysctl "$MAINT_ZRAM_REL" "$dst" \
        "zram swap tuning" \
        "loaded at every boot" \
        "swap on zram keeps the kernel's disk-swap defaults" || return 0
    # Applied only while the installed file is ours; a kept, edited one is
    # the user's to load.
    [[ $DRY_RUN -eq 0 ]] && cmp -s "$DOTS_DIR/$MAINT_ZRAM_REL" "$dst" || return 0
    want="$(sed -n 's/^vm\.swappiness *= *//p' "$dst")"
    now="$(cat "${DOTS_PROC_SYS:-/proc/sys}/vm/swappiness" 2>/dev/null || true)"
    [[ "$now" == "$want" ]] && return 0
    if "${SUDO[@]}" sysctl -q -p "$dst"; then
        green "  applied vm.swappiness=$want now (was ${now:-unknown})"
    else
        yellow "  could not apply it now — it loads at the next boot, or run:  sudo sysctl -p $dst"
    fi
}
