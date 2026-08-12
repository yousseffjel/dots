#!/usr/bin/env bash
# Exercises config/dwm/bin/dwm-colorpicker end to end against fake binaries.
#
# WHY THIS TEST EXISTS. config/dwm/bin/ held nine scripts and zero tests, and on
# 2026-08-12 that let a total failure ship green: dwm-colorpicker would have
# failed on EVERY invocation, because ImageMagick's `%[hex:p{0,0}]` returns
# eight hex digits (RRGGBBAA) for maim's actual RGBA output, and the script's
# strict six-digit validation rejected it. The full suite passed the whole time
# — nothing in tests/ ran the script. Only the reviewer caught it.
#
# THE SHIM IS THE POINT, NOT THE PLUMBING. The bug survived a hand-written test
# because that test's fake maim wrote an RGB PNG. It reproduced maim's
# *interface* (arguments, exit status, a file at the right path) but not its
# *output format*, so it tested the parser against a world that does not exist.
# Every fixture below is therefore generated in a specific, named PNG format,
# and RGBA — what maim really writes — is the first case.
#
# SAFETY. Three of the four binaries this script calls have real side effects,
# so all four are faked on PATH:
#   * xclip would overwrite the user's actual clipboard;
#   * notify-send would post a real desktop notification;
#   * xdotool and maim would read the live pointer and screen.
# ImageMagick is deliberately NOT faked: it is the thing under test. Faking it
# would leave this file asserting against its own fixture generator.
#
# CI: the `tests` job is ubuntu-latest with bash + coreutils only. When no
# ImageMagick is present this skips — LOUDLY, and saying so on stdout, because
# a silent skip is a green job that checked nothing (the same reasoning that
# put --strict in tests/lint.sh).
#
# WHAT THIS FILE DOES NOT CATCH, measured rather than assumed. Five mutations
# were applied to the picker and this test re-run against each. Four fail it:
# dropping `-alpha off -depth 8`, dropping either flag alone, and swapping
# `-alpha off` for the compositing `-alpha remove`. The fifth — loosening the
# `^[0-9A-Fa-f]{6}$` validation to `{6,8}` — SURVIVES, and that is a property of
# the code rather than a hole worth papering over: with the normalisation in
# place no input tried here (RGBA, 16-bit, palette, grayscale, CMYK) yields
# anything but six digits, so the strict regex is a second layer that never
# fires. It is kept deliberately, so that a future ImageMagick whose output
# shape changes fails loudly instead of truncating a colour onto the clipboard.
# Catching that mutant would mean asserting on the script's source text, which
# tests the implementation rather than the behaviour; it was judged not worth it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

PICKER="$DOTS_DIR/config/dwm/bin/dwm-colorpicker"
[[ -f "$PICKER" ]] || {
    red "missing: $PICKER"
    exit 1
}

# The script probes magick then convert; this test needs the same binary to
# build fixtures. Resolve it the same way rather than assuming either name.
if command -v magick >/dev/null 2>&1; then
    MAGICK="magick"
elif command -v convert >/dev/null 2>&1; then
    MAGICK="convert"
else
    yellow "SKIP: dwm-colorpicker.sh needs ImageMagick (magick or convert) and"
    yellow "      neither is on PATH. The picker cannot be tested without the"
    yellow "      real thing — faking it would test this file against itself."
    exit 0
fi
blue "==> using ImageMagick via '$MAGICK'"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"

rc=0
pass() { green "  ok: $1"; }
fail() {
    red "  FAIL: $1"
    rc=1
}

