#!/usr/bin/env bash
# The ly build's pins (scripts/install-services-ly.sh) are well-formed and
# agree with each other. Offline: it reads the pins, it never fetches them.
# Bumping one pin without its partner is the failure this exists for, the
# same job tests/linter-pins.sh does for the linters.
#
# What is asserted:
#   * the commit is 40 hex digits and each sha256 is 64;
#   * the URLs carry the versions they claim (ly tag in the vendor URL, zig
#     version twice in the zig URL), so a version bump cannot leave a URL
#     behind;
#   * the zig pin meets ly's minimum (ly_zig_ok), and is a release, not -dev
#     (ly's README refuses dev builds);
#   * build deps are declared in packages/build.lst, which the install stage
#     installs before the services stage runs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=../scripts/install-services-ly.sh
source "$DOTS_DIR/scripts/install-services-ly.sh"

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}
# Both are called only through check's "$@". See tests/pkg-repos.sh.
# shellcheck disable=SC2317,SC2329
re() { [[ "$1" =~ $2 ]]; }
# The list captured first, not piped into grep -q: under pipefail an early
# grep exit can SIGPIPE the pipeline and read a match as a failure.
BUILD_LST="$(sed 's/#.*//' "$DOTS_DIR/packages/build.lst" | tr -s '[:space:]' '\n')"
# shellcheck disable=SC2317,SC2329
declared() { grep -qxF "$1" <<<"$BUILD_LST"; }

blue "==> pin shapes"
check "LY_COMMIT is 40 hex digits" re "$LY_COMMIT" '^[0-9a-f]{40}$'
check "LY_VENDOR_SHA256 is 64 hex digits" re "$LY_VENDOR_SHA256" '^[0-9a-f]{64}$'
check "ZIG_SHA256 is 64 hex digits" re "$ZIG_SHA256" '^[0-9a-f]{64}$'
check "LY_VERSION is x.y.z" re "$LY_VERSION" '^[0-9]+\.[0-9]+\.[0-9]+$'
check "ZIG_VERSION is a release x.y.z, not -dev" re "$ZIG_VERSION" '^[0-9]+\.[0-9]+\.[0-9]+$'

blue "==> pins agree"
check "the vendor URL is the v$LY_VERSION release" re "$LY_VENDOR_URL" "/releases/download/v$LY_VERSION/vendor\.tar\.zst$"
check "the zig URL is $ZIG_VERSION, x86_64-linux" re "$ZIG_URL" "^https://ziglang\.org/download/$ZIG_VERSION/zig-x86_64-linux-$ZIG_VERSION\.tar\.xz$"
check "zig $ZIG_VERSION meets ly's minimum $LY_MIN_ZIG" ly_zig_ok

blue "==> build deps are declared"
for p in "${LY_BUILD_DEPS[@]}"; do
    check "$p in packages/build.lst" declared "$p"
done

if [[ $FAILS -eq 0 ]]; then
    green "✓ ly pins: well-formed and consistent"
else
    red "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
