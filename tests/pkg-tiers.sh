#!/usr/bin/env bash
# Exercises install_tier (scripts/install-pkg-tiers.sh) — the loop that
# installs packages/core, desktop and extra.lst — and xbps_prepare
# (scripts/install-pkg-xbps.sh), against fake xbps-query and xbps-install on
# a sealed PATH.
#
# The fakes reproduce what the real xbps 0.60.7 does, probed with
# xbps-static against the live repos in a scratch root (2026-10-15):
#   * `xbps-query <name>`: exit 0 installed, 2 not;
#   * `xbps-query -R <name>`: exit 0 in the index, 2 not;
#   * `xbps-install -y a b` with one name not in the index installs NOTHING:
#     "ERROR: Package 'b' not found in repository pool.", exit 2. Any other
#     failure in a transaction also installs nothing.
#
# What is asserted:
#   * an installed package is neither passed to xbps-install nor reported as
#     "installed:", only counted in one "N already installed" line;
#   * a name not in the index is reported as failed BEFORE the transaction
#     and never reaches xbps-install, where it would sink the whole batch;
#   * every other missing package goes to ONE transaction, with stdin on
#     /dev/null (sudo's use_pty would make the terminal raw);
#   * a failed transaction installs nothing, so each package is retried alone
#     and the failure lands on the one that broke it;
#   * PACKAGE rows only for what this run installed; dry run says "would
#     install" only for what is missing;
#   * failures by tier: hard aborts, desktop is FAILED with its consequence,
#     extra is skipped — each with xbps's own last line;
#   * xbps_prepare: sync + xbps self-update, then the full upgrade, in that
#     order; neither failure is fatal; a dry run runs neither.

# The predicates are only called through check's "$@", which shellcheck
# cannot follow. Both codes, as in tests/pkg-repos.sh.
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
    XDG_DATA_HOME="$SB/data" XDG_CACHE_HOME="$SB/cache" DB="$SB/pkgdb" LOG="$SB/calls.log" SB

seal_path "$SB/bin" bash grep sed tr mkdir touch cut sort cat mv rm tail wc awk tee mktemp readlink
# shellcheck disable=SC2016 # the bodies expand when the fakes run
{
    # FAKE_UNAVAIL: names not in the repo index.
    fake "$SB/bin" xbps-query 'if [[ "$1" == -R ]]; then
    [[ " ${FAKE_UNAVAIL:-} " == *" $2 "* ]] && exit 2; exit 0
fi
grep -qx "$1" "$DB" || exit 2
echo "$1-1.0_1"'
    # xbps-install [-S][-y][-u] [pkg...]. FAKE_FAIL: names that fail to
    # install (a download or signature error) — the whole transaction then
    # installs nothing, as real xbps. FAKE_CONFLICT fails any transaction of
    # more than one package. FAKE_SYNC_FAIL / FAKE_UPGRADE_FAIL fail the two
    # prepare steps.
    fake "$SB/bin" xbps-install 'echo "xbps-install $*" >>"$LOG"
[[ "$(readlink /proc/$$/fd/0)" == /dev/null ]] || echo "STDIN NOT NULL" >>"$LOG"
flags="$1"; shift
case "$flags" in
    -Syu) [[ -n "${FAKE_SYNC_FAIL:-}" ]] && { echo "ERROR: [reposync] failed to fetch file" >&2; exit 1; }; exit 0 ;;
    -yu) [[ -n "${FAKE_UPGRADE_FAIL:-}" ]] && { echo "Transaction aborted due to unresolved shlibs." >&2; exit 19; }; exit 0 ;;
esac
for p in "$@"; do
    [[ " ${FAKE_UNAVAIL:-} " == *" $p "* ]] && { echo "ERROR: Package '"'"'$p'"'"' not found in repository pool." >&2; exit 2; }
