#!/usr/bin/env bash
# Exercises the REAL migration chain for the 0.3.0 release: a 0.2.0 install
# runs the repo's own scripts/migrate.sh, which must find
# scripts/migrations/0.2.0-to-0.3.0.sh and record 0.3.0 in the manifest.
#
# Why this exists: migrate.sh stops when no <from>-to-<to> script exists, and
# the manifest then stays at the old version, so `dots doctor` warns on every
# upgraded machine. tests/migrate.sh proves the walking logic on fixture
# migrations. This test proves the shipped files line up: VERSION, the
# migration's name, and the version migrate.sh records.
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

blue "==> the shipped files line up"
check "VERSION is 0.3.0" test "$(tr -d '[:space:]' <"$R/VERSION")" = 0.3.0
check "a 0.2.0-to-0.3.0 migration ships" test -f "$R/scripts/migrations/0.2.0-to-0.3.0.sh"

blue "==> a 0.2.0 install upgrades"
printf 'META\tversion\t0.2.0\nPACKAGE\tgit\n' >"$MANIFEST"
migrate
check "migrate.sh exits 0" test "$RC" -eq 0
check "the manifest now records 0.3.0" test "$(recorded)" = 0.3.0
check "the no-op step said so" grep -q "no migration step needed" <<<"$OUT"
check "other rows are untouched" grep -qP '^PACKAGE\tgit$' "$MANIFEST"
migrate
check "a second run is a no-op" test "$RC:$(recorded)" = "0:0.3.0"

if [[ $FAILS -eq 0 ]]; then
    green "✓ migration 0.3.0: a 0.2.0 install reaches 0.3.0"
else
    red "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
