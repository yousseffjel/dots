#!/usr/bin/env bash
# Validates packages/*.lst syntax: one reasonably-named package per line
# after stripping comments/blank lines, no duplicates within a file, and no
# package listed in both core.lst and extra.lst. This is a fast, offline
# syntax check — it does NOT hit dnf/network; see the CI "install-dry-run"
# job (.github/workflows/ci.yml) for live repo validation of package names.
#
# usage: tests/pkglist.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGES_DIR="$DOTS_DIR/packages"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue()  { printf '\033[34m%s\033[0m\n' "$*"; }

for arg in "$@"; do
    case "$arg" in
        -h|--help) echo "usage: tests/pkglist.sh"; exit 0 ;;
        *) red "unknown argument: $arg"; exit 1 ;;
    esac
done

# Strips '#' comments (whole-line or trailing) and blank lines — same rule
# as read_pkg_list() in scripts/install-pkg.sh.
read_pkg_list() {
    sed 's/#.*//' "$1" | tr -s '[:space:]' '\n' | grep -v '^$'
}

FAIL=0

blue "==> checking package name format"
for list in "$PACKAGES_DIR"/core.lst "$PACKAGES_DIR"/extra.lst; do
    while IFS= read -r pkg; do
        if ! [[ "$pkg" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]]; then
            red "  invalid package name in $(basename "$list"): '$pkg'"
            FAIL=1
        fi
    done < <(read_pkg_list "$list")
done
[[ $FAIL -eq 0 ]] && green "  ok"

blue "==> checking for duplicates within each list"
for list in "$PACKAGES_DIR"/core.lst "$PACKAGES_DIR"/extra.lst; do
    dupes="$(read_pkg_list "$list" | sort | uniq -d)"
    if [[ -n "$dupes" ]]; then
        red "  duplicate entries in $(basename "$list"):"
        while IFS= read -r d; do red "    $d"; done <<< "$dupes"
        FAIL=1
    fi
done
[[ $FAIL -eq 0 ]] && green "  ok"

blue "==> checking core.lst and extra.lst don't overlap"
overlap="$(comm -12 \
    <(read_pkg_list "$PACKAGES_DIR/core.lst" | sort -u) \
    <(read_pkg_list "$PACKAGES_DIR/extra.lst" | sort -u))"
if [[ -n "$overlap" ]]; then
    red "  packages listed in both core.lst and extra.lst:"
    while IFS= read -r o; do red "    $o"; done <<< "$overlap"
    FAIL=1
else
    green "  ok"
fi

if [[ $FAIL -eq 0 ]]; then
    green "✓ package lists valid"
else
    red "✗ package list validation failed — see above"
fi
exit "$FAIL"
