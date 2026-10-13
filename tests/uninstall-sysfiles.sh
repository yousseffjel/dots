#!/usr/bin/env bash
# Exercises scripts/uninstall-sysfiles.sh: the SYSFILE rows `dots drivers`
# writes for root-owned files it copied (today the touchpad snippet,
# scripts/drivers-laptop.sh), with SUDO empty and a sandbox directory.
#
# What is asserted:
#   * an unedited copy of a version the repo shipped is removed — the
#     current one, and an older one;
#   * an edited copy is kept, and named;
#   * a file already gone is fine; no rows means nothing to do;
#   * --dry-run removes nothing.
#
# "Shipped" is proved by git history, so DOTS_DIR is a throwaway repo with two
# committed versions of the file — the real file_matches_history runs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
# All four XDG variables: HOME alone leaks into the real install manifest.
export HOME="$SB/home" XDG_STATE_HOME="$SB/state" XDG_CONFIG_HOME="$SB/config" \
    XDG_DATA_HOME="$SB/data" XDG_CACHE_HOME="$SB/cache"

REL=config/xorg/40-dots-touchpad.conf
DOTS_DIR="$SB/repo"
mkdir -p "$DOTS_DIR/config/xorg" "$SB/etc"
git -C "$DOTS_DIR" init -q
echo "old version" >"$DOTS_DIR/$REL"
git -C "$DOTS_DIR" add "$REL"
git -C "$DOTS_DIR" -c user.name=t -c user.email=t@t commit -qm old
cp "$REAL_DOTS_DIR/$REL" "$DOTS_DIR/$REL"
git -C "$DOTS_DIR" -c user.name=t -c user.email=t@t commit -qam new

# No red/green/blue of its own (CLAUDE.md rule 2): it sources global_fn.sh and
# replaces them with plain ones, as tests/pkg-repos.sh does.
# shellcheck source=../scripts/global_fn.sh
source "$REAL_DOTS_DIR/scripts/global_fn.sh"
red() { printf '%s\n' "$*"; }
green() { red "$@"; }
yellow() { red "$@"; }
blue() { red "$@"; }
# shellcheck source=../scripts/uninstall-sysfiles.sh
source "$REAL_DOTS_DIR/scripts/uninstall-sysfiles.sh"
SUDO=() DRY_RUN=0 ASSUME_YES=1

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then printf '\033[32m  ok    %s\033[0m\n' "$what"; else
        printf '\033[31m  FAIL  %s\033[0m\n' "$what"
        FAILS=$((FAILS + 1))
    fi
}
# place <name> <content> — an installed file plus its SYSFILE row.
place() {
    printf '%s\n' "$2" >"$SB/etc/$1"
    manifest_append_row SYSFILE xorg "$SB/etc/$1" "$REL"
}
run() { OUT="$(uninstall_sysfiles 2>&1)"; }

printf '\033[34m%s\033[0m\n' "==> nothing claimed"
run
check "no rows: nothing to do" grep -q "no SYSFILE rows" <<<"$OUT"

printf '\033[34m%s\033[0m\n' "==> removal"
place current "$(cat "$DOTS_DIR/$REL")"
place older "old version"
place edited "my own settings"
DRY_RUN=1 run
check "dry run: nothing removed" test -e "$SB/etc/current" -a -e "$SB/etc/older"
check "dry run: said what it would do" grep -q "(dry-run) would remove $SB/etc/current" <<<"$OUT"
run
check "the current shipped version is removed" test ! -e "$SB/etc/current"
check "an older shipped version is removed" test ! -e "$SB/etc/older"
check "an edited copy is kept" test -e "$SB/etc/edited"
check "...and named" grep -q "kept $SB/etc/edited" <<<"$OUT"
run
check "a second run: already gone is fine" grep -q "already gone" <<<"$OUT"

if [[ $FAILS -eq 0 ]]; then
    printf '\033[32m%s\033[0m\n' "✓ uninstall-sysfiles: only unedited copies are removed"
else
    printf '\033[31m%s\033[0m\n' "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
