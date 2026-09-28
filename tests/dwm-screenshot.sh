#!/usr/bin/env bash
# Exercises config/dwm/bin/dwm-screenshot against faked maim/slop/xclip/dmenu.
#
# What is asserted:
#   * each mode reaches maim with the right selector (--window <id>,
#     --geometry <slop's answer>) and always --hidecursor;
#   * region mode themes slop from dwm.selbordercolor, converting #RRGGBB to
#     the float RGBA slop wants (hex2rgba's arithmetic is checked, not just
#     that a --color flag appeared), and falls back to no --color unthemed;
#   * cancelling slop, or pressing Escape at either dmenu prompt, exits 0
#     having captured nothing; garbage typed into dmenu is rejected BEFORE a
#     capture is taken;
#   * --window with no focused window (_NET_ACTIVE_WINDOW 0x0) fails;
#   * file/both land in DOTS_SCREENSHOT_DIR under the documented name; a
#     missing xclip does not lose a file that was already saved;
#   * an empty capture is an error, and a missing maim fails up front.
#
# SAFETY: every tool is a fake on a sealed PATH — a real maim would capture
# the tester's screen, a real xclip would replace their clipboard, and a real
# dmenu would block forever. The fake maim writes a small non-empty file to
# its last argument, which is all the script inspects (`-s` on the temp file).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SUT="$DOTS_DIR/config/dwm/bin/dwm-screenshot"
[[ -f "$SUT" ]] || {
    red "missing: $SUT"
    exit 1
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
LOG="$TMP/calls.log"
SHOTS="$TMP/shots"

rc=0
pass() { green "  ok: $1"; }
fail() {
    red "  FAIL: $1"
    rc=1
}

# mkbin <name> <tool to leave out>...
mkbin() {
    local dir="$TMP/$1" t
    shift
    seal_path "$dir" bash awk mktemp rm mv mkdir date cat
    for t in maim slop xclip xprop dmenu notify-send xrdb; do
        [[ " $* " == *" $t "* ]] && continue
        case "$t" in
            # Writes "PNG" into its last argument, or nothing when FAKE_EMPTY.
            maim) fake "$dir" maim "echo \"maim \${*:1:\$#-1}\" >>'$LOG'; [[ -n \"\${FAKE_EMPTY:-}\" ]] || echo PNG >\"\${*: -1}\"" ;;
            # Prints FAKE_GEOM (empty = the user pressed Escape).
            slop) fake "$dir" slop "echo \"slop \$*\" >>'$LOG'; printf '%s' \"\${FAKE_GEOM-}\"; [[ -n \"\${FAKE_GEOM-}\" ]]" ;;
            xprop) fake "$dir" xprop "echo \"_NET_ACTIVE_WINDOW(WINDOW): window id # \${FAKE_WIN:-0x0}\"" ;;
            xrdb) fake "$dir" xrdb "[[ -n \"\${FAKE_SEL:-}\" ]] && printf 'dwm.normbordercolor:\t#111111\ndwm.selbordercolor:\t%s\n' \"\$FAKE_SEL\"; exit 0" ;;
            # Answers successive prompts from FAKE_MENU ("a|b"); "ESC" = Escape.
            dmenu) fake "$dir" dmenu "n=\$(cat '$TMP/menu.n' 2>/dev/null || echo 0); echo \$((n + 1)) >'$TMP/menu.n'
IFS='|' read -ra a <<<\"\${FAKE_MENU:-}\"; ans=\"\${a[\$n]:-ESC}\"; [[ \"\$ans\" == ESC ]] && exit 1; echo \"\$ans\"" ;;
            *) fake "$dir" "$t" "echo \"$t \$*\" >>'$LOG'" ;;
        esac
    done
}
mkbin all
mkbin no-xclip xclip
mkbin no-maim maim

