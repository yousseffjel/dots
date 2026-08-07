#!/usr/bin/env bash
# Proves config/picom/picom.conf and config/theme/templates/always/picom.dcol
# carry identical settings.
#
# Why this test exists: picom.dcol regenerates ~/.config/picom/picom.conf in
# full on every wallpaper change, while config/picom/picom.conf is what the
# installer copies onto a fresh machine. A setting changed in only one of them
# looks correct after install and is silently reverted the first time the
# wallpaper changes. That failure is invisible without a check like this one.
#
# It does not compare the two files directly — it runs the real template engine
# and diffs its output, so a substitution bug would fail here too.
#
# SAFETY: the engine is pointed at a throwaway tree containing ONLY picom.dcol.
# Running the whole `always` group would fire every template's post-command,
# and several of those act on the live session no matter how the environment is
# sandboxed: dunst.dcol runs `pkill -x dunst`, statusbar.dcol runs
# `pkill -x dwmblocks`, and xresources.dcol runs `xrdb -merge` against the
# running X server. pkill matches by process name system-wide, so env isolation
# cannot contain it. A fake pkill is also placed first on PATH so even picom's
# own post-command signals nothing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

CONF="$DOTS_DIR/config/picom/picom.conf"
TMPL="$DOTS_DIR/config/theme/templates/always/picom.dcol"
PALETTE="$DOTS_DIR/themes/dark/colors.dcol"

for f in "$CONF" "$TMPL" "$PALETTE" "$DOTS_DIR/scripts/theme/apply-templates.sh"; do
    if [[ ! -f "$f" ]]; then
        red "missing: $f"
        exit 1
    fi
done

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

# Throwaway DOTS_DIR: apply-templates.sh resolves TEMPLATES_DIR from its own
# location ($SCRIPT_DIR/../../config/theme/templates), so a copy of the script
# beside a templates tree holding only picom.dcol processes only picom.
mkdir -p "$SB/dots/scripts/theme" "$SB/dots/config/theme/templates/always"
cp "$DOTS_DIR/scripts/theme/apply-templates.sh" "$SB/dots/scripts/theme/"
cp "$TMPL" "$SB/dots/config/theme/templates/always/"

# The engine skips a template whose target parent directory does not exist,
# treating that as "the app is not installed" — so this must be created.
mkdir -p "$SB/config/picom" "$SB/cache" "$SB/home"

mkdir -p "$SB/bin"
cat >"$SB/bin/pkill" <<'FAKE'
#!/bin/sh
exit 0
FAKE
chmod 755 "$SB/bin/pkill"

blue "==> generating picom.conf from picom.dcol via the real engine"
if ! out="$(env -u DISPLAY PATH="$SB/bin:$PATH" HOME="$SB/home" \
    XDG_CONFIG_HOME="$SB/config" XDG_CACHE_HOME="$SB/cache" \
    bash "$SB/dots/scripts/theme/apply-templates.sh" --palette "$PALETTE" always 2>&1)"; then
    red "template engine failed:"
    printf '%s\n' "$out"
    exit 1
fi

GENERATED="$SB/config/picom/picom.conf"
if [[ ! -f "$GENERATED" ]]; then
    red "engine produced no $GENERATED"
    printf '%s\n' "$out"
    exit 1
fi

# Settings only. The two files legitimately differ in their headers — one says
# "static fallback", the other "generated, do not edit" — and the template
# carries a target|post-command line the output does not.
strip_settings() {
    sed 's/#.*//' "$1" | sed 's/[[:space:]]*$//' | grep -v '^[[:space:]]*$'
}

blue "==> diffing generated output against the installer's copy"
if diff -u <(strip_settings "$CONF") <(strip_settings "$GENERATED") >"$SB/diff"; then
    green "  ok: picom.conf and picom.dcol are in lockstep"
else
    red "  picom.conf and picom.dcol have drifted apart"
    red "  (left = config/picom/picom.conf, right = generated from picom.dcol)"
    cat "$SB/diff"
    exit 1
fi

# An unresolved <wallbash_*> would mean the palette lacked a key the template
# uses — the engine does not check for leftovers itself.
if grep -q 'wallbash_' "$GENERATED"; then
    red "  unsubstituted placeholder left in the generated file:"
    grep -n 'wallbash_' "$GENERATED"
    exit 1
fi
green "  ok: no unsubstituted placeholders"

# Cheap libconfig sanity: balanced braces/brackets. picom cannot be run here to
# parse it for real (starting it would composite over the live session).
check_balance() {
    local f="$1" name="$2" opens closes
    # Compared numerically, not as strings: wc emits leading whitespace on
    # some platforms, which would make "12" and " 12" look different.
    opens="$(tr -cd '{' <"$f" | wc -c)"
    closes="$(tr -cd '}' <"$f" | wc -c)"
    if ((opens != closes)); then
        red "  $name: unbalanced braces ($opens '{' vs $closes '}')"
        return 1
    fi
    opens="$(tr -cd '[' <"$f" | wc -c)"
    closes="$(tr -cd ']' <"$f" | wc -c)"
    if ((opens != closes)); then
        red "  $name: unbalanced brackets ($opens '[' vs $closes ']')"
        return 1
    fi
    return 0
}

rc=0
check_balance "$CONF" "picom.conf" || rc=1
check_balance "$GENERATED" "generated picom.conf" || rc=1
if [[ $rc -ne 0 ]]; then
    exit 1
fi
green "  ok: braces and brackets balanced in both"

green "✓ picom lockstep verified"
