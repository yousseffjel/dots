#!/usr/bin/env bash
# The touchpad cases of tests/drivers.sh (scope-h slot 4) — SOURCED by it,
# never run alone (tests/lib/ is outside run-tests.sh's depth-1 glob). Uses
# that file's machine/chassis/run/check helpers; split off at the 250-line cap.
#
# "Unedited" is proved from git history, and a slot's new file has none until
# it is committed. So these cases run against a throwaway repo ($REPO) holding
# two committed versions of the snippet, and point DOTS_DIR at it: the real
# file_matches_history is exercised, not a stub.

REL=config/xorg/40-dots-touchpad.conf
REPO="$SB/repo"
DST="$SB/xorg.conf.d/40-dots-touchpad.conf"
mkdir -p "$REPO/config/xorg"
git -C "$REPO" init -q
printf 'Section "InputClass"\n    Identifier "dots touchpad (old)"\nEndSection\n' >"$REPO/$REL"
git -C "$REPO" add "$REL"
git -C "$REPO" -c user.name=t -c user.email=t@t commit -qm old
OLD="$(cat "$REPO/$REL")"
cp "$DOTS_DIR/$REL" "$REPO/$REL"
git -C "$REPO" -c user.name=t -c user.email=t@t commit -qam new
tp_run() { DOTS_DIR="$REPO" run; }
tp_rows() { manifest_rows SYSFILE | wc -l; }

blue "==> touchpad: laptops only"
machine GenuineIntel none
chassis 9
tp_run
check "laptop: snippet installed" cmp -s "$DOTS_DIR/$REL" "$DST"
check "SYSFILE row with the repo path" row SYSFILE $'xorg\t'"$DST"$'\t'"$REL"
check "told to log in again" said "apply at your next login"
: >"$LOG"
tp_run
check "re-run: already current" said "already current"
check "re-run: still one row" test "$(tp_rows)" -eq 1
machine GenuineIntel none
chassis 3
tp_run
check "desktop: no snippet" test ! -e "$DST"
machine GenuineIntel kvm
chassis 1
tp_run
check "VM (unknown): no snippet" test ! -e "$DST"
machine GenuineIntel none
chassis 9
DRY_RUN=1 tp_run
check "dry run: nothing written" test ! -e "$DST"
check "dry run: said what it would do" said "(dry-run) would install $DST"

blue "==> touchpad: never overwrites what is not an unedited copy"
machine GenuineIntel none
chassis 9
tp_run
printf '%s\n' "$OLD" >"$DST"
tp_run
check "our unedited OLDER copy is replaced" cmp -s "$DOTS_DIR/$REL" "$DST"
printf '# my tweak\n' >>"$DST"
tp_run
check "an edited copy is kept" grep -q 'my tweak' "$DST"
check "...and said so" said "kept    $DST"
machine GenuineIntel none
chassis 9
mkdir -p "$SB/xorg.conf.d"
printf '%s\n' "$OLD" >"$DST"
tp_run
check "a file we never claimed is kept, even if it matches history" test "$(cat "$DST")" = "$OLD"
check "...and not claimed" test "$(tp_rows)" -eq 0

blue "==> touchpad: round trip through the real uninstall step"
# The writer (drivers_touchpad) and the reader (uninstall_sysfiles) agree on
# the SYSFILE field order only if this passes; each one's own test would not
# notice them drifting apart.
# shellcheck source=../../scripts/uninstall-sysfiles.sh
source "$DOTS_DIR/scripts/uninstall-sysfiles.sh"
machine GenuineIntel none
chassis 9
tp_run
check "installed" test -e "$DST"
ASSUME_YES=1 DOTS_DIR="$REPO" uninstall_sysfiles >"$SB/out" 2>&1
check "uninstall removed what drivers installed" test ! -e "$DST"
check "...and said so" grep -q "removed $DST" "$SB/out"

blue "==> touchpad: a failed write"
# A read-only directory stops only a non-root writer; root would just write.
if [[ $EUID -ne 0 ]]; then
    machine GenuineIntel none
    chassis 9
    mkdir -p "$SB/xorg.conf.d"
    chmod 555 "$SB/xorg.conf.d"
    tp_run
    chmod 755 "$SB/xorg.conf.d"
    check "reported in FAILED_EXTRA" grep -qx touchpad <<<"$(printf '%s\n' "${FAILED_EXTRA[@]}")"
    check "no SYSFILE row for a file that was not written" test "$(tp_rows)" -eq 0
else
    blue "  skipped: running as root"
fi
