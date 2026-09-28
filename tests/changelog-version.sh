#!/usr/bin/env bash
# CHANGELOG.md and VERSION agree on what the current release is.
#
# VERSION is the source of truth — the install manifest records it and
# scripts/migrate.sh compares against it — so the newest *released* heading in
# CHANGELOG.md (the first `## [x.y.z]`, skipping `## [Unreleased]`) must name
# the same version. Bumping one without the other is the drift this catches:
# a release whose notes are filed under the wrong number, or notes for a
# version that was never cut.
#
# Also requires an `## [Unreleased]` section ABOVE the newest release, which
# is where CONTRIBUTING.md tells every change to be recorded; losing it on a
# release cut is the easy mistake.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

CHANGELOG="$DOTS_DIR/CHANGELOG.md"
VERSION_FILE="$DOTS_DIR/VERSION"
for f in "$CHANGELOG" "$VERSION_FILE"; do
    [[ -f "$f" ]] || {
        red "missing: $f"
        exit 1
    }
done

rc=0
version="$(tr -d '[:space:]' <"$VERSION_FILE")"

blue "==> newest released CHANGELOG heading vs VERSION ($version)"
# Line numbers of the first [Unreleased] and the first released heading.
unreleased_line="$(grep -n -m1 '^## \[Unreleased\]' "$CHANGELOG" | cut -d: -f1 || true)"
release="$(grep -n -m1 -E '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' "$CHANGELOG" || true)"
release_line="${release%%:*}"
release_ver="$(sed -E 's/^[0-9]+:## \[([^]]+)\].*/\1/' <<<"$release")"

if [[ -z "$release" ]]; then
    red "  no released '## [x.y.z]' heading in CHANGELOG.md"
    rc=1
elif [[ "$release_ver" != "$version" ]]; then
    red "  CHANGELOG's newest release is $release_ver, VERSION says $version"
    red "     cut the release in both places (CONTRIBUTING.md, 'Cut a release')"
    rc=1
else
    green "  ok: both say $version"
fi

blue "==> [Unreleased] section above the newest release"
if [[ -z "$unreleased_line" ]]; then
    red "  no '## [Unreleased]' heading — CONTRIBUTING.md sends every change there"
    rc=1
elif [[ -n "$release_line" && "$unreleased_line" -gt "$release_line" ]]; then
    red "  '## [Unreleased]' (line $unreleased_line) sits below the newest release (line $release_line)"
    rc=1
else
    green "  ok: [Unreleased] at line $unreleased_line"
fi

if ((rc != 0)); then
    red "✗ CHANGELOG.md and VERSION disagree"
    exit 1
fi
green "✓ CHANGELOG.md matches VERSION $version"