# --- fakes ------------------------------------------------------------------
# maim is rewritten per case; the other three are constant.
cat >"$TMP/bin/xdotool" <<'EOF'
#!/bin/sh
echo "X=137"
echo "Y=42"
echo "SCREEN=0"
echo "WINDOW=12345"
EOF
cat >"$TMP/bin/xclip" <<EOF
#!/bin/sh
cat > "$TMP/clipboard.txt"
EOF
cat >"$TMP/bin/notify-send" <<EOF
#!/bin/sh
printf '%s\n' "\$*" >> "$TMP/notify.log"
EOF
chmod 755 "$TMP/bin"/*

# Writes a fake maim that emits ONE pixel of $2 in the PNG subformat $1.
# The format is the whole point — see the header.
fake_maim() {
    cat >"$TMP/bin/maim" <<EOF
#!/bin/sh
for last; do :; done
$MAGICK -size 1x1 xc:$2 $1:"\$last"
EOF
    chmod 755 "$TMP/bin/maim"
}

run_picker() { PATH="$TMP/bin:$PATH" bash "$PICKER" "$@" 2>&1; }

# --- the regression this file exists for ------------------------------------

blue "==> hex normalisation across the PNG formats maim can emit"

# PNG32 is RGBA — what maim actually writes (png:IHDR.color_type 6) and the
# case that failed in production. PNG48 is 16-bit, which yields twelve digits
# raw. Both must come back as six.
while IFS='|' read -r fmt label colour; do
    fake_maim "$fmt" "$colour"
    : >"$TMP/clipboard.txt"
    out="$(run_picker || true)"
    got="$(cat "$TMP/clipboard.txt" 2>/dev/null || true)"
    if [[ "$out" == "$colour" && "$got" == "$colour" ]]; then
        pass "$label ($fmt) -> $colour, on stdout and clipboard"
    else
        fail "$label ($fmt): expected '$colour', stdout '$out', clipboard '$got'"
    fi
done <<'CASES'
PNG32|RGBA (what maim really writes)|#3fa9c2
PNG24|RGB|#c23f8a
PNG48|16 bits per channel|#3fa9c2
PNG8|palette|#3fa9c2
CASES

# -alpha off must DISCARD the channel, not composite against a background.
# Compositing would return a plausible but WRONG colour, which is worse than
# the original loud failure: `-alpha remove -background white` on this pixel
# gives #eec1c1 rather than #c83232.
fake_maim PNG32 "'rgba(200,50,50,0.3)'"
: >"$TMP/clipboard.txt"
out="$(run_picker || true)"
if [[ "$out" == "#c83232" ]]; then
    pass "semi-transparent pixel reports its true RGB (#c83232), not a composite"
else
    fail "semi-transparent pixel gave '$out' — expected #c83232; is -alpha off now -alpha remove?"
fi

# --- failure paths ----------------------------------------------------------

blue "==> every failure path names itself and exits non-zero"

expect_failure() {
    local desc="$1" needle="$2"
    shift 2
    local out
    if out="$(run_picker "$@")"; then
        fail "$desc: expected a non-zero exit, got success"
    elif [[ "$out" == *"$needle"* ]]; then
        pass "$desc"
    else
        fail "$desc: exited non-zero but said '$out'"
    fi
}

fake_maim PNG32 "#3fa9c2"
printf '#!/bin/sh\nexit 1\n' >"$TMP/bin/xdotool"
chmod 755 "$TMP/bin/xdotool"
expect_failure "dead X (xdotool returns nothing)" "is DISPLAY set"

printf '#!/bin/sh\necho "WINDOW=1"\n' >"$TMP/bin/xdotool"
chmod 755 "$TMP/bin/xdotool"
expect_failure "xdotool output without X=/Y=" "could not read the pointer position"

printf '#!/bin/sh\necho "X=1"\necho "Y=1"\n' >"$TMP/bin/xdotool"
chmod 755 "$TMP/bin/xdotool"
printf '#!/bin/sh\nexit 1\n' >"$TMP/bin/maim"
chmod 755 "$TMP/bin/maim"
expect_failure "maim cannot capture" "could not capture"

fake_maim PNG32 "#3fa9c2"
expect_failure "unknown option is rejected" "unknown option" --bogus

# The counterpart: --no-notify is a REAL option and must still succeed, or the
# check above would pass for the wrong reason (everything rejected).
: >"$TMP/notify.log"
if out="$(run_picker --no-notify)" && [[ "$out" == "#3fa9c2" ]]; then
    if [[ -s "$TMP/notify.log" ]]; then
        fail "--no-notify still sent a notification"
    else
        pass "--no-notify succeeds and sends nothing"
    fi
else
    fail "--no-notify should have succeeded, got '$out'"
fi

if ((rc != 0)); then
    red "✗ dwm-colorpicker is broken"
    exit 1
fi
green "✓ dwm-colorpicker: hex normalisation across 4 PNG formats + 4 failure paths"
