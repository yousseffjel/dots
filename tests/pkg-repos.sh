#!/usr/bin/env bash
# Exercises the repos step (scripts/install-pkg-repos.sh) and its revert
# (scripts/uninstall-repos.sh) against fake xbps-query, xbps-install,
# xbps-remove and xbps-uhelper on a sealed PATH. On Void that step is one
# repository: the official nonfree repo, for sublime-text4.
#
# The fakes reproduce xbps-static 0.60.7, probed in a scratch root against
# the live repos (2026-10-15):
#   * installing void-repo-nonfree only adds a repo config; the nonfree index
#     is fetched by the NEXT `xbps-install -S`, so until then nothing from it
#     resolves;
#   * `xbps-query -L` prints "<count> <url> (RSA signed)" per synced repo;
#   * `xbps-query -i --repository=<url> -Rs ''` lists that repo only, "[*]"
#     marking installed packages and "[-]" the rest.
#
# What is asserted:
#   * a fresh run enables nonfree, re-syncs, installs sublime-text4, and
#     writes one REPO row plus one PACKAGE row;
#   * a re-run changes nothing: no install, no sync, no new rows;
#   * nonfree already enabled by the user: no REPO row (uninstall must not
#     remove what it did not add);
#   * enabling fails: sublime is not attempted, the failure is summarised;
#   * not glibc x86_64: skipped with the nvim fallback named;
#   * --dry-run: no xbps-install at all;
#   * uninstall keeps nonfree while a nonfree package is installed, removes
#     it once none is, and leaves a repo it never added alone.

# The predicates are only called through check's "$@". Both codes: SC2317
# for older shellcheck, SC2329 since 0.10.0 renamed it (tests/linter-pins.sh).
# shellcheck disable=SC2317,SC2329

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
# All four XDG variables: HOME alone leaks into the real install manifest.
export HOME="$SB/home" XDG_STATE_HOME="$SB/state" XDG_CONFIG_HOME="$SB/config" \
    XDG_DATA_HOME="$SB/data" XDG_CACHE_HOME="$SB/cache" \
    DB="$SB/pkgdb" LOG="$SB/calls.log" CONF="$SB/nonfree.conf" SYNCED="$SB/nonfree.synced"
NONFREE_URL=https://repo-default.voidlinux.org/current/nonfree
export NONFREE_URL

seal_path "$SB/bin" bash grep sed tr mkdir touch cut sort cat mv rm tail wc awk tee mktemp readlink dirname
# shellcheck disable=SC2016 # the bodies expand when the fakes run
{
    fake "$SB/bin" xbps-uhelper '[[ "$1" == arch ]] && echo "${FAKE_ARCH:-x86_64}"'
    # The nonfree packages a synced index offers.
    fake "$SB/bin" xbps-query 'nf="sublime-text4 unrar"
case "$1" in
-L) [[ -n "${FAKE_L_FAIL:-}" ]] && exit 1
    echo "14823 https://repo-default.voidlinux.org/current (RSA signed)"
    [[ -e "$SYNCED" ]] && echo "   67 $NONFREE_URL (RSA signed)"; exit 0 ;;
-i) [[ "$2" == "--repository=$NONFREE_URL" && -e "$SYNCED" ]] || exit 2
    for p in $nf; do grep -qx "$p" "$DB" && echo "[*] $p-1_1" || echo "[-] $p-1_1"; done; exit 0 ;;
-R) [[ " $nf " == *" $2 "* ]] && { [[ -e "$SYNCED" ]]; exit $?; }; exit 0 ;;
esac
grep -qx "$1" "$DB" || exit 2; echo "$1-1_1"'
    fake "$SB/bin" xbps-install 'echo "xbps-install $*" >>"$LOG"
case "$1" in
-S) [[ -e "$CONF" ]] && touch "$SYNCED"; exit 0 ;;
-y) shift
    for p in "$@"; do
        [[ "$p" == void-repo-nonfree && -n "${FAKE_NONFREE_FAIL:-}" ]] && { echo "ERROR: [trans] failed to download" >&2; exit 1; }
        [[ "$p" == sublime-text4 && ! -e "$SYNCED" ]] && { echo "ERROR: Package '"'"'$p'"'"' not found in repository pool." >&2; exit 2; }
    done
    for p in "$@"; do echo "$p" >>"$DB"; [[ "$p" == void-repo-nonfree ]] && touch "$CONF"; done; exit 0 ;;
esac; exit 1'
    fake "$SB/bin" xbps-remove 'echo "xbps-remove $*" >>"$LOG"; shift
for p in "$@"; do grep -qx "$p" "$DB" || exit 2; sed -i "/^$p\$/d" "$DB"
    [[ "$p" == void-repo-nonfree ]] && rm -f "$CONF" "$SYNCED"; done'
}
PATH="$SB/bin"

