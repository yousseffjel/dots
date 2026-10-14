#!/usr/bin/env bash
# Exercises install_tier (scripts/install-pkg-tiers.sh) — the loop that
# installs packages/core, desktop and extra.lst — against fake rpm and dnf on
# a sealed PATH.
#
# What is asserted:
#   * a package rpm already has is neither passed to dnf nor reported as
#     "installed:", only counted in one "N already installed" line — a re-run
#     used to print "installed:" for every package in every list;
#   * a missing package is installed, reported, and gets a PACKAGE row; an
#     already-present one gets none (uninstall must not remove it) — including
#     a list name that is only a Provides of the installed package (thunar,
#     provided by Fedora's Thunar);
#   * a dry run says "would install" only for what is missing, and never
#     "installed:";
#   * failures by tier: hard aborts, desktop is FAILED with its consequence,
#     extra is skipped — each with dnf's own last line.

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
    XDG_DATA_HOME="$SB/data" XDG_CACHE_HOME="$SB/cache" DB="$SB/rpmdb" LOG="$SB/calls.log" SB

seal_path "$SB/bin" bash grep sed tr mkdir touch cut sort cat mv rm tail wc awk
# shellcheck disable=SC2016 # the bodies expand when the fakes run
{
    # rpm -q <name> matches names; -q --whatprovides also matches the
    # "Provide=Package" lines of $SB/provides (real rpm: thunar -> Thunar).
    fake "$SB/bin" rpm '[[ "$1" == -q ]] || exit 1
if [[ "$2" == --whatprovides ]]; then
    grep -qx "$3" "$DB" && exit 0
    real=$(grep "^$3=" "$SB/provides" 2>/dev/null | cut -d= -f2)
    [[ -n "$real" ]] && grep -qx "$real" "$DB"
else
    grep -qx "$2" "$DB"
fi'
    fake "$SB/bin" dnf 'echo "dnf $*" >>"$LOG"
[[ " ${FAKE_FAIL:-} " == *" $3 "* ]] && { echo "No match for argument: $3" >&2; exit 1; }
echo "$3" >>"$DB"'
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
dnf_calls() { grep -c '^dnf install' "$LOG" || true; }
fresh() {
    rm -rf "$SB/state"
    printf '%s\n' "$@" >"$DB"
    : >"$LOG"
    FAILED_DESKTOP=() FAILED_EXTRA=()
}
# tier <mode> — install_tier on $SB/t.lst, in this shell (arrays must
# survive), output in $SB/out.
tier() { install_tier t "$SB/t.lst" "$1" >"$SB/out" 2>&1; }

printf 'git\nzsh\ntmux\nfzf\n' >"$SB/t.lst"

printf '\033[34m%s\033[0m\n' "==> a mix of present and missing"
fresh git zsh
tier extra
check "only the missing two reach dnf" test "$(dnf_calls)" -eq 2
check "dnf never asked for an installed package" not grep -q "install -y git" "$LOG"
check "the new ones are reported" said "installed: tmux"
check "an installed one is NOT reported as installed" not_said "installed: git"
check "one summary line for the rest" said "ok      2 already installed"
check "PACKAGE rows only for what this run installed" \
    test "$(manifest_rows PACKAGE | cut -f2 | sort | tr '\n' ' ')" = "fzf tmux "

printf '\033[34m%s\033[0m\n' "==> a re-run"
: >"$LOG"
tier extra
check "zero dnf calls" test "$(dnf_calls)" -eq 0
check "nothing claimed as installed" not_said "installed:"
check "all four counted" said "ok      4 already installed"

printf '\033[34m%s\033[0m\n' "==> dry run"
fresh git
DRY_RUN=1 tier extra
check "would install only the missing three" test "$(grep -c 'would install' "$SB/out")" -eq 3
check "not for an installed one" not_said "would install: git"
check "never says installed:" not_said "installed: "
check "no dnf, no rows" test "$(dnf_calls):$(manifest_rows PACKAGE | wc -l)" = "0:0"

printf '\033[34m%s\033[0m\n' "==> a list name that is a Provides (thunar -> Thunar)"
echo "thunar=Thunar" >"$SB/provides"
printf 'thunar\n' >"$SB/t2.lst"
fresh Thunar
install_tier t "$SB/t2.lst" desktop >"$SB/out" 2>&1
check "provided by an installed package: counted, no dnf" test "$(dnf_calls)" -eq 0
check "...and no PACKAGE row (uninstall must not remove Thunar)" test "$(manifest_rows PACKAGE | wc -l)" -eq 0

printf '\033[34m%s\033[0m\n' "==> failures by tier"
fresh git zsh
FAKE_FAIL=tmux tier extra
check "extra: skipped, run continues to fzf" said "installed: fzf"
check "...in FAILED_EXTRA" test "${FAILED_EXTRA[*]}" = tmux
check "...with dnf's own reason" said "dnf: No match for argument: tmux"
fresh git zsh
CONSEQUENCE[tmux]="the session manager key does nothing"
FAKE_FAIL=tmux tier desktop
check "desktop: FAILED with its consequence" said "FAILED: tmux — the session manager key does nothing"
check "...in FAILED_DESKTOP" test "${FAILED_DESKTOP[*]}" = tmux
fresh git zsh
rc=0
(FAKE_FAIL=tmux tier hard) || rc=$?
check "hard: aborts the run" test "$rc" -ne 0
check "...naming the package" grep -q "RED required package failed to install: tmux" "$SB/out"

if [[ $FAILS -eq 0 ]]; then
    printf '\033[32m%s\033[0m\n' "✓ pkg-tiers: reports what changed, skips what is there"
else
    printf '\033[31m%s\033[0m\n' "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
