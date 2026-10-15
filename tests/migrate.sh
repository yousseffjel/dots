#!/usr/bin/env bash
# Exercises scripts/migrate.sh — the version chain install-void.sh runs
# before every install stage — against a sandbox manifest. Untested until
# 2026-10-12, the release that first ships a real migration.
#
# What is asserted:
#   * no manifest (a fresh install): a no-op that creates nothing;
#   * one hop: the migration runs, then the manifest records the new version;
#   * a chain of hops runs in order and ends at VERSION;
#   * --dry-run names the hop and changes nothing;
#   * a failing hop exits 1 and leaves the manifest at the version it was;
#   * two migrations from one version is an error, not a guess;
#   * no path onward: stops where it is, exit 0, says so.
#
# HOW. A sandbox COPY of scripts/ with its own VERSION and a migrations dir of
# fixtures that only append to a log. HOME and the XDG base dirs point into
# the sandbox, so the real manifest is never read or written.
# shellcheck disable=SC2016 # the bash -c bodies take $1/$2 as their own arguments
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

rc=0
check() {
    local name="$1"
    shift
    if "$@"; then
        green "  ok: $name"
    else
        red "  FAIL: $name"
        rc=1
    fi
}

REPO="$TMP/repo"
H="$TMP/home"
MANIFEST="$H/.local/state/dots/manifest"
LOG="$TMP/ran.log"

# setup <repo VERSION> <installed version or "">
setup() {
    rm -rf "$REPO" "$H" "$LOG"
    mkdir -p "$REPO" "$H"
    cp -r "$DOTS_DIR/scripts" "$REPO/"
    rm -f "$REPO/scripts/migrations/"*.sh
    printf '%s\n' "$1" >"$REPO/VERSION"
    if [[ -n "$2" ]]; then
        mkdir -p "${MANIFEST%/*}"
        printf 'META\tversion\t%s\n' "$2" >"$MANIFEST"
    fi
}
# hop <from> <to> [exit code] — a fixture migration that logs its own name.
hop() {
    printf '#!/usr/bin/env bash\necho "%s-to-%s" >>"%s"\nexit %s\n' \
        "$1" "$2" "$LOG" "${3:-0}" >"$REPO/scripts/migrations/$1-to-$2.sh"
}
migrate() {
    RC=0
    OUT="$(env -i PATH="/usr/bin:/bin" HOME="$H" XDG_STATE_HOME="$H/.local/state" \
        XDG_CONFIG_HOME="$H/.config" XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" \
        bash "$REPO/scripts/migrate.sh" "$@" 2>&1)" || RC=$?
}
recorded() { awk -F'\t' '$1=="META" && $2=="version" {print $3}' "$MANIFEST" 2>/dev/null; }
ran() { [[ "$(tr '\n' ' ' <"$LOG" 2>/dev/null)" == "$1" ]]; }

blue "==> fresh install"
setup 0.2.0 ""
hop 0.1.0 0.2.0
migrate
check "no manifest: exit 0" test "$RC" -eq 0
check "...runs nothing" test ! -e "$LOG"
check "...creates no manifest" test ! -e "$MANIFEST"

blue "==> one hop"
setup 0.2.0 0.1.0
hop 0.1.0 0.2.0
migrate
check "exit 0" test "$RC" -eq 0
check "the migration ran once" ran "0.1.0-to-0.2.0 "
check "the manifest now records 0.2.0" test "$(recorded)" = 0.2.0
migrate
check "a second run is a no-op (already at VERSION)" ran "0.1.0-to-0.2.0 "

blue "==> a chain"
setup 0.3.0 0.1.0
hop 0.1.0 0.2.0
hop 0.2.0 0.3.0
migrate
check "both hops, in order" ran "0.1.0-to-0.2.0 0.2.0-to-0.3.0 "
check "ends at VERSION" test "$(recorded)" = 0.3.0

blue "==> --dry-run"
setup 0.2.0 0.1.0
hop 0.1.0 0.2.0
migrate --dry-run
check "names the hop" grep -q 'would run migration 0.1.0 -> 0.2.0' <<<"$OUT"
check "runs nothing" test ! -e "$LOG"
check "the manifest still says 0.1.0" test "$(recorded)" = 0.1.0

blue "==> a failing hop"
setup 0.3.0 0.1.0
hop 0.1.0 0.2.0
hop 0.2.0 0.3.0 1
migrate
check "exit 1" test "$RC" -eq 1
check "the manifest stops at the last good hop (0.2.0)" test "$(recorded)" = 0.2.0

blue "==> ambiguity and dead ends"
setup 0.2.0 0.1.0
hop 0.1.0 0.2.0
hop 0.1.0 0.1.5
migrate
check "two migrations from 0.1.0: exit 1" test "$RC" -eq 1
check "...and neither ran" test ! -e "$LOG"
setup 0.2.0 0.0.9
hop 0.1.0 0.2.0
migrate
check "no path from 0.0.9: exit 0" test "$RC" -eq 0
check "...stays at 0.0.9 and says so" bash -c '[[ "$1" == 0.0.9 ]] && grep -q "no migration path from 0.0.9" <<<"$2"' _ "$(recorded)" "$OUT"

if ((rc != 0)); then
    red "✗ migrate.sh"
    exit 1
fi
green "✓ migrate.sh: chain, dry-run, failure, ambiguity"
