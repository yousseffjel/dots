#!/usr/bin/env bash
# Exercises restore_pipewire (scripts/install-restore-pipewire.sh) and
# uninstall_pipewire (scripts/uninstall-pipewire.sh) on real files: a sandbox
# HOME, and DOTS_EXAMPLES_DIR pointing at fixture copies of the two example
# configs Void ships (/usr/share/examples/{wireplumber,pipewire}/...).
#
# What is asserted:
#   * both links are made, pointing at the examples, one LINK row each;
#   * a re-run changes nothing and appends no row;
#   * a file the user already has at a link's path is left alone, unclaimed;
#   * an example that is missing (package not installed) is skipped;
#   * --dry-run makes nothing;
#   * uninstall removes the links it made and the directories once empty,
#     and keeps a link the user has re-pointed since.

# The predicates are only called through check's "$@". See tests/pkg-repos.sh.
# shellcheck disable=SC2317,SC2329

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
# All four XDG variables: HOME alone leaks into the real install manifest.
export HOME="$SB/home" XDG_STATE_HOME="$SB/state" XDG_CONFIG_HOME="$SB/home/.config" \
    XDG_DATA_HOME="$SB/data" XDG_CACHE_HOME="$SB/cache" DOTS_EXAMPLES_DIR="$SB/examples"
mkdir -p "$HOME" "$SB/examples/wireplumber" "$SB/examples/pipewire"
# The real files' one effective line each (read from the packages, 2026-10-15).
echo 'context.exec = [ { path = "/usr/bin/wireplumber" args = "" } ]' \
    >"$SB/examples/wireplumber/10-wireplumber.conf"
echo 'context.exec = [ { path = "/usr/bin/pipewire" args = "-c pipewire-pulse.conf" } ]' \
    >"$SB/examples/pipewire/20-pipewire-pulse.conf"

# No red/green/blue of its own (CLAUDE.md rule 2): it sources global_fn.sh,
# then replaces them with plain ones so output is greppable.
# shellcheck source=../scripts/global_fn.sh
source "$DOTS_DIR/scripts/global_fn.sh"
red() { printf 'RED %s\n' "$*"; }
green() { printf '%s\n' "$*"; }
yellow() { green "$@"; }
blue() { green "$@"; }
# shellcheck source=../scripts/install-restore-pipewire.sh
source "$DOTS_DIR/scripts/install-restore-pipewire.sh"
# shellcheck source=../scripts/uninstall-pipewire.sh
source "$DOTS_DIR/scripts/uninstall-pipewire.sh"
DRY_RUN=0 ASSUME_YES=1

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then printf '\033[32m  ok    %s\033[0m\n' "$what"; else
        printf '\033[31m  FAIL  %s\033[0m\n' "$what"
        FAILS=$((FAILS + 1))
    fi
}
D="$HOME/.config/pipewire/pipewire.conf.d"
points() { [[ -L "$D/$1" && "$(readlink "$D/$1")" == "$SB/examples/$2" ]]; }
rows() { manifest_rows LINK | wc -l; }
said() { grep -qF -- "$1" "$SB/out"; }
fresh() { rm -rf "$HOME/.config" "$SB/state"; }

printf '\033[34m%s\033[0m\n' "==> a fresh restore"
fresh
restore_pipewire >"$SB/out" 2>&1
check "wireplumber linked" points 10-wireplumber.conf wireplumber/10-wireplumber.conf
check "pipewire-pulse linked" points 20-pipewire-pulse.conf pipewire/20-pipewire-pulse.conf
check "one LINK row each, path in column 3" \
    test "$(manifest_rows LINK | cut -f2,3 | tr '\t\n' ' |')" = "pipewire $D/10-wireplumber.conf|pipewire $D/20-pipewire-pulse.conf|"

printf '\033[34m%s\033[0m\n' "==> a re-run"
restore_pipewire >"$SB/out" 2>&1
check "no new rows" test "$(rows)" -eq 2
check "says already linked" said "already links"

printf '\033[34m%s\033[0m\n' "==> the user's own file is there"
fresh
mkdir -p "$D" && echo mine >"$D/10-wireplumber.conf"
restore_pipewire >"$SB/out" 2>&1
check "left untouched" test "$(cat "$D/10-wireplumber.conf")" = mine
check "...and unclaimed (only the other one has a row)" test "$(rows)" -eq 1

printf '\033[34m%s\033[0m\n' "==> wireplumber not installed"
fresh
mv "$SB/examples/wireplumber" "$SB/wp.bak"
restore_pipewire >"$SB/out" 2>&1
check "skipped, saying so" said "is wireplumber installed?"
check "...no link, no row for it" test "$(rows):$(find "$D" -name '10-*' | wc -l)" = "1:0"
mv "$SB/wp.bak" "$SB/examples/wireplumber"

printf '\033[34m%s\033[0m\n' "==> --dry-run"
fresh
DRY_RUN=1 restore_pipewire >"$SB/out" 2>&1
check "nothing made" test ! -e "$HOME/.config/pipewire"
DRY_RUN=0

printf '\033[34m%s\033[0m\n' "==> uninstall"
fresh
restore_pipewire >/dev/null 2>&1
uninstall_pipewire >"$SB/out" 2>&1
check "both links and both directories gone" test ! -e "$HOME/.config/pipewire"
fresh
restore_pipewire >/dev/null 2>&1
ln -sfn /somewhere/else "$D/20-pipewire-pulse.conf"
uninstall_pipewire >"$SB/out" 2>&1
check "a re-pointed link is kept" test "$(readlink "$D/20-pipewire-pulse.conf")" = /somewhere/else
check "...the other still removed" test ! -e "$D/10-wireplumber.conf"

if [[ $FAILS -eq 0 ]]; then
    printf '\033[32m%s\033[0m\n' "✓ pipewire config: linked once, removed exactly"
else
    printf '\033[31m%s\033[0m\n' "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