done
[[ -n "${FAKE_CONFLICT:-}" && $# -gt 1 ]] && { echo "ERROR: transaction conflict" >&2; exit 11; }
for p in "$@"; do
    [[ " ${FAKE_FAIL:-} " == *" $p "* ]] && { echo "ERROR: $p-1.0_1: failed to download signature" >&2; exit 1; }
done
for p in "$@"; do echo "$p" >>"$DB"; done'
}
PATH="$SB/bin"

# No red/green/blue of its own (CLAUDE.md rule 2): it sources global_fn.sh and
# replaces them with plain ones, as tests/pkg-repos.sh does.
# shellcheck source=../scripts/global_fn.sh
source "$DOTS_DIR/scripts/global_fn.sh"
red() { printf 'RED %s\n' "$*"; }
green() { printf '%s\n' "$*"; }
yellow() { green "$@"; }
blue() { green "$@"; }
PACKAGES_DIR="$SB"
# shellcheck source=../scripts/install-pkg-tiers.sh
source "$DOTS_DIR/scripts/install-pkg-tiers.sh"
# shellcheck source=../scripts/install-pkg-xbps.sh
source "$DOTS_DIR/scripts/install-pkg-xbps.sh"
SUDO=() DRY_RUN=0

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
not_said() { ! said "$1"; }
not() { ! "$@"; }
installs() { grep -c '^xbps-install -y ' "$LOG" || true; }
fresh() {
    rm -rf "$SB/state"
    printf '%s\n' "$@" >"$DB"
    : >"$LOG"
    FAILED_DESKTOP=() FAILED_EXTRA=()
}
# tier <mode> — install_tier on $SB/t.lst, in this shell (arrays must
# survive), output in $SB/out. stdin is a regular file, never /dev/null: the
# runner may already give us /dev/null, which would hide a call that forgot
# to close its own.
tier() { install_tier t "$SB/t.lst" "$1" >"$SB/out" 2>&1 <"$SB/stdin"; }
: >"$SB/stdin"

printf 'git\nzsh\ntmux\nfzf\n' >"$SB/t.lst"

printf '\033[34m%s\033[0m\n' "==> a mix of present and missing"
fresh git zsh
tier extra
check "the missing two reach xbps in ONE transaction" test "$(installs)" -eq 1
check "...exactly those two" grep -qx "xbps-install -y tmux fzf" "$LOG"
check "...with stdin off the terminal (sudo would make it raw)" not grep -q "STDIN NOT NULL" "$LOG"
check "the new ones are reported" said "installed: tmux"
check "an installed one is NOT reported as installed" not_said "installed: git"
check "one summary line for the rest" said "ok      2 already installed"
check "PACKAGE rows only for what this run installed" \
    test "$(manifest_rows PACKAGE | cut -f2 | sort | tr '\n' ' ')" = "fzf tmux "

printf '\033[34m%s\033[0m\n' "==> a re-run"
: >"$LOG"
tier extra
check "zero xbps-install calls" test "$(installs)" -eq 0
check "nothing claimed as installed" not_said "installed:"
check "all four counted" said "ok      4 already installed"

printf '\033[34m%s\033[0m\n' "==> dry run"
fresh git
DRY_RUN=1 tier extra
check "would install only the missing three" test "$(grep -c 'would install' "$SB/out")" -eq 3
check "not for an installed one" not_said "would install: git"
check "never says installed:" not_said "installed: "
check "no xbps-install, no rows" test "$(installs):$(manifest_rows PACKAGE | wc -l)" = "0:0"

printf '\033[34m%s\033[0m\n' "==> dry run on a box whose index was never synced"
fresh git
# In a subshell: if it aborts, the check below must report it, not the
# abort take this whole test down with it.
rc=0
(FAKE_UNAVAIL="xbps zsh tmux fzf" DRY_RUN=1 tier hard) || rc=$?
check "hard tier does not abort" test "$rc" -eq 0
check "...all three listed, unchecked" test "$(grep -c 'would install' "$SB/out")" -eq 3
check "...and it says why" said "no synced repo index"
check "...nothing failed" test "${#FAILED_EXTRA[@]}:${#FAILED_DESKTOP[@]}" = "0:0"
fresh git
FAKE_UNAVAIL="tmux" DRY_RUN=1 tier extra
check "synced index: a dry run still reports an unknown name" said "xbps: not in the repository index (xbps-query -R tmux)"
check "...and no unsynced note" not_said "no synced repo index"

printf '\033[34m%s\033[0m\n' "==> a name not in the index never reaches the transaction"
fresh git zsh
FAKE_UNAVAIL=tmux tier extra
check "one transaction, without it" grep -qx "xbps-install -y fzf" "$LOG"
check "the rest still installed" said "installed: fzf"
check "it is skipped, with the reason" said "xbps: not in the repository index (xbps-query -R tmux)"
check "...in FAILED_EXTRA" test "${FAILED_EXTRA[*]}" = tmux
fresh git zsh
rc=0
(FAKE_UNAVAIL=tmux tier hard) || rc=$?
check "hard: an unknown name aborts before any install" test "$rc:$(installs)" = "1:0"

printf '\033[34m%s\033[0m\n' "==> failures by tier"
fresh git zsh
CONSEQUENCE[tmux]="the session manager key does nothing"
FAKE_UNAVAIL=tmux tier desktop
check "desktop: FAILED with its consequence" said "FAILED: tmux — the session manager key does nothing"
check "...in FAILED_DESKTOP" test "${FAILED_DESKTOP[*]}" = tmux
fresh git zsh
rc=0
(FAKE_CONFLICT=1 FAKE_FAIL=tmux tier hard) || rc=$?
check "hard: a package failing alone aborts" test "$rc" -ne 0
check "...naming the package" grep -q "RED required package failed to install: tmux" "$SB/out"

printf '\033[34m%s\033[0m\n' "==> a failed transaction: one package at a time"
fresh git zsh
FAKE_FAIL=tmux tier extra
check "said so, with xbps's own exit status" said "the transaction failed (xbps exit 1)"
check "the batch, then one run per package" test "$(installs)" -eq 3
check "the retried fzf installed, with its row" \
    test "$(said "installed: fzf" && manifest_rows PACKAGE | cut -f2)" = fzf
check "the one that fails alone is the one skipped" test "${FAILED_EXTRA[*]}" = tmux
check "...with xbps's own reason" said "xbps: ERROR: tmux-1.0_1: failed to download signature"

printf '\033[34m%s\033[0m\n' "==> xbps_prepare: sync + self-update, then the full upgrade"
: >"$LOG"
xbps_prepare >"$SB/out" 2>&1 <"$SB/stdin"
check "two calls, in order" test "$(tr '\n' '|' <"$LOG")" = "xbps-install -Syu xbps|xbps-install -yu|"
check "said up to date" said "system up to date"
: >"$LOG"
FAKE_SYNC_FAIL=1 xbps_prepare >"$SB/out" 2>&1 <"$SB/stdin"
check "sync fails: warned, no upgrade attempted, not fatal" \
    test "$(said "could not sync" && wc -l <"$LOG")" = 1
: >"$LOG"
FAKE_UPGRADE_FAIL=1 xbps_prepare >"$SB/out" 2>&1 <"$SB/stdin"
check "upgrade fails: warned with the command to run" said "run: sudo xbps-install -Su"
: >"$LOG"
DRY_RUN=1 xbps_prepare >"$SB/out" 2>&1
check "dry run: no xbps call" test ! -s "$LOG"

if [[ $FAILS -eq 0 ]]; then
    printf '\033[32m%s\033[0m\n' "✓ pkg-tiers: reports what changed, skips what is there"
else
    printf '\033[31m%s\033[0m\n' "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
