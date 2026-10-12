#!/usr/bin/env bash
# No chord is grabbed by both dwm and sxhkd.
#
# Both call XGrabKey() on the root window; a keysym+modifier claimed twice
# goes to whichever grabbed first and the other silently gets nothing — no
# error in either log. Since dwm's MODKEY became Mod4Mask (Super) the two
# share one namespace, so "check it by eye" is no longer good enough.
#
# What is asserted:
#   * both sides parse to a non-empty chord list containing a known chord
#     (dwm super+p, sxhkd super+w) — an empty parse must not read as "no
#     overlap";
#   * MODKEY is resolved from its #define and TAGKEYS() expands to its four
#     chords, so a change to either is followed rather than assumed;
#   * the shipped files share no chord;
#   * a planted overlap IS reported, so the comparison itself is proven.
#
# Not covered: sxhkd's {a,b} brace expansion — the shipped sxhkdrc uses none,
# and a chord with a brace fails the parse loudly rather than being skipped.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

CONFIG="$DOTS_DIR/suckless/dwm/config.def.h"
SXHKDRC="$DOTS_DIR/config/sxhkd/sxhkdrc"
TMP="$(mktemp -d)"
# The parsers run outside any `if`/`||`, where set -e is disabled inside
# functions too and a failure would read as "no chords". An abort is reported
# here instead.
finished=0
trap '((finished)) || red "✗ key-collisions: a parser failed (unknown modifier, or brace expansion?)"; rm -rf "$TMP"' EXIT

# Chords are written "<mods sorted, '+'-joined>+<keysym>", e.g. shift+super+b.
# norm_chord <mod>... <keysym>
norm_chord() {
    local key="${*: -1}" mods=""
    # No grep for empty names here: one that matches nothing exits 1, and
    # under set -e a failing $(...) assignment ends the script silently.
    if (($# > 1)); then
        mods="$(printf '%s\n' "${@:1:$#-1}" | sort -u | paste -sd+ -)+"
    fi
    printf '%s\n' "$mods$key"
}

# mask_names <C modifier expression> — "MODKEY|ShiftMask" -> "super shift"
mask_names() {
    local part out=()
    IFS='|' read -ra parts <<<"$1"
    for part in "${parts[@]}"; do
        part="${part//[[:space:]]/}"
        [[ "$part" == MODKEY ]] && part="$MODKEY"
        case "$part" in
            ShiftMask) out+=(shift) ;;
            ControlMask) out+=(ctrl) ;;
            Mod1Mask) out+=(alt) ;;
            Mod4Mask) out+=(super) ;;
            0) ;;
            *) return 1 ;;
        esac
    done
    printf '%s\n' "${out[*]}"
}

# dwm_chords <config.def.h> — every key in keys[], TAGKEYS expanded.
dwm_chords() {
    local mods key line
    sed -n '/^static const Key keys\[\]/,/^};/p' "$1" >"$TMP/keys"
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*TAGKEYS\([[:space:]]*XK_([A-Za-z0-9_]+) ]]; then
            key="${BASH_REMATCH[1]}"
            for mods in 0 ControlMask ShiftMask 'ControlMask|ShiftMask'; do
                # shellcheck disable=SC2046 # word-split the modifier names
                norm_chord $(mask_names "MODKEY|$mods") "$key"
            done
        elif [[ "$line" =~ ^[[:space:]]*\{[[:space:]]*([A-Za-z0-9|[:space:]]+),[[:space:]]*XK_([A-Za-z0-9_]+) ]]; then
            key="${BASH_REMATCH[2]}"
            mods="$(mask_names "${BASH_REMATCH[1]}")" || return 1
            # shellcheck disable=SC2086 # word-split the modifier names
            norm_chord $mods "$key"
        fi
    done <"$TMP/keys"
}

# sxhkd_chords <sxhkdrc> — every unindented, non-comment line is a chord.
sxhkd_chords() {
    local line part parts mods=() key
    while IFS= read -r line; do
        [[ "$line" =~ ^[^#[:space:]] ]] || continue
        [[ "$line" != *[{}]* ]] || return 1
        IFS='+' read -ra parts <<<"${line// /}"
        mods=()
        for part in "${parts[@]:0:${#parts[@]}-1}"; do
            case "$part" in
                super | mod4) mods+=(super) ;;
                alt | mod1) mods+=(alt) ;;
                ctrl | control) mods+=(ctrl) ;;
                shift) mods+=(shift) ;;
                *) return 1 ;;
            esac
        done
        key="${parts[-1]}"
        norm_chord "${mods[@]}" "$key"
    done <"$1"
}

# Resolved here, not inside dwm_chords: that runs in a pipeline subshell.
MODKEY="$(sed -n 's/^#define MODKEY[[:space:]]\{1,\}\([A-Za-z0-9]*\).*/\1/p' "$CONFIG")"
[[ -n "$MODKEY" ]] || {
    red "no #define MODKEY in $CONFIG"
    exit 1
}

rc=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        rc=1
    fi
}

blue "==> parse both grabbers"
dwm_chords "$CONFIG" | sort -u >"$TMP/dwm"
sxhkd_chords "$SXHKDRC" | sort -u >"$TMP/sxhkd"
check "dwm: MODKEY+p parsed ($(wc -l <"$TMP/dwm") chords)" \
    grep -qx "$(norm_chord "$(mask_names MODKEY)" p)" "$TMP/dwm"
check "dwm: TAGKEYS expanded (ctrl+shift+MODKEY+9)" \
    grep -qx "$(norm_chord ctrl shift "$(mask_names MODKEY)" 9)" "$TMP/dwm"
check "sxhkd: super+w parsed ($(wc -l <"$TMP/sxhkd") chords)" grep -qx super+w "$TMP/sxhkd"

blue "==> the shipped files share no chord"
comm -12 "$TMP/dwm" "$TMP/sxhkd" >"$TMP/both"
check "no chord in both" test ! -s "$TMP/both"
while IFS= read -r chord; do red "        grabbed twice: $chord"; done <"$TMP/both"

blue "==> a planted overlap is reported"
cp "$SXHKDRC" "$TMP/sxhkdrc"
# dwm's togglebar chord, spelled with whatever MODKEY currently is.
planted="$(mask_names MODKEY)"
printf '\n%s + b\n\ttrue\n' "$planted" >>"$TMP/sxhkdrc"
sxhkd_chords "$TMP/sxhkdrc" | sort -u >"$TMP/planted"
check "$planted+b (dwm's togglebar) is caught" grep -qx "$planted+b" <(comm -12 "$TMP/dwm" "$TMP/planted")

# shellcheck disable=SC2034 # read by the EXIT trap
finished=1
if ((rc)); then
    red "✗ dwm and sxhkd keybindings collide"
    exit 1
fi
green "✓ dwm and sxhkd keybindings are disjoint"
