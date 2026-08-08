#!/usr/bin/env bash
# Validates packages/*.lst syntax: one reasonably-named package per line
# after stripping comments/blank lines, no duplicates within a file, and no
# package listed in two different tiers. This is a fast, offline syntax
# check — it does NOT hit dnf/network; see the CI "install-dry-run" job
# (.github/workflows/ci.yml) for live repo validation of package names.
#
# Every check GLOBS packages/*.lst rather than naming the lists. That is
# deliberate: the repo went from two lists to four (core, build, desktop,
# extra) and a test that names them silently stops covering whichever one is
# added next. A new tier is picked up here for free.
#
# usage: tests/pkglist.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGES_DIR="$DOTS_DIR/packages"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

for arg in "$@"; do
    case "$arg" in
        -h | --help)
            echo "usage: tests/pkglist.sh"
            exit 0
            ;;
        *)
            red "unknown argument: $arg"
            exit 1
            ;;
    esac
done

# Strips '#' comments (whole-line or trailing) and blank lines — same rule
# as read_pkg_list() in scripts/install-pkg-tiers.sh.
read_pkg_list() {
    sed 's/#.*//' "$1" | tr -s '[:space:]' '\n' | grep -v '^$'
}

FAIL=0

LISTS=()
while IFS= read -r f; do LISTS+=("$f"); done < <(find "$PACKAGES_DIR" -maxdepth 1 -name '*.lst' | sort)

blue "==> discovering package lists"
if [[ ${#LISTS[@]} -eq 0 ]]; then
    red "  no packages/*.lst found at all — wrong PACKAGES_DIR, or the lists were removed"
    exit 1
fi
green "  found ${#LISTS[@]}: $(for l in "${LISTS[@]}"; do printf '%s ' "$(basename "$l")"; done)"

blue "==> checking package name format"
for list in "${LISTS[@]}"; do
    while IFS= read -r pkg; do
        if ! [[ "$pkg" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]]; then
            red "  invalid package name in $(basename "$list"): '$pkg'"
            FAIL=1
        fi
    done < <(read_pkg_list "$list")
done
[[ $FAIL -eq 0 ]] && green "  ok"

# A list that parses to nothing is almost always a header-comment mistake —
# one stray '#' can comment out an entire tier, and every consumer would then
# quietly install nothing from it.
blue "==> checking no list is empty"
for list in "${LISTS[@]}"; do
    if [[ "$(read_pkg_list "$list" | wc -l)" -eq 0 ]]; then
        red "  $(basename "$list") declares no packages at all"
        FAIL=1
    fi
done
[[ $FAIL -eq 0 ]] && green "  ok"

blue "==> checking for duplicates within each list"
for list in "${LISTS[@]}"; do
    dupes="$(read_pkg_list "$list" | sort | uniq -d)"
    if [[ -n "$dupes" ]]; then
        red "  duplicate entries in $(basename "$list"):"
        while IFS= read -r d; do red "    $d"; done <<<"$dupes"
        FAIL=1
    fi
done
[[ $FAIL -eq 0 ]] && green "  ok"

# All pairs, not just one pair. A package in two tiers is ambiguous: it would
# be installed twice, and its failure would be reported under whichever tier
# happened to reach it first.
blue "==> checking no package appears in two tiers"
overlap_found=0
for ((i = 0; i < ${#LISTS[@]}; i++)); do
    for ((j = i + 1; j < ${#LISTS[@]}; j++)); do
        overlap="$(comm -12 \
            <(read_pkg_list "${LISTS[i]}" | sort -u) \
            <(read_pkg_list "${LISTS[j]}" | sort -u))"
        if [[ -n "$overlap" ]]; then
            red "  in both $(basename "${LISTS[i]}") and $(basename "${LISTS[j]}"):"
            while IFS= read -r o; do red "    $o"; done <<<"$overlap"
            overlap_found=1
            FAIL=1
        fi
    done
done
[[ $overlap_found -eq 0 ]] && green "  ok ($((${#LISTS[@]} * (${#LISTS[@]} - 1) / 2)) pairs checked)"

if [[ $FAIL -eq 0 ]]; then
    green "✓ package lists valid"
else
    red "✗ package list validation failed — see above"
fi
exit "$FAIL"
