#!/usr/bin/env bash
# Runs three linters over scripts/*.sh, tests/*.sh and the repo-root *.sh:
# static analysis, a format check (shfmt -d, no rewrite), and markdownlint.
# This is the whole of the CI "lint" job (.github/workflows/ci.yml), which
# invokes this script rather than restating the checks.
#
# Careful with comments here: a line whose first word is the static-analysis
# tool's own name is read as a directive to it, and the file then fails to
# parse. That is why the three are not simply listed by name above.
#
# Missing tools are reported and skipped rather than treated as failures, so
# this is usable on a box that only has some of them installed.
#
# --strict turns every such skip into a failure. CI passes it: there the tools
# are installed by preceding steps, so a skip does not mean "not available
# locally", it means an install step silently failed and the job is about to
# go green having checked nothing.
#
# usage: tests/lint.sh [--strict]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

STRICT=0
for arg in "$@"; do
    case "$arg" in
        --strict) STRICT=1 ;;
        -h | --help)
            echo "usage: tests/lint.sh [--strict]"
            echo "  --strict   treat a missing linter as a failure, not a skip"
            exit 0
            ;;
        *)
            red "unknown argument: $arg"
            exit 1
            ;;
    esac
done

cd "$DOTS_DIR"

mapfile -t SH_FILES < <(find . -maxdepth 2 -type f -name '*.sh' -not -path './.git/*')

# An empty list means the find failed or the repo layout moved — never that
# there is nothing to check, since this script is itself one of the matches.
# Without this, both shell linters below would be handed zero paths and the
# run could read as a pass.
if [[ ${#SH_FILES[@]} -eq 0 ]]; then
    red "no *.sh files found under $DOTS_DIR — the find above failed"
    exit 1
fi

FAIL=0

# A linter that is not installed. Yellow and carry on by default; under
# --strict this is the failure the flag exists for, because the caller has
# already promised the tool is there.
missing_tool() {
    if [[ $STRICT -eq 1 ]]; then
        red "  $1 not found, and --strict was passed — nothing was checked"
        FAIL=1
    else
        yellow "  skipped ($1 not installed — see README.md for pre-commit setup)"
    fi
}

blue "==> shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck "${SH_FILES[@]}"; then
        green "  ok"
    else
        red "  shellcheck reported issues"
        FAIL=1
    fi
else
    missing_tool shellcheck
fi

blue "==> shfmt (format check)"
if command -v shfmt >/dev/null 2>&1; then
    if shfmt -i 4 -ci -bn -d "${SH_FILES[@]}"; then
        green "  ok"
    else
        red "  shfmt found formatting differences — run: shfmt -i 4 -ci -bn -w <file>"
        FAIL=1
    fi
else
    missing_tool shfmt
fi

blue "==> markdownlint"
MDLINT_ARGS=("**/*.md" --config .markdownlint.yaml --ignore-path .markdownlintignore)
if command -v markdownlint >/dev/null 2>&1; then
    if markdownlint "${MDLINT_ARGS[@]}"; then
        green "  ok"
    else
        red "  markdownlint reported issues"
        FAIL=1
    fi
elif command -v npx >/dev/null 2>&1; then
    if npx --yes markdownlint-cli "${MDLINT_ARGS[@]}"; then
        green "  ok"
    else
        red "  markdownlint reported issues"
        FAIL=1
    fi
else
    missing_tool "markdownlint / npx"
fi

if [[ $FAIL -eq 0 ]]; then
    green "✓ lint passed"
else
    red "✗ lint failed — see above"
fi
exit "$FAIL"
