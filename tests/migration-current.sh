#!/usr/bin/env bash
# Exercises the REAL migration step into the current release: an install at
# the previous version runs the repo's own scripts/migrate.sh, which must find
# scripts/migrations/<prev>-to-<VERSION>.sh and record VERSION.
#
# Version-independent on purpose: it reads VERSION and finds the step by its
# target, so cutting a release never means editing this test (it replaced
# tests/migration-0.3.0.sh, which hard-coded 0.3.0 and would have failed on
# the next bump). What it catches is the mistake CONTRIBUTING.md warns
# about: a release without its migration script, after which migrate.sh
# stops, the manifest stays at the old version, and `dots doctor` warns on
# every upgraded install. tests/migrate.sh proves the walking logic on
# fixture migrations; this proves the shipped files line up.
#
# Sandboxed: a copy of scripts/ + VERSION, all four XDG variables under a temp
# dir, and `env -i` with a minimal PATH.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
R="$TMP/repo"
mkdir -p "$R" "$TMP/state/dots"
cp -r "$DOTS_DIR/scripts" "$R/"
cp "$DOTS_DIR/VERSION" "$R/"
MANIFEST="$TMP/state/dots/manifest"
VERSION="$(tr -d '[:space:]' <"$R/VERSION")"

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}
recorded() { sed -n 's/^META\tversion\t//p' "$MANIFEST"; }
migrate() {
    RC=0
    OUT="$(env -i PATH="/usr/bin:/bin" HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" \
        XDG_CONFIG_HOME="$TMP/config" XDG_DATA_HOME="$TMP/data" XDG_CACHE_HOME="$TMP/cache" \
        bash "$R/scripts/migrate.sh" 2>&1)" || RC=$?
}

blue "==> a migration ships for VERSION $VERSION"
steps=("$R"/scripts/migrations/*-to-"$VERSION".sh)
check "exactly one scripts/migrations/<prev>-to-$VERSION.sh" test "${#steps[@]}" -eq 1 -a -f "${steps[0]}"
step="${steps[0]##*/}"
prev="${step%-to-*}"

blue "==> an install at $prev upgrades to $VERSION"
printf 'META\tversion\t%s\nPACKAGE\tgit\n' "$prev" >"$MANIFEST"
migrate
check "migrate.sh exits 0" test "$RC" -eq 0
check "the manifest now records $VERSION" test "$(recorded)" = "$VERSION"
check "the step ran" grep -q "migrated $prev -> $VERSION" <<<"$OUT"
check "other rows are untouched" grep -qP '^PACKAGE\tgit$' "$MANIFEST"
migrate
check "a second run is a no-op" test "$RC:$(recorded)" = "0:$VERSION"

if [[ $FAILS -eq 0 ]]; then
    green "✓ migration into $VERSION: an install at $prev reaches it"
else
    red "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
