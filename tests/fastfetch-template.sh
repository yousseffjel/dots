#!/usr/bin/env bash
# Exercises fastfetch.dcol through the real template engine. Its sibling
# tests/starship-template.sh does the same for starship.dcol; the two were
# split rather than combined because one file crossed the 250-line cap in
# rules/foundations/file-architecture.md. They duplicate a short harness on
# purpose, which is the same convention CLAUDE.md rule 2 sets for the colour
# helpers in scripts/.
#
# fastfetch has no static counterpart to diff against the way picom does, so
# this checks the properties that actually break in practice:
#   * placeholders are all substituted (the engine never checks for leftovers)
#   * the template is skipped while its parent directory is missing, which is
#     what makes the installer's mkdir load-bearing
#   * the output is valid JSON and every requested module actually renders
#
# SAFETY: the engine runs against a throwaway tree containing ONLY the template
# under test. Running the whole `always` group would fire every post-command,
# and three act on the live session however the environment is sandboxed —
# dunst.dcol runs `pkill -x dunst`, statusbar.dcol `pkill -x dwmblocks`, and
# xresources.dcol `xrdb -merge` against the running X server. pkill matches by
# process name system-wide, so env isolation cannot contain it. Fakes for
# pkill/xrdb/setsid go first on PATH as a second layer.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

PALETTE="$DOTS_DIR/themes/dark/colors.dcol"
ENGINE="$DOTS_DIR/scripts/theme/apply-templates.sh"
FASTFETCH_TMPL="$DOTS_DIR/config/theme/templates/always/fastfetch.dcol"

for f in "$PALETTE" "$ENGINE" "$FASTFETCH_TMPL"; do
    [[ -f "$f" ]] || {
        red "missing: $f"
        exit 1
    }
done

PASS=0
FAIL=0
SKIP=0
ok() {
    green "  ok: $*"
    PASS=$((PASS + 1))
}
bad() {
    red "  FAIL: $*"
    FAIL=$((FAIL + 1))
}
skip() {
    yellow "  skip: $*"
    SKIP=$((SKIP + 1))
}

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

mkdir -p "$SB/bin"
for f in pkill xrdb setsid; do
    printf '#!/bin/sh\nexit 0\n' >"$SB/bin/$f"
    chmod 755 "$SB/bin/$f"
done

# One throwaway DOTS_DIR per template. apply-templates.sh resolves
# TEMPLATES_DIR from its own location, so a copy of the script beside a
# one-template tree processes exactly that template.
make_tree() {
    local name="$1" tmpl="$2"
    mkdir -p "$SB/$name/dots/scripts/theme" \
        "$SB/$name/dots/config/theme/templates/always" \
        "$SB/$name/config" "$SB/$name/cache" "$SB/$name/home"
    cp "$ENGINE" "$SB/$name/dots/scripts/theme/"
    cp "$tmpl" "$SB/$name/dots/config/theme/templates/always/"
}

run_engine() {
    local name="$1"
    env -u DISPLAY PATH="$SB/bin:$PATH" HOME="$SB/$name/home" \
        XDG_CONFIG_HOME="$SB/$name/config" XDG_CACHE_HOME="$SB/$name/cache" \
        bash "$SB/$name/dots/scripts/theme/apply-templates.sh" \
        --palette "$PALETTE" always 2>&1
}

# Expected hex for a placeholder, read from the static palette.
palette_hex() { sed -n "s/^dcol_$1=\"\{0,1\}\([0-9A-Fa-f]*\)\"\{0,1\}$/\1/p" "$PALETTE"; }

# -------------------------------------------------------------- fastfetch --
blue "==> fastfetch.dcol"
make_tree fastfetch "$FASTFETCH_TMPL"

# Deliberately BEFORE creating ~/.config/fastfetch. The engine treats a missing
# parent directory as "app not installed", which is why the installer has to
# create this one — if that mkdir is ever dropped, fastfetch silently stops
# being themed and nothing else notices.
#
# This asserts on the engine's SKIP MESSAGE, not merely on the file's absence.
# Absence alone is true whether the engine skipped cleanly or failed trying to
# write into a directory that is not there, so the weaker check passes even
# with the install-check deleted — confirmed by mutating it to `if false`.
preout="$(run_engine fastfetch 2>&1 || true)"
if [[ -e "$SB/fastfetch/config/fastfetch/config.jsonc" ]]; then
    bad "rendered despite a missing parent directory"
