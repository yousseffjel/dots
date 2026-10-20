#!/usr/bin/env bash
# The xresources template survives xrdb's cpp pass.
#
# xrdb runs the merged file through the C preprocessor, `!` comments
# included: a `/*` opens a C block comment and breaks the merge, and an
# apostrophe opens a character literal and warns (docs/THEMING.md). The rule
# was only tested on the xcursor output (tests/cursor-x11.sh), so "Void's" in
# a comment of xresources.dcol made every theme apply and wallpaper change
# print `missing terminating ' character` (Void VM, 2026-10-20).
#
# What is asserted, on the template body (line 1 is the target|command header,
# which is never rendered):
#   * no apostrophe and no `/*`;
#   * when cpp is installed, preprocessing it prints nothing on stderr. The
#     grep holds where cpp is absent; cpp catches what the grep cannot name.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

TEMPLATE="$DOTS_DIR/config/theme/templates/always/xresources.dcol"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
tail -n +2 "$TEMPLATE" >"$TMP/body"

rc=0
blue "==> xresources.dcol against xrdb's cpp pass"
if grep -nF "'" "$TMP/body" || grep -nF '/*' "$TMP/body"; then
    red "  FAIL: an apostrophe or slash-star in the template body (line numbers above are body lines, +1 for the file)"
    rc=1
else
    green "  ok: no apostrophe or slash-star"
fi
if command -v cpp >/dev/null 2>&1; then
    cpp -P "$TMP/body" >/dev/null 2>"$TMP/err" || true
    if [[ -s $TMP/err ]]; then
        red "  FAIL: cpp complains about the template:"
        cat "$TMP/err"
        rc=1
    else
        green "  ok: cpp preprocesses it silently"
    fi
else
    yellow "  skip: no cpp here — the grep above is the whole check"
fi

if ((rc != 0)); then
    red "✗ xresources cpp safety"
    exit 1
fi
green "✓ xresources cpp safety: the template merges without a cpp warning"