# No red/green/blue of its own (CLAUDE.md rule 2): it sources global_fn.sh,
# then replaces them with plain ones so output is greppable.
# shellcheck source=../scripts/global_fn.sh
source "$DOTS_DIR/scripts/global_fn.sh"
red() { printf 'RED %s\n' "$*"; }
green() { printf '%s\n' "$*"; }
yellow() { green "$@"; }
blue() { green "$@"; }
# install-pkg.sh sources the tier machinery (CONSEQUENCE, FAILED_*) first;
# the repos step writes into it.
PACKAGES_DIR="$SB"
# shellcheck source=../scripts/install-pkg-tiers.sh
source "$DOTS_DIR/scripts/install-pkg-tiers.sh"
# shellcheck source=../scripts/install-pkg-repos.sh
source "$DOTS_DIR/scripts/install-pkg-repos.sh"
# shellcheck source=../scripts/uninstall-repos.sh
source "$DOTS_DIR/scripts/uninstall-repos.sh"
# The drivers are their own test (tests/drivers.sh); here they only must run.
drivers_install() { echo "drivers_install" >>"$LOG"; }
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
said() { grep -qF -- "$1" "$SB/out"; }
logged() { grep -qxF -- "$1" "$LOG"; }
not_logged() { ! grep -qF -- "$1" "$LOG"; }
has() { grep -qx "$1" "$DB"; }
lacks() { ! has "$1"; }
rows() { manifest_rows "$1" | wc -l; }
fresh() {
    rm -rf "$SB/state" "$CONF" "$SYNCED"
    printf '%s\n' "$@" >"$DB"
    : >"$LOG"
    FAILED_EXTRA=()
}
: >"$SB/stdin"
install_run() { repos_install >"$SB/out" 2>&1 <"$SB/stdin"; }
uninstall_run() { uninstall_repos >"$SB/out" 2>&1 <"$SB/stdin"; }

printf '\033[34m%s\033[0m\n' "==> a fresh install"
fresh xbps
install_run
check "nonfree enabled" logged "xbps-install -y void-repo-nonfree"
check "...then the index re-synced" logged "xbps-install -S"
check "sublime-text4 installed after the sync" test "$(grep -n . "$LOG" | tr '\n' ' ')" = "1:xbps-install -y void-repo-nonfree 2:xbps-install -S 3:xbps-install -y sublime-text4 4:drivers_install "
check "one REPO row, naming the package" test "$(manifest_rows REPO)" = $'REPO\tpackage\tnonfree\tvoid-repo-nonfree'
check "one PACKAGE row, the editor" test "$(manifest_rows PACKAGE | cut -f2)" = sublime-text4
check "nothing failed" test "${#FAILED_EXTRA[@]}" -eq 0

printf '\033[34m%s\033[0m\n' "==> a re-run"
: >"$LOG"
install_run
check "no install, no sync" not_logged "xbps-install"
check "...the drivers still run" logged "drivers_install"
check "no new rows" test "$(rows REPO):$(rows PACKAGE)" = "1:1"

printf '\033[34m%s\033[0m\n' "==> nonfree already enabled by the user"
fresh xbps void-repo-nonfree
touch "$CONF" "$SYNCED"
install_run
check "not enabled again" not_logged "void-repo-nonfree"
check "no REPO row (uninstall must not remove it)" test "$(rows REPO)" -eq 0
check "sublime-text4 still installed" has sublime-text4

printf '\033[34m%s\033[0m\n' "==> enabling nonfree fails"
fresh xbps
FAKE_NONFREE_FAIL=1 install_run
check "sublime is not attempted" not_logged "sublime-text4"
check "the failure is summarised" test "${FAILED_EXTRA[*]}" = void-repo-nonfree
check "...naming the fallback" said "text files open in nvim instead"
check "no REPO row" test "$(rows REPO)" -eq 0

printf '\033[34m%s\033[0m\n' "==> not glibc x86_64"
fresh xbps
FAKE_ARCH=x86_64-musl install_run
check "skipped, no xbps-install" not_logged "xbps-install"
check "...saying why" said "nonfree has no sublime-text4 for x86_64-musl"

printf '\033[34m%s\033[0m\n' "==> --dry-run"
fresh xbps
DRY_RUN=1 install_run
check "no xbps-install at all" not_logged "xbps-install"
check "says what it would do" said "(dry-run) would install void-repo-nonfree"
DRY_RUN=0

printf '\033[34m%s\033[0m\n' "==> uninstall: kept while a nonfree package is installed"
fresh xbps
install_run
uninstall_run
check "kept, with the reason" said "kept void-repo-nonfree — installed packages still come from nonfree"
check "...still installed" has void-repo-nonfree

printf '\033[34m%s\033[0m\n' "==> uninstall: xbps cannot list its repositories"
FAKE_L_FAIL=1 uninstall_run
check "fails closed: kept" said "xbps-query -L failed — cannot tell what comes from nonfree, so it is kept"
check "...still installed" has void-repo-nonfree

printf '\033[34m%s\033[0m\n' "==> uninstall: removed once nothing comes from it"
sed -i '/^sublime-text4$/d' "$DB"
uninstall_run
check "xbps-remove void-repo-nonfree" logged "xbps-remove -y void-repo-nonfree"
check "...gone" lacks void-repo-nonfree
uninstall_run
check "a second uninstall: says it is gone, no call" said "void-repo-nonfree is no longer installed"

printf '\033[34m%s\033[0m\n' "==> uninstall: a repo it never added is left alone"
fresh xbps void-repo-nonfree
touch "$CONF" "$SYNCED"
uninstall_run
check "no REPO rows: nothing removed" not_logged "xbps-remove"
check "...said so" said "no REPO rows in manifest"

if [[ $FAILS -eq 0 ]]; then
    printf '\033[32m%s\033[0m\n' "✓ repos: nonfree added once, reverted only when unused"
else
    printf '\033[31m%s\033[0m\n' "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