elif printf '%s' "$preout" | grep -q 'skip.*fastfetch\.dcol'; then
    ok "skipped when ~/.config/fastfetch does not exist (installer must mkdir it)"
else
    bad "no file written, but the engine did not report a skip — it errored instead"
    printf '%s\n' "$preout"
fi

mkdir -p "$SB/fastfetch/config/fastfetch"
if ! out="$(run_engine fastfetch)"; then
    red "engine failed:"
    printf '%s\n' "$out"
    exit 1
fi

FF="$SB/fastfetch/config/fastfetch/config.jsonc"
if [[ -f "$FF" ]]; then
    ok "config.jsonc written once the directory exists"
else
    bad "no config.jsonc produced"
fi

if [[ -f "$FF" ]] && grep -q 'wallbash_' "$FF"; then
    bad "unsubstituted placeholder: $(grep -n 'wallbash_' "$FF" | head -1)"
else
    ok "no unsubstituted placeholders"
fi

for pair in "keys:1xa7" "title:3xa8"; do
    field="${pair%%:*}"
    want="#$(palette_hex "${pair##*:}")"
    if grep -q "\"$field\": \"$want\"" "$FF"; then
        ok "display.color.$field is $want"
    else
        bad "display.color.$field is not $want: $(grep "\"$field\"" "$FF" | head -1)"
    fi
done

# Modules the config asks for. fastfetch IGNORES an unknown module type and
# still exits 0 — verified by renaming `kernel` to `kernelz`, which drops the
# line silently — so exit status alone would not catch a typo here.
MODULES=(os kernel uptime packages shell wm terminal cpu gpu memory disk)
missing=()
for m in "${MODULES[@]}"; do
    grep -q "\"type\": \"$m\"" "$FF" || missing+=("$m")
done
if [[ ${#missing[@]} -eq 0 ]]; then
    ok "all ${#MODULES[@]} modules declared in the generated config"
else
    bad "modules missing from the config: ${missing[*]}"
fi

# JSONC is JSON plus comments; strip // lines before handing it to a parser.
if command -v python3 >/dev/null 2>&1; then
    if python3 -c '
import json,sys,re
src = open(sys.argv[1]).read()
src = re.sub(r"^\s*//.*$", "", src, flags=re.M)
json.loads(src)
' "$FF" 2>/dev/null; then
        ok "generated config is valid JSON once comments are stripped"
    else
        bad "generated config is not valid JSON"
    fi
else
    skip "python3 not available — JSON validity not checked"
fi

if command -v fastfetch >/dev/null 2>&1; then
    if ffout="$(fastfetch --config "$FF" 2>"$SB/ff.err")"; then
        ok "fastfetch parses the generated config"
        # Assert on rendered keys, not just exit status — see the note above.
        clean="$(printf '%s' "$ffout" | sed 's/\x1b\[[0-9;]*[A-Za-z]//g')"
        gone=()
        for m in "${MODULES[@]}"; do
            printf '%s' "$clean" | grep -qw "$m" || gone+=("$m")
        done
        if [[ ${#gone[@]} -eq 0 ]]; then
            ok "all ${#MODULES[@]} modules appear in fastfetch's output"
        else
            bad "declared but not rendered (unknown module type?): ${gone[*]}"
        fi
    else
        bad "fastfetch rejected the generated config: $(head -1 "$SB/ff.err")"
    fi
else
    skip "fastfetch not installed — generated config not parsed"
fi

# ------------------------------------------------------------------ result --
printf '\n'
if ((FAIL > 0)); then
    red "✗ fastfetch template: $PASS passed, $FAIL failed, $SKIP skipped"
    exit 1
fi
green "✓ fastfetch template: $PASS passed, $SKIP skipped"
