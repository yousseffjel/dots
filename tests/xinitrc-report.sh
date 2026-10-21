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
if grep -q -- 'never restores the dots theme' <<<"$out" && grep -q -- 'never starts a D-Bus session' <<<"$out" \
    && ! grep -q -- 'never stops clipmenud' <<<"$out"; then
    green "  ok: a ~/.xinitrc with neither step is reported, for both"
else
    red "  an ~/.xinitrc with neither step was NOT reported for both"
    rc=1
fi
# A Fedora-era themed ~/.xinitrc with no session bus at all: the shipped
# theme half minus the dbus-run-session block, then `exec dwm`. Built from the
# shipped template, not by hand.
{ sed -e '/^# A session D-Bus bus/,/^fi$/d' -e '/^# Session end/,$d' "$SB/xinitrc.shipped" && echo 'exec dwm'; } >"$SB/no-bus-xinitrc"
out="$(report "$SB/no-bus-xinitrc")"
if ! grep -q 'dbus-run-session' "$SB/no-bus-xinitrc" && grep -q -- 'never starts a D-Bus session' <<<"$out" \
    && ! grep -q -- 'never restores the dots theme' <<<"$out"; then
    green "  ok: a themed ~/.xinitrc with no session bus gets only the session lines"
else
    red "  the no-bus ~/.xinitrc report is wrong: $out"
    rc=1
fi
# The last Fedora template: a full dots_session_end, but the session came from
# dots-session.target, not a bus. On Void that block can never work, so it
# gets the whole session block, never only the stops.
{ sed -e '/^# A session D-Bus bus/,/^fi$/d' "$SB/xinitrc.shipped" | sed '$d' && printf '%s\n' \
    'systemctl --user start dots-session.target && dots_session_target=1' 'dwm'; } >"$SB/fedora-xinitrc"
out="$(report "$SB/fedora-xinitrc")"
if grep -q -- 'never starts a D-Bus session' <<<"$out" && grep -qF -- 'dots-session.target lines above it' <<<"$out" \
    && ! grep -q -- 'Add inside dots_session_end' <<<"$out"; then
    green "  ok: the last Fedora ~/.xinitrc (dots-session.target) gets the whole session block"
else
    red "  the Fedora-era ~/.xinitrc report is wrong: $out"
    rc=1
fi
# A Void ~/.xinitrc with the bus but no session-end step.
{ sed '/^# Session end/,$d' "$SB/xinitrc.shipped" && echo 'exec dwm'; } >"$SB/pre-cleanup-xinitrc"
out="$(report "$SB/pre-cleanup-xinitrc")"
# shellcheck disable=SC2016 # the $(id -u) is the paste line's, matched literally
if grep -q -- 'never stops clipmenud at logout' <<<"$out" && grep -qF -- "            pkill -u \"\$(id -u)\" -f '/clipmenud\$'" <<<"$out" \
    && ! grep -q -- 'never starts a D-Bus session' <<<"$out" && ! grep -q -- 'never restores' <<<"$out"; then
    green "  ok: a bus without a session end gets the session-end lines"
else
    red "  the pre-cleanup ~/.xinitrc report is wrong: $out"
    rc=1
fi

# A session end that stops only clipmenud: the current template minus the
# dwmblocks and night-light pkills.
grep -v -e '-x dwmblocks' -e 'dwm-nightlight' "$SB/xinitrc.shipped" >"$SB/pre-blocks-xinitrc"
out="$(report "$SB/pre-blocks-xinitrc")"
# shellcheck disable=SC2016 # the $(id -u) is the paste line's, matched literally
if grep -q -- 'never stops dwmblocks at logout' <<<"$out" && grep -qF -- '            pkill -u "$(id -u)" -x dwmblocks' <<<"$out" \
    && ! grep -q -- 'never stops clipmenud' <<<"$out" && ! grep -q -- 'never starts a D-Bus session' <<<"$out" \
    && ! grep -qF -- 'clipmenud' <<<"$out"; then
    green "  ok: a session end without dwmblocks gets only the missing lines"
