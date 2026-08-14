#!/usr/bin/env bash
# Keeps the two shellcheck pins in this repo in agreement.
#
# The version is declared twice, and each copy decides which linter judges a
# shell script in a different place:
#
#   * .github/workflows/ci.yml — SHELLCHECK_VERSION, the binary the `lint`
#     job downloads and puts ahead of the runner image's own copy;
#   * .pre-commit-config.yaml — the shellcheck-py rev, the binary a commit
#     hook runs on the dev host.
#
# They must not drift, because shellcheck renumbers findings between minor
# releases: 0.10.0 split unreachable function bodies out of SC2317 into
# SC2329, so a `# shellcheck disable=` directive can be honoured by one
# version and ignored by the next. That is not hypothetical — it is what
# turned the lint job red while `pre-commit run --all-files` stayed green,
# on a runner image whose bundled shellcheck was older than this pin.
#
# HOW IT CHECKS. Both numbers are read out of the shipped files; neither is
# restated here, so this test cannot be the thing that goes stale. An
# extraction that finds nothing is a FAILURE, not a pass — a renamed key or
# a restructured hook block must fail the build rather than silently check
# two empty strings against each other.
#
# usage: tests/shellcheck-pin.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

CI_YML="$DOTS_DIR/.github/workflows/ci.yml"
PRE_COMMIT="$DOTS_DIR/.pre-commit-config.yaml"

for f in "$CI_YML" "$PRE_COMMIT"; do
    [[ -f "$f" ]] || {
        red "missing: $f"
        exit 1
    }
done

blue "==> reading both shellcheck pins"

# ci.yml: `SHELLCHECK_VERSION: v0.11.0` -> 0.11.0. Both extractions below are
# single awk passes that exit on the first match — deliberately not
# `… | head -1`, which under `set -o pipefail` can surface the 141 of a
# SIGPIPE'd producer, a shape this repo has been bitten by three times.
CI_VERSION="$(awk '$1 == "SHELLCHECK_VERSION:" { v = $2; sub(/^v/, "", v); print v; exit }' "$CI_YML")"

# .pre-commit-config.yaml: the `rev:` belonging to the shellcheck-py repo
# block, `v0.11.0.1` -> 0.11.0. The fourth component is shellcheck-py's own
# packaging revision and says nothing about which shellcheck is inside.
PC_REV="$(awk '/shellcheck-py/ { found = 1 } found && $1 == "rev:" { print $2; exit }' "$PRE_COMMIT")"
PC_VERSION="$(printf '%s' "${PC_REV#v}" | cut -d. -f1-3)"

rc=0
if [[ -z "$CI_VERSION" ]]; then
    red "  no SHELLCHECK_VERSION found in $(basename "$CI_YML")"
    red "     (renamed or removed — the lint job no longer pins shellcheck)"
    rc=1
fi
if [[ -z "$PC_REV" ]]; then
    red "  no shellcheck-py rev found in $(basename "$PRE_COMMIT")"
    red "     (the hook was renamed or dropped — update this test)"
    rc=1
fi
((rc == 0)) || exit 1

green "  ci.yml: $CI_VERSION   pre-commit: $PC_VERSION (rev $PC_REV)"

blue "==> comparing"
if [[ "$CI_VERSION" != "$PC_VERSION" ]]; then
    red "  shellcheck pins disagree: CI runs $CI_VERSION, the commit hook runs $PC_VERSION"
    red "     -> a disable directive that satisfies one can go red in the other"
    red "     -> bump both, and recompute SHELLCHECK_SHA256 in ci.yml"
    exit 1
fi

green "✓ shellcheck pin: ci.yml and .pre-commit-config.yaml agree on $CI_VERSION"
