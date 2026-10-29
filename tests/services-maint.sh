#!/usr/bin/env bash
# Exercises the services stage's system upkeep (scripts/install-services-maint.sh):
# the weekly TRIM script, the snooze-weekly link and the zram sysctl file, on
# a sandbox /etc, /proc/swaps and runit dirs, with SUDO empty.
#
# What is asserted:
#   * /etc/cron.weekly/fstrim is installed executable (run-parts skips
#     anything else), with a SYSFILE row; snooze-weekly is linked, with a
#     SERVICE row; without snooze installed it is skipped, with no row;
#   * the shipped script is valid sh and calls `fstrim -a`;
#   * zram in /proc/swaps: the sysctl file is installed, then applied now
#     through sysctl -p; already at the value: not applied again;
#   * no zram (disk swap only): no sysctl file at all;
#   * a re-run appends no row; an edited copy is kept, and never applied;
#   * --dry-run writes nothing.

# The predicates are only called through check's "$@". See tests/pkg-repos.sh.
# SC2016: the eval'd checks are single-quoted on purpose.
# shellcheck disable=SC2317,SC2329,SC2016

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
# All four XDG variables: HOME alone leaks into the real install manifest.
export HOME="$SB/home" XDG_STATE_HOME="$SB/state" XDG_CONFIG_HOME="$SB/config" \
    XDG_DATA_HOME="$SB/data" XDG_CACHE_HOME="$SB/cache" \
    DOTS_RUNIT_SV="$SB/sv" DOTS_RUNIT_SERVICE="$SB/service" DOTS_VIRT=none \
    DOTS_ETC="$SB/etc" DOTS_PROC_SWAPS="$SB/swaps" DOTS_PROC_SYS="$SB/sys"

# No red/green/blue of its own (CLAUDE.md rule 2): it sources global_fn.sh,
# then replaces them with plain ones so output is greppable.
# shellcheck source=../scripts/global_fn.sh
source "$DOTS_DIR/scripts/global_fn.sh"
red() { printf 'RED %s\n' "$*"; }
green() { printf '%s\n' "$*"; }
yellow() { green "$@"; }
blue() { green "$@"; }
# shellcheck source=../scripts/install-services-runit.sh
source "$DOTS_DIR/scripts/install-services-runit.sh"
# shellcheck source=../scripts/install-services-maint.sh
source "$DOTS_DIR/scripts/install-services-maint.sh"
SUDO=() DRY_RUN=0

# sysctl is faked: it records the call instead of writing the real /proc/sys.
mkdir -p "$SB/bin"
printf '#!/bin/sh\necho "sysctl $*" >>"%s"\n' "$SB/sysctl.log" >"$SB/bin/sysctl"
chmod 755 "$SB/bin/sysctl"
export PATH="$SB/bin:$PATH"

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then printf '\033[32m  ok    %s\033[0m\n' "$what"; else
        printf '\033[31m  FAIL  %s\033[0m\n' "$what"
        FAILS=$((FAILS + 1))
    fi
}
said() { grep -qF -- "$1" "$SB/out"; }
rows() { manifest_rows "$1" | cut -f2- | tr '\t\n' ' |'; }
TRIM="$SB/etc/cron.weekly/fstrim"
ZRAM="$SB/etc/sysctl.d/99-dots-zram.conf"
# box [snooze] [zram] — a fresh /etc, runit dirs, /proc/swaps and manifest.
box() {
    rm -rf "${SB:?}/etc" "$SB/sv" "$SB/service" "$SB/state" "$SB/sys" "$SB/sysctl.log"
    mkdir -p "$SB/sv" "$SB/service" "$SB/sys/vm"
    echo 60 >"$SB/sys/vm/swappiness"
    printf 'Filename\tType\tSize\tUsed\tPriority\n/swapfile file 8388604 0 10\n' >"$SB/swaps"
    local a
    for a in "$@"; do
        case "$a" in
            snooze) mkdir -p "$SB/sv/snooze-weekly" ;;
            zram) printf '/dev/zram0 partition 7864316 0 32767\n' >>"$SB/swaps" ;;
        esac
    done
}

printf '\033[34m%s\033[0m\n' "==> the shipped files"
check "the TRIM script is valid sh" sh -n "$DOTS_DIR/$MAINT_TRIM_REL"
check "...and trims every mounted file system" grep -qx 'exec fstrim -a' "$DOTS_DIR/$MAINT_TRIM_REL"
check "the sysctl file sets swappiness" grep -qE '^vm\.swappiness = [0-9]+$' "$DOTS_DIR/$MAINT_ZRAM_REL"

printf '\033[34m%s\033[0m\n' "==> snooze installed, swap on zram"
box snooze zram
services_maintenance >"$SB/out" 2>&1
check "fstrim installed, executable" test -x "$TRIM"
check "...identical to the repo's" cmp -s "$DOTS_DIR/$MAINT_TRIM_REL" "$TRIM"
check "snooze-weekly linked" test -L "$SB/service/snooze-weekly"
check "the sysctl file installed" cmp -s "$DOTS_DIR/$MAINT_ZRAM_REL" "$ZRAM"
check "...and not executable" test ! -x "$ZRAM"
check "SYSFILE rows for both" test "$(rows SYSFILE)" = "cron $TRIM $MAINT_TRIM_REL|sysctl $ZRAM $MAINT_ZRAM_REL|"
check "a SERVICE row for snooze-weekly" test "$(rows SERVICE)" = "snooze-weekly|"
check "applied now with sysctl -p" grep -qx "sysctl -q -p $ZRAM" "$SB/sysctl.log"
check "...and said so" said "applied vm.swappiness=180 now (was 60)"

printf '\033[34m%s\033[0m\n' "==> re-run: nothing new"
echo 180 >"$SB/sys/vm/swappiness"
rm -f "$SB/sysctl.log"
services_maintenance >"$SB/out" 2>&1
check "no new rows" test "$(rows SYSFILE)$(rows SERVICE)" = "cron $TRIM $MAINT_TRIM_REL|sysctl $ZRAM $MAINT_ZRAM_REL|snooze-weekly|"
check "already at the value: sysctl not run" test ! -e "$SB/sysctl.log"

printf '\033[34m%s\033[0m\n' "==> an edited sysctl file is the user's"
echo 60 >"$SB/sys/vm/swappiness"
echo 'vm.swappiness = 100' >"$ZRAM"
services_maintenance >"$SB/out" 2>&1
check "kept" grep -qx 'vm.swappiness = 100' "$ZRAM"
check "...and not applied" test ! -e "$SB/sysctl.log"

printf '\033[34m%s\033[0m\n' "==> disk swap only, no snooze"
box
services_maintenance >"$SB/out" 2>&1
check "no sysctl file without zram" test ! -e "$ZRAM"
check "...and it says why" said "no swap on zram"
check "fstrim still installed" test -x "$TRIM"
check "snooze-weekly skipped, no SERVICE row" eval '[[ ! -e $SB/service/snooze-weekly && -z $(rows SERVICE) ]]'

printf '\033[34m%s\033[0m\n' "==> --dry-run"
box snooze zram
DRY_RUN=1 services_maintenance >"$SB/out" 2>&1
check "nothing written" eval '[[ ! -e $SB/etc && ! -e $SB/service/snooze-weekly && ! -e $SB/sysctl.log ]]'
check "no rows" test -z "$(rows SYSFILE)$(rows SERVICE)"

if [[ $FAILS -eq 0 ]]; then
    printf '\033[32m%s\033[0m\n' "✓ services-maint: weekly TRIM, zram sysctl only on zram, reversible"
else
    printf '\033[31m%s\033[0m\n' "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
