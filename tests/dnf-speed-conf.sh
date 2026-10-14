#!/usr/bin/env bash
# Exercises scripts/install-pkg-dnf.sh: dnf_speed_conf (the persistent dnf5
# drop-in, a SYSFILE row) and dnf_refresh (one makecache up front), with SUDO
# empty, a sandbox drop-in directory and a fake dnf on a sealed PATH.
#
# What is asserted:
#   * the shipped drop-in sets the four speed options under [main], with the
#     floor written as dnf parses it (20k = 20480, checked on Fedora 44);
#   * it is copied with a SYSFILE row of kind dnf; a re-run changes nothing;
#   * an edited copy is kept; --dry-run writes nothing;
#   * the real uninstall step removes what the install wrote (round trip,
#     with a WROTE check in between);
#   * dnf_refresh runs one makecache, says nothing alarming when it works,
#     never aborts when it fails, and runs no dnf in a dry run.
#
# "Shipped" is proved by git history, so DOTS_DIR is a throwaway repo with the
# drop-in committed — the real file_matches_history runs.

# The predicates are only called through check's "$@", which shellcheck
# cannot follow. Both codes, as in tests/pkg-repos.sh.
# shellcheck disable=SC2317,SC2329

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REL=config/dnf/30-dots-speed.conf

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
# All four XDG variables: HOME alone leaks into the real install manifest.
export HOME="$SB/home" XDG_STATE_HOME="$SB/state" XDG_CONFIG_HOME="$SB/config" \
    XDG_DATA_HOME="$SB/data" XDG_CACHE_HOME="$SB/cache" LOG="$SB/calls.log" \
    DOTS_DNF_CONF_DIR="$SB/libdnf5.conf.d"

DOTS_DIR="$SB/repo"
mkdir -p "$DOTS_DIR/config/dnf"
cp "$REAL_DOTS_DIR/$REL" "$DOTS_DIR/$REL"
git -C "$DOTS_DIR" init -q
git -C "$DOTS_DIR" add "$REL"
git -C "$DOTS_DIR" -c user.name=t -c user.email=t@t commit -qm conf

seal_path "$SB/bin" bash git grep sed tr mkdir touch cut sort cat mv rm tail awk cmp install mktemp date wc
# shellcheck disable=SC2016 # the body expands when the fake runs
fake "$SB/bin" dnf 'echo "dnf $*" >>"$LOG"; exit "${FAKE_DNF_RC:-0}"'
PATH="$SB/bin"

# No red/green/blue of its own (CLAUDE.md rule 2): it sources global_fn.sh and
# replaces them with plain ones, as tests/pkg-repos.sh does.
# shellcheck source=../scripts/global_fn.sh
source "$REAL_DOTS_DIR/scripts/global_fn.sh"
red() { printf 'RED %s\n' "$*"; }
green() { printf '%s\n' "$*"; }
yellow() { green "$@"; }
blue() { green "$@"; }
SCRIPT_DIR="$REAL_DOTS_DIR/scripts"
# shellcheck source=../scripts/install-pkg-dnf.sh
source "$REAL_DOTS_DIR/scripts/install-pkg-dnf.sh"
# shellcheck source=../scripts/uninstall-sysfiles.sh
source "$REAL_DOTS_DIR/scripts/uninstall-sysfiles.sh"
SUDO=() DRY_RUN=0 ASSUME_YES=1 FAILED_EXTRA=()
DST="$DOTS_DNF_CONF_DIR/30-dots-speed.conf"

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then printf '\033[32m  ok    %s\033[0m\n' "$what"; else
        printf '\033[31m  FAIL  %s\033[0m\n' "$what"
        FAILS=$((FAILS + 1))
    fi
}
not() { ! "$@"; }
said() { grep -qF -- "$1" "$SB/out"; }
rows() { manifest_rows SYSFILE | wc -l | tr -d ' '; }
# key=value under [main] — the only section the drop-in may have.
sets() { [[ "$(sed -n '/^\[main\]/,/^\[/p' "$REAL_DOTS_DIR/$REL")" == *$'\n'"$1"* ]]; }

blue "==> the shipped drop-in"
check "one section, [main]" test "$(grep -c '^\[' "$REAL_DOTS_DIR/$REL")" -eq 1
for kv in fastestmirror=True max_parallel_downloads=10 minrate=20k timeout=30; do
    check "sets $kv" sets "$kv"
done

blue "==> install"
dnf_speed_conf >"$SB/out" 2>&1
check "copied" cmp -s "$DOTS_DIR/$REL" "$DST"
check "SYSFILE row of kind dnf, with the repo path" \
    grep -qxF "SYSFILE"$'\t'"dnf"$'\t'"$DST"$'\t'"$REL" <<<"$(manifest_rows SYSFILE)"
dnf_speed_conf >"$SB/out" 2>&1
check "re-run: already current" said "already current"
check "re-run: still one row" test "$(rows)" -eq 1

blue "==> round trip through the real uninstall step"
check "WROTE: the file is there before uninstall" test -e "$DST"
uninstall_sysfiles >"$SB/out" 2>&1
check "uninstall removed it" test ! -e "$DST"

blue "==> never overwrites an edit; dry run writes nothing"
rm -rf "$SB/state"
mkdir -p "$DOTS_DNF_CONF_DIR"
printf '[main]\nminrate=1k\n' >"$DST"
dnf_speed_conf >"$SB/out" 2>&1
check "a file dots never wrote is kept" grep -qx 'minrate=1k' "$DST"
check "...and not claimed" test "$(rows)" -eq 0
rm -f "$DST"
DRY_RUN=1 dnf_speed_conf >"$SB/out" 2>&1
check "dry run: nothing written" test ! -e "$DST"
check "dry run: said what it would do" said "(dry-run) would install $DST"

blue "==> dnf_refresh"
: >"$LOG"
dnf_refresh >"$SB/out" 2>&1
check "one makecache" test "$(grep -c '^dnf makecache' "$LOG")" -eq 1
check "ok when it works" said "metadata current"
rc=0
FAKE_DNF_RC=1 dnf_refresh >"$SB/out" 2>&1 || rc=$?
check "a failed makecache never aborts" test "$rc" -eq 0
check "...but says so" said "dnf makecache failed"
: >"$LOG"
DRY_RUN=1 dnf_refresh >"$SB/out" 2>&1
check "dry run: no dnf at all" not test -s "$LOG"

if [[ $FAILS -eq 0 ]]; then
    green "✓ dnf-speed-conf: the drop-in installs, re-runs and uninstalls cleanly"
else
    red "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