else
    red "  the pre-dwmblocks ~/.xinitrc report is wrong: $out"
    rc=1
fi
# A session end that stops everything except xss-lock.
grep -v -e '-x xss-lock' "$SB/xinitrc.shipped" >"$SB/pre-xsslock-xinitrc"
out="$(report "$SB/pre-xsslock-xinitrc")"
# shellcheck disable=SC2016 # the $(id -u) is the paste line's, matched literally
if grep -q -- 'never stops xss-lock at logout' <<<"$out" && grep -qF -- '            pkill -u "$(id -u)" -x xss-lock' <<<"$out" \
    && ! grep -q -- 'never stops dwmblocks' <<<"$out" && ! grep -q -- 'never stops clipmenud' <<<"$out" \
    && [[ "$(grep -c 'pkill -u' <<<"$out")" == 1 ]]; then
    green "  ok: a session end without the xss-lock stop gets that ONE line, not the block"
else
    red "  the pre-xss-lock ~/.xinitrc report is wrong: $out"
    rc=1
fi
# A session end that stops everything except PipeWire (2026-10-15).
grep -v -e '-x wireplumber' -e '-x pipewire' "$SB/xinitrc.shipped" >"$SB/pre-pipewire-xinitrc"
out="$(report "$SB/pre-pipewire-xinitrc")"
# shellcheck disable=SC2016 # the $(id -u) is the paste line's, matched literally
if grep -q -- 'never stops PipeWire at logout' <<<"$out" && grep -qF -- '            pkill -u "$(id -u)" -x pipewire' <<<"$out" \
    && [[ "$(grep -c 'pkill -u' <<<"$out")" == 2 ]]; then
    green "  ok: a session end without the PipeWire stops gets those TWO lines"
else
    red "  the pre-pipewire ~/.xinitrc report is wrong: $out"
    rc=1
fi
# A Void ~/.xinitrc from before 2026-10-21: everything, but clipmenud stopped
# by -x, which never matches (it runs as "bash").
sed "s|-f '/clipmenud\\\$'|-x clipmenud|" "$SB/xinitrc.shipped" >"$SB/pre-clipf-xinitrc"
out="$(report "$SB/pre-clipf-xinitrc")"
# shellcheck disable=SC2016 # the $(id -u) is the paste line's, matched literally
if grep -q -- '-x clipmenud' "$SB/pre-clipf-xinitrc" && grep -q -- 'its clipmenud stop never matches' <<<"$out" \
    && grep -qF -- "            pkill -u \"\$(id -u)\" -f '/clipmenud\$'" <<<"$out" \
    && [[ $(grep -c 'then log out and back in' <<<"$out") == 1 ]] && ! grep -q -- 'Add inside' <<<"$out"; then
    green "  ok: an -x clipmenud stop gets only its replacement line"
else
    red "  the pre-clipmenud-f ~/.xinitrc report is wrong: $out"
    rc=1
fi

# pkill -f must match the daemon's own self-detection pattern, or the stop
# silently matches nothing. Both sides read from the shipped files.
want="$(sed -n "s/^DAEMON_PATTERN='\(.*\)'$/\1/p" "$DOTS_DIR/config/dwm/bin/dwm-nightlight")"
got="$(sed -n "s/.*pkill -u .* -f '\([^']*nightlight[^']*\)'.*/\1/p" "$SB/xinitrc.shipped")"
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
done < <(report "$SB/old-xinitrc" | sed -n '/never starts a D-Bus session/,$p' | sed -n 's/^          //p')
if ((missing == 0)); then
    green "  ok: docs/THEMING.md carries every session paste line"
else
    rc=1
fi

if ((rc != 0)); then
    red "✗ xinitrc report"
    exit 1
fi
green "✓ xinitrc report"
