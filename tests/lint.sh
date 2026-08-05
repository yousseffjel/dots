#!/usr/bin/env bash
# Runs the same checks as the CI "lint" job (.github/workflows/ci.yml),
# locally: shellcheck, shfmt -d (format check, no rewrite), markdownlint.
# Missing tools are reported and skipped rather than treated as failures,
# so this is usable on a box that only has some of them installed — CI is
# still the authoritative gate.
#
# usage: tests/lint.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[34m%s\033[0m\n' "$*"; }

for arg in "$@"; do
    case "$arg" in
        -h|--help) echo "usage: tests/lint.sh"; exit 0 ;;
        *) red "unknown argument: $arg"; exit 1 ;;
    esac
done

cd "$DOTS_DIR"

mapfile -t SH_FILES < <(find . -maxdepth 2 -type f -name '*.sh' -not -path './.git/*')

FAIL=0

blue "==> shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck "${SH_FILES[@]}"; then
        green "  ok"
    else
        red "  shellcheck reported issues"
        FAIL=1
    fi
else
    yellow "  skipped (shellcheck not installed — see README.md for pre-commit setup)"
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
    yellow "  skipped (shfmt not installed — see README.md for pre-commit setup)"
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
    yellow "  skipped (markdownlint / npx not installed)"
fi

if [[ $FAIL -eq 0 ]]; then
    green "✓ lint passed"
else
    red "✗ lint failed — see above"
fi
exit "$FAIL"