# run <bin> [VAR=val...] -- <args...>; sets RC and ERR; fresh log/menu/shots.
run() {
    local bin="$1" envs=()
    shift
    while [[ $# -gt 0 && "$1" != -- ]]; do
        envs+=("$1")
        shift
    done
    shift
    : >"$LOG"
    rm -rf "$SHOTS" "$TMP/menu.n"
    RC=0
    env -i PATH="$TMP/$bin" HOME="$TMP/home" TMPDIR="$TMP" DOTS_SCREENSHOT_DIR="$SHOTS" "${envs[@]}" \
        bash "$SUT" "$@" >/dev/null 2>"$TMP/err" || RC=$?
    ERR="$(cat "$TMP/err")"
}
has() { grep -qF -- "$1" "$LOG"; }
shots() { find "$SHOTS" -type f 2>/dev/null | wc -l; }

blue "==> modes reach maim correctly"
run all -- --full --file
if [[ $RC -eq 0 ]] && has "maim --hidecursor" && [[ "$(shots)" -eq 1 ]]; then
    pass "--full --file: captured with --hidecursor, one file saved"
else
    fail "--full --file: rc=$RC shots=$(shots) log=$(cat "$LOG")"
fi
name="$(basename "$(find "$SHOTS" -type f 2>/dev/null | head -1)")"
if [[ "$name" =~ ^dots-screenshot-[0-9]{8}-[0-9]{6}\.png$ ]]; then pass "file name follows NAME_FMT ($name)"; else fail "file name '$name'"; fi
run all FAKE_WIN=0x2a00007 -- --window --clipboard
if has "maim --hidecursor --window 0x2a00007" && has "xclip -selection clipboard -t image/png -i"; then
    pass "--window captures the active window id and copies it as image/png"
else
    fail "--window: $(cat "$LOG")"
fi
run all -- --window --clipboard
if [[ $RC -ne 0 && "$ERR" == *"no active window"* ]] && ! has maim; then
    pass "--window with _NET_ACTIVE_WINDOW 0x0 fails before capturing"
else
    fail "--window 0x0: rc=$RC"
fi

blue "==> region: slop theming and cancel"
run all FAKE_GEOM=800x600+10+20 FAKE_SEL='#ff8000' -- --region --clipboard
if has "slop --bordersize 2 --color 1.000,0.502,0.000,1" && has "maim --hidecursor --geometry 800x600+10+20"; then
    pass "#ff8000 -> --color 1.000,0.502,0.000,1, and slop's geometry reaches maim"
else
    fail "region themed: $(cat "$LOG")"
fi
run all FAKE_GEOM=800x600+10+20 -- --region --clipboard
if has "slop --bordersize 2" && ! grep -q -- '--color' "$LOG"; then pass "unthemed: no --color, slop's default"; else fail "unthemed: $(cat "$LOG")"; fi
run all FAKE_GEOM= -- --region --file
if [[ $RC -eq 0 ]] && ! has maim && [[ "$(shots)" -eq 0 ]]; then
    pass "Escape in slop: exit 0, nothing captured or saved"
else
    fail "slop cancel: rc=$RC shots=$(shots)"
fi

blue "==> dmenu prompts"
run all 'FAKE_MENU=full|both' --
if [[ $RC -eq 0 && "$(shots)" -eq 1 ]] && has "xclip"; then pass "both prompts answered: saved and copied"; else fail "prompts: rc=$RC shots=$(shots)"; fi
run all 'FAKE_MENU=ESC' --
if [[ $RC -eq 0 ]] && ! has maim; then pass "Escape at the first prompt: exit 0, no capture"; else fail "esc 1: rc=$RC"; fi
run all 'FAKE_MENU=full|ESC' --
if [[ $RC -eq 0 ]] && ! has maim; then pass "Escape at the second prompt: exit 0, no capture"; else fail "esc 2: rc=$RC"; fi
run all 'FAKE_MENU=fulll|file' --
# "Stopped at validation" is asserted through the ABSENCE of the next stage's
# error: with the validation's exit removed, a bogus mode falls through to an
# empty capture and dies on "empty file" instead. "maim was not called" alone
# passed that mutant, since a bogus mode never reaches maim anyway. (A check
# for a leftover temp file would prove nothing: the script's EXIT trap deletes
# it on every path.)
if [[ $RC -ne 0 && "$ERR" == *"unknown mode"* && "$ERR" != *"empty file"* ]] && ! has maim; then
    pass "a mistyped mode is rejected BEFORE anything is captured"
else
    fail "typo mode: rc=$RC err=$ERR log=$(cat "$LOG")"
fi
run all FAKE_GEOM=800x600+10+20 'FAKE_MENU=region|fille' --
if [[ $RC -ne 0 && "$ERR" == *"unknown destination"* ]] && ! has slop && ! has maim; then
    pass "a mistyped destination is rejected BEFORE the region drag (no wasted selection)"
else
    fail "typo destination: rc=$RC log=$(cat "$LOG")"
fi

blue "==> failure paths"
run no-xclip -- --full --both
if [[ $RC -eq 0 && "$(shots)" -eq 1 ]] && has "notify-send" && ! grep -q "and copied" "$LOG"; then
    pass "no xclip with --both: file still saved, message says saved (not copied)"
else
    fail "no xclip: rc=$RC shots=$(shots) log=$(cat "$LOG")"
fi
run all FAKE_EMPTY=1 -- --full --file
if [[ $RC -ne 0 && "$ERR" == *"empty file"* && "$(shots)" -eq 0 ]]; then pass "an empty capture is an error, nothing saved"; else fail "empty: rc=$RC"; fi
run no-maim -- --full --file
if [[ $RC -ne 0 && "$ERR" == *"maim is not installed"* ]]; then pass "missing maim fails up front"; else fail "no maim: rc=$RC err=$ERR"; fi
run all -- --bogus
if [[ $RC -ne 0 ]] && ! has maim; then pass "unknown option rejected"; else fail "bogus: rc=$RC"; fi

if ((rc != 0)); then
    red "✗ dwm-screenshot is broken"
    exit 1
fi
green "✓ dwm-screenshot: modes, theming, cancels and delivery all hold"
