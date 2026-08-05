#!/usr/bin/env bash
# Builds every vendored suckless program (make only — never `make install`,
# never writes outside suckless/) to confirm the tree compiles. Matches the
# CI "build-suckless" job. Build dependencies are NOT installed by this
# script — install them yourself first (see scripts/install-suckless.sh's
# install_deps(), or run that script directly) or run this inside a
# toolbox/podman Fedora container per TESTING.md.
#
# usage: tests/build.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUCKLESS_DIR="$DOTS_DIR/suckless"
PROGRAMS=(dwm st dmenu dwmblocks slock)

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue()  { printf '\033[34m%s\033[0m\n' "$*"; }

for arg in "$@"; do
    case "$arg" in
        -h|--help) echo "usage: tests/build.sh"; exit 0 ;;
        *) red "unknown argument: $arg"; exit 1 ;;
    esac
done

FAIL=0
for prog in "${PROGRAMS[@]}"; do
    dir="$SUCKLESS_DIR/$prog"
    blue "==> building $prog"
    if make -C "$dir" clean >/dev/null && make -C "$dir"; then
        green "  ok: $prog"
    else
        red "  build failed: $prog"
        FAIL=1
    fi
done

if [[ $FAIL -eq 0 ]]; then
    green "✓ all suckless programs built"
else
    red "✗ one or more builds failed — see above"
fi
exit "$FAIL"
