#!/usr/bin/env bash
# Every name in packages/*.lst and packages/live/*.lst (scope J) must exist
# in Void Linux's x86_64 repo index, and in the MAIN repo: the package stages
# install these before the repos step enables nonfree (and the live
# installer's target never has it), so a nonfree name here would fail on
# every install.
#
# It checks against tests/fixtures/void-x86_64-pkgs.tsv, a snapshot of the
# official index (name<TAB>repo). That keeps the test offline and
# deterministic, and it replaces the old rule-8 habit of checking each name by
# hand on packages.fedoraproject.org. The snapshot goes stale as Void renames
# packages, so a snapshot older than STALE_DAYS prints a yellow warning, and
# --refresh rebuilds it from the live index. Refreshing needs curl, zstd, tar
# and python3 (plistlib), and is never run by CI.
#
# The parser is the SHIPPED read_pkg_list(), extracted from
# scripts/install-pkg-tiers.sh rather than re-implemented, so this test reads
# a list exactly as the installer does. The lists are globbed, never named
# (CLAUDE.md rule 10).
#
# usage: tests/void-pkgnames.sh [--refresh]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SNAPSHOT="$SCRIPT_DIR/fixtures/void-x86_64-pkgs.tsv"
TIERS="$DOTS_DIR/scripts/install-pkg-tiers.sh"
REPO_URL="https://repo-default.voidlinux.org/current"
STALE_DAYS=90
MIN_ENTRIES=10000

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# refresh — rebuild the snapshot from the live index (main + nonfree).
refresh() {
    local tool repo suffix
    for tool in curl zstd tar python3; do
        command -v "$tool" >/dev/null 2>&1 || {
            red "--refresh needs $tool"
            exit 1
        }
    done
    # Global, not local: the EXIT trap runs after this function has returned.
    REFRESH_TMP="$(mktemp -d)"
    trap 'rm -rf "$REFRESH_TMP"' EXIT
    local tmp="$REFRESH_TMP"
    for repo in main nonfree; do
        suffix=""
        [[ $repo == main ]] || suffix="/$repo"
        mkdir "$tmp/$repo"
        blue "==> fetching $REPO_URL$suffix/x86_64-repodata"
        curl -fsSL "$REPO_URL$suffix/x86_64-repodata" | zstd -dc | tar -x -C "$tmp/$repo" index.plist
    done
    {
        printf '# Void Linux x86_64 package index snapshot: name<TAB>repo.\n'
        printf '# Source: %s{,/nonfree}/x86_64-repodata\n' "$REPO_URL"
        printf '# Captured: %s by tests/void-pkgnames.sh --refresh\n' "$(date -u +%F)"
        python3 -I -c '
import plistlib, sys
for repo, path in zip(("main", "nonfree"), sys.argv[1:]):
    with open(path, "rb") as f:
        for name in sorted(plistlib.load(f)):
            print(f"{name}\t{repo}")
' "$tmp/main/index.plist" "$tmp/nonfree/index.plist"
    } >"$SNAPSHOT.new"
    mv "$SNAPSHOT.new" "$SNAPSHOT"
    green "wrote $SNAPSHOT ($(grep -vc '^#' "$SNAPSHOT") packages)"
}

for arg in "$@"; do
    case "$arg" in
        --refresh)
            refresh
            exit 0
            ;;
        -h | --help)
            echo "usage: tests/void-pkgnames.sh [--refresh]"
            exit 0
            ;;
        *)
            red "unknown argument: $arg"
            exit 1
            ;;
    esac
done

FAIL=0

blue "==> snapshot"
if [[ ! -f $SNAPSHOT ]]; then
    red "  FAIL: no snapshot at $SNAPSHOT — run tests/void-pkgnames.sh --refresh"
    exit 1
fi
entries="$(grep -vc '^#' "$SNAPSHOT")"
if ((entries < MIN_ENTRIES)); then
    red "  FAIL: snapshot has $entries entries (< $MIN_ENTRIES) — truncated? re-run --refresh"
    exit 1
fi
captured="$(sed -n 's/^# Captured: \([0-9-]*\).*/\1/p' "$SNAPSHOT")"
if [[ -z $captured ]]; then
    red "  FAIL: snapshot has no '# Captured:' date line"
    FAIL=1
else
    age=$((($(date -u +%s) - $(date -u -d "$captured" +%s)) / 86400))
    if ((age > STALE_DAYS)); then
        yellow "  warn: snapshot is $age days old (captured $captured) — run --refresh"
    else
        green "  ok: $entries packages, captured $captured ($age days ago)"
    fi
fi

# The shipped parser, extracted rather than copied.
eval "$(sed -n '/^read_pkg_list()/,/^}$/p' "$TIERS")"
if ! declare -F read_pkg_list >/dev/null; then
    red "  FAIL: could not extract read_pkg_list() from $TIERS"
    exit 1
fi

declare -A REPO_OF=()
while IFS=$'\t' read -r name repo; do
    REPO_OF["$name"]="$repo"
done < <(grep -v '^#' "$SNAPSHOT")

blue "==> every packages/*.lst and packages/live/*.lst name is in Void's main repo"
lists=0
for list in "$DOTS_DIR"/packages/*.lst "$DOTS_DIR"/packages/live/*.lst; do
    [[ -e $list ]] || continue
    lists=$((lists + 1))
    while IFS= read -r pkg; do
        case "${REPO_OF[$pkg]:-}" in
            main) ;;
            nonfree)
                red "  FAIL: ${list#"$DOTS_DIR"/packages/}: $pkg is only in nonfree, which the package stages have not enabled yet"
                FAIL=1
                ;;
            *)
                red "  FAIL: ${list#"$DOTS_DIR"/packages/}: $pkg is not a Void package"
                FAIL=1
                ;;
        esac
    done < <(read_pkg_list "$list")
done
if ((lists == 0)); then
    red "  FAIL: no packages/*.lst found"
    exit 1
fi

if ((FAIL)); then
    red "✗ void package names"
    exit 1
fi
green "✓ void package names ($lists lists)"
