#!/usr/bin/env bash
# The report half of the ~/.xinitrc contract: what the installer prints for a
# ~/.xinitrc the user already has. Rule 6 makes that file user-owned once it
# exists, so it is never rewritten — each later fix reaches existing installs
# only through these paste lines. Split out of tests/xinitrc-theme.sh at the
# 250-line cap; that file still RUNS the generated ~/.xinitrc.
#
# Each case is an .xinitrc as some earlier installer generated it, rebuilt from
# the current template minus what was added since, so everything else in the
# file is exactly what ships. Each must get only the block it lacks, and every
# printed session paste line must also be in docs/THEMING.md. The night-light
# stop is checked against dwm-nightlight's own DAEMON_PATTERN, because a pkill
# -f pattern that drifts matches nothing and says nothing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# install-session.sh only defines functions, so sourcing it runs nothing.
# shellcheck source=../scripts/install-session.sh
source "$DOTS_DIR/scripts/install-session.sh"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
session_xinitrc_template >"$SB/xinitrc.shipped"

rc=0
blue "==> report on an existing ~/.xinitrc"
report() {
    (
        # Called indirectly from session_xinitrc_report. Both codes are
        # disabled for the 0.10.0 rename - see tests/autostart-daemons.sh.
        # shellcheck disable=SC2317,SC2329
        green() { printf '%s\n' "$*"; }
        # shellcheck disable=SC2317,SC2329
        yellow() { printf '%s\n' "$*"; }
        session_xinitrc_report "$1"
    )
}
if grep -q -- '^ok ' <<<"$(report "$SB/xinitrc.shipped")"; then
    green "  ok: the generated file is recognised"
else
    red "  the generated ~/.xinitrc is reported as not restoring the theme"
    rc=1
fi
printf '#!/bin/sh\nexec dwm\n' >"$SB/old-xinitrc"
out="$(report "$SB/old-xinitrc")"
if grep -q -- 'never restores the dots theme' <<<"$out" && grep -q -- 'never starts dots-session.target' <<<"$out" \
    && ! grep -q -- 'never stops clipmenud' <<<"$out"; then
    green "  ok: a pre-2026-10-05 ~/.xinitrc is reported, for both"
else
    red "  an ~/.xinitrc with neither step was NOT reported for both"
    rc=1
fi
# What the installer generated between 2026-10-05 and 2026-10-06: the theme
# block, no session target. Built from the shipped template, not by hand.
{ sed '/^# Session end/,$d' "$SB/xinitrc.shipped" && echo 'exec dwm'; } >"$SB/pre-portal-xinitrc"
out="$(report "$SB/pre-portal-xinitrc")"
if ! grep -q 'dots-session.target' "$SB/pre-portal-xinitrc" && grep -q -- 'never starts dots-session.target' <<<"$out" \
    && ! grep -q -- 'never restores the dots theme' <<<"$out"; then
    green "  ok: a themed but pre-portal ~/.xinitrc gets only the session-target lines"
else
    red "  the pre-portal ~/.xinitrc report is wrong: $out"
    rc=1
fi

# 2026-10-06 to 2026-10-07: a session target, no session-end step. Its exact
# block is gone from the template, so only its marker is reproduced.
{ sed '$d' "$SB/pre-portal-xinitrc" && printf '%s\n' \
    'systemctl --user start dots-session.target && { dwm; exit 0; }' 'exec dwm'; } >"$SB/pre-cleanup-xinitrc"
out="$(report "$SB/pre-cleanup-xinitrc")"
# shellcheck disable=SC2016 # the $(id -u) is the paste line's, matched literally
if grep -q -- 'never stops clipmenud at logout' <<<"$out" && grep -qF -- '            pkill -u "$(id -u)" -x clipmenud' <<<"$out" \
    && ! grep -q -- 'never starts dots-session.target' <<<"$out" && ! grep -q -- 'never restores' <<<"$out"; then
    green "  ok: a pre-cleanup ~/.xinitrc gets only the session-end lines"
else
    red "  the pre-cleanup ~/.xinitrc report is wrong: $out"
    rc=1
fi

# Earlier on 2026-10-07: a session-end step that stops only clipmenud. The
# current template minus the two later pkills.
grep -v -e '-x dwmblocks' -e 'dwm-nightlight' "$SB/xinitrc.shipped" >"$SB/pre-blocks-xinitrc"
out="$(report "$SB/pre-blocks-xinitrc")"
# shellcheck disable=SC2016 # the $(id -u) is the paste line's, matched literally
if grep -q -- 'never stops dwmblocks at logout' <<<"$out" && grep -qF -- '            pkill -u "$(id -u)" -x dwmblocks' <<<"$out" \
    && ! grep -q -- 'never stops clipmenud' <<<"$out" && ! grep -q -- 'never starts dots-session.target' <<<"$out"; then
    green "  ok: a session end without dwmblocks gets the updated session-end lines"
else
    red "  the pre-dwmblocks ~/.xinitrc report is wrong: $out"
    rc=1
fi
# pkill -f must match the daemon's own self-detection pattern, or the stop
# silently matches nothing. Both sides read from the shipped files.
want="$(sed -n "s/^DAEMON_PATTERN='\(.*\)'$/\1/p" "$DOTS_DIR/config/dwm/bin/dwm-nightlight")"
got="$(sed -n "s/.*pkill -u .* -f '\([^']*\)'.*/\1/p" "$SB/xinitrc.shipped")"
if [[ -n "$want" && "$got" == "$want" ]]; then
    green "  ok: the night-light stop uses dwm-nightlight's own DAEMON_PATTERN"
else
    red "  night-light pattern drift: template '$got', dwm-nightlight '$want'"
    rc=1
fi

# The paste lines live twice — printed by the installer, documented for anyone
# who never re-runs it. Every printed line must appear in the doc's block.
missing=0
while IFS= read -r line; do
    grep -qxF "$line" "$DOTS_DIR/docs/THEMING.md" || {
        red "  docs/THEMING.md lacks the paste line: $line"
        missing=1
    }
done < <(report "$SB/old-xinitrc" | sed -n '/never starts dots-session.target/,$p' | sed -n 's/^          //p')
if ((missing == 0)); then
    green "  ok: docs/THEMING.md carries every session-target paste line"
else
    rc=1
fi

if ((rc != 0)); then
    red "✗ xinitrc report"
    exit 1
fi
green "✓ xinitrc report"
