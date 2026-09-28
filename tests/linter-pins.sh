#!/usr/bin/env bash
# Keeps every linter pinned twice in this repo pinned to the same version.
#
# Each of the three linters is declared in two places, and each copy decides
# which binary judges a file in a different place:
#
#   * .github/workflows/ci.yml's env block — what the `lint` job installs
#     (SHELLCHECK_VERSION, SHFMT_VERSION, MARKDOWNLINT_VERSION);
#   * .pre-commit-config.yaml — the hook `rev:` a commit runs on the dev host
#     (shellcheck-py, pre-commit-shfmt, markdownlint-cli).
#
# They must not drift. shellcheck renumbers findings between minor releases
# (0.10.0 split unreachable function bodies out of SC2317 into SC2329), so a
# `# shellcheck disable=` honoured by one version is ignored by the next —
# that turned the lint job red while `pre-commit run --all-files` stayed
# green. shfmt and markdownlint change their verdicts across versions too.
#
# WHY THIS IS ALSO THE DEPENDABOT GATE. .github/dependabot.yml bumps the
# pre-commit revs but cannot touch ci.yml's env vars, so a bot PR for one of
# these hooks goes red HERE until its ci.yml twin moves in the same branch.
# Until 2026-09-28 this was tests/shellcheck-pin.sh and checked shellcheck
# only, which would have let such a PR desync shfmt or markdownlint silently.
#
# HOW IT CHECKS. Every number is read out of the shipped files; none is
# restated here, so this test cannot be the thing that goes stale. An
# extraction that finds nothing is a FAILURE, not a pass — a renamed key or a
# restructured hook block must fail the build rather than silently compare
# two empty strings.
#
# usage: tests/linter-pins.sh

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

# The env value of <KEY>: in ci.yml, leading `v` dropped. Single awk passes
# that exit on the first match — deliberately not `… | head -1`, which under
# `set -o pipefail` can surface the 141 of a SIGPIPE'd producer, a shape this
# repo has been bitten by three times.
ci_pin() {
    awk -v k="$1:" '$1 == k { v = $2; gsub(/["\047]/, "", v); sub(/^v/, "", v); print v; exit }' "$CI_YML"
}

# The `rev:` of the pre-commit repo block whose URL contains <repo>, reduced
# to MAJOR.MINOR.PATCH: shellcheck-py's `v0.11.0.1` and pre-commit-shfmt's
# `v3.13.1-1` both carry a packaging revision that says nothing about which
# linter is inside. YAML quotes (`rev: 'v0.11.0.1'`) are stripped in both
# extractors, so a legitimately quoted value cannot false-fail.
pc_pin() {
    awk -v r="$1" 'index($0, "repo:") && index($0, r) { found = 1; next }
        found && $1 == "rev:" { v = $2; gsub(/["\047]/, "", v); print v; exit }' "$PRE_COMMIT"
}

rc=0

# <label> <ci.yml key> <pre-commit repo substring> <extra hint on mismatch>
check_pin() {
    local label="$1" key="$2" repo="$3" hint="$4" ci pc_rev pc
    ci="$(ci_pin "$key")"
    pc_rev="$(pc_pin "$repo")"
    pc="$(printf '%s' "${pc_rev#v}" | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
    if [[ -z "$ci" ]]; then
        red "  $label: no $key in $(basename "$CI_YML") — the lint job no longer pins it"
        rc=1
    elif [[ -z "$pc_rev" ]]; then
        red "  $label: no rev for a '$repo' repo in $(basename "$PRE_COMMIT") — hook renamed or dropped?"
        rc=1
    elif [[ "$ci" != "$pc" ]]; then
        red "  $label pins disagree: CI runs $ci, the commit hook runs $pc (rev $pc_rev)"
        red "     -> bump $key in ci.yml to match${hint:+; $hint}"
        rc=1
    else
        green "  ok: $label $ci (ci.yml $key, pre-commit rev $pc_rev)"
    fi
}

blue "==> ci.yml pins vs .pre-commit-config.yaml revs"
check_pin shellcheck SHELLCHECK_VERSION shellcheck-py "and recompute SHELLCHECK_SHA256"
check_pin shfmt SHFMT_VERSION pre-commit-shfmt ""
check_pin markdownlint MARKDOWNLINT_VERSION markdownlint-cli ""

if ((rc != 0)); then
    red "✗ linter pins have drifted between CI and the commit hooks"
    exit 1
fi
green "✓ linter pins: ci.yml and .pre-commit-config.yaml agree on all three"
