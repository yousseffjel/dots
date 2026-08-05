#!/usr/bin/env bash
# Brings an existing install's manifest-recorded version up to the repo's
# current VERSION by running scripts/migrations/<from>-to-<to>.sh scripts
# in a chain, one hop at a time, updating the manifest's version after
# each successfully-applied hop.
#
# Idempotent and safe to re-run: a fresh install (no manifest yet) or an
# install already at VERSION is a no-op. Called automatically by
# install-fedora.sh; also runnable standalone.
#
# usage: migrate.sh [--dry-run]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MIGRATIONS_DIR="$SCRIPT_DIR/migrations"
source "$SCRIPT_DIR/global_fn.sh"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        -h | --help)
            echo "usage: migrate.sh [--dry-run]"
            exit 0
            ;;
        *)
            red "unknown argument: $arg"
            exit 1
            ;;
    esac
done

repo_version="$(tr -d '[:space:]' <"$DOTS_DIR/VERSION")"
installed_version="$(manifest_get_meta version)"

if [[ -z "$installed_version" ]]; then
    blue "no installed version recorded yet — nothing to migrate (fresh install)"
    exit 0
fi

current="$installed_version"
applied_any=0

while [[ "$current" != "$repo_version" ]]; do
    mapfile -t matches < <(
        for f in "$MIGRATIONS_DIR/$current-to-"*.sh; do
            [[ -f "$f" ]] && printf '%s\n' "$f"
        done
    )
    if [[ ${#matches[@]} -gt 1 ]]; then
        red "ambiguous migration path: multiple files start with '$current-to-' (${matches[*]}) — expected exactly one"
        exit 1
    fi
    migration_file="${matches[0]:-}"

    if [[ -z "$migration_file" ]]; then
        yellow "no migration path from $current to $repo_version — stopping (manifest stays at $current)"
        break
    fi

    to_version="$(basename "$migration_file" .sh)"
    to_version="${to_version#*-to-}"

    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would run migration $current -> $to_version ($migration_file)"
        current="$to_version"
        continue
    fi

    blue "==> running migration $current -> $to_version"
    if bash "$migration_file"; then
        manifest_set_meta version "$to_version"
        green "  migrated $current -> $to_version"
        current="$to_version"
        applied_any=1
    else
        red "migration $current -> $to_version failed — manifest stays at $current"
        exit 1
    fi
done

if [[ $DRY_RUN -eq 1 ]]; then
    [[ "$current" != "$installed_version" ]] && blue "  (dry-run) would end at version $current"
elif [[ "$current" != "$repo_version" ]]; then
    yellow "stopped at $current — not yet at $repo_version (no migration path found; see the warning above)"
elif [[ $applied_any -eq 1 ]]; then
    green "✓ migrations complete — now at $current"
else
    green "✓ already at $repo_version — nothing to migrate"
fi
