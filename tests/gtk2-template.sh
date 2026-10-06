#!/usr/bin/env bash
# Exercises gtk2.dcol through the real template engine, against every shipped
# palette. The template renders to the theme cache and its post-command moves
# the result into ~/.gtkrc-2.0, which is what GTK2 (lxpolkit's password
# prompt) reads. Checked here:
#   * every placeholder is substituted, for all four themes — a palette that
#     lacks a key the template uses leaves `#<wallbash_…>`, which GTK2 rejects
#     with a warning and skips that colour;
#   * every colour is a quoted 6-digit hex, and the cache and ~/.gtkrc-2.0 match;
#   * a second apply converges and leaves no temp file behind;
#   * a ~/.gtkrc-2.0 of the user's own — a file, or a symlink to one — is
#     never replaced: only a file carrying the engine's header is;
#   * the installer claims what the engine wrote and backs up anything else,
#     and the header string is spelled the same in all three places;
#   * every style the rc applies is defined.
# Whether GTK2 itself accepts the syntax cannot be checked on the Arch dev
# host (no gtk2); the change log records a run in a fedora:44 container.
#
# SAFETY: same harness as tests/starship-template.sh — a throwaway tree
# holding ONLY this template, so no other template's post-command (pkill
# dunst, pkill dwmblocks, xrdb) can reach the live session.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

ENGINE="$DOTS_DIR/scripts/theme/apply-templates.sh"
TMPL="$DOTS_DIR/config/theme/templates/always/gtk2.dcol"
INSTALLER="$DOTS_DIR/scripts/install-restore-theme.sh"
for f in "$ENGINE" "$TMPL" "$INSTALLER"; do
    [[ -f "$f" ]] || {
        red "missing: $f"
        exit 1
    }
done

PASS=0
FAIL=0
ok() {
    green "  ok: $*"
    PASS=$((PASS + 1))
}
bad() {
    red "  FAIL: $*"
    FAIL=$((FAIL + 1))
}

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

mkdir -p "$SB/bin"
for f in pkill xrdb setsid; do
    printf '#!/bin/sh\nexit 0\n' >"$SB/bin/$f"
    chmod 755 "$SB/bin/$f"
done

# apply-templates.sh resolves TEMPLATES_DIR from its own location, so a copy
# of the script beside a one-template tree processes exactly that template.
make_tree() {
    local name="$1"
    mkdir -p "$SB/$name/dots/scripts/theme" \
        "$SB/$name/dots/config/theme/templates/always" \
        "$SB/$name/config" "$SB/$name/cache" "$SB/$name/home"
    cp "$ENGINE" "$SB/$name/dots/scripts/theme/"
    cp "$TMPL" "$SB/$name/dots/config/theme/templates/always/"
}

# <name> <palette>
run_engine() {
    env -u DISPLAY PATH="$SB/bin:$PATH" HOME="$SB/$1/home" \
        XDG_CONFIG_HOME="$SB/$1/config" XDG_CACHE_HOME="$SB/$1/cache" \
        bash "$SB/$1/dots/scripts/theme/apply-templates.sh" \
        --palette "$2" always 2>&1
}

palette_hex() { sed -n "s/^dcol_$2=\"\{0,1\}\([0-9A-Fa-f]*\)\"\{0,1\}$/\1/p" "$1"; }

# <name> <palette>: one theme's render, checked end to end.
check_theme() {
    local name="$1" palette="$2" out cached rc want got
    make_tree "$name"
    if ! out="$(run_engine "$name" "$palette")"; then
        bad "$name: engine failed"
        printf '%s\n' "$out"
        return 0
    fi
    cached="$SB/$name/cache/dots/theme/gtkrc-2.0"
    rc="$SB/$name/home/.gtkrc-2.0"
    if [[ ! -f "$cached" || ! -f "$rc" ]]; then
        bad "$name: expected both $cached and ~/.gtkrc-2.0"
        printf '%s\n' "$out"
        return 0
    fi
    if grep -q 'wallbash_' "$rc"; then
        bad "$name: unsubstituted placeholder: $(grep -m1 'wallbash_' "$rc")"
    else
        ok "$name: no unsubstituted placeholders"
    fi
    if grep -E '^[[:space:]]+(bg|fg|base|text)\[' "$rc" \
        | grep -vqE '= "#[0-9A-Fa-f]{6}"$'; then
        bad "$name: a colour is not a quoted 6-digit hex"
    else
        ok "$name: every colour is a quoted 6-digit hex"
    fi
    if cmp -s "$cached" "$rc"; then
        ok "$name: ~/.gtkrc-2.0 matches the cache"
    else
        bad "$name: ~/.gtkrc-2.0 differs from the cache"
    fi
    want="$(palette_hex "$palette" pry1)"
    got="$(sed -n '/^style "dots-default"/,/^}/s/^ *bg\[NORMAL\] *= "#\(.*\)"$/\1/p' "$rc")"
    if [[ -n "$want" && "$got" == "$want" ]]; then
        ok "$name: window background is the palette's pry1"
    else
        bad "$name: window background '$got', palette pry1 '$want'"
    fi
}

blue "==> gtk2.dcol against every shipped palette"
shopt -s nullglob
palettes=("$DOTS_DIR"/themes/*/colors.dcol)
shopt -u nullglob
[[ ${#palettes[@]} -gt 0 ]] || bad "no themes/*/colors.dcol found"
for p in "${palettes[@]}"; do
    t="${p%/colors.dcol}"
    check_theme "${t##*/}" "$p"
done

PALETTE="${palettes[0]:-}"
RC="$SB/rerun/home/.gtkrc-2.0"

blue "==> a second apply converges"
make_tree rerun
run_engine rerun "$PALETTE" >/dev/null || true
cp "$RC" "$SB/first" 2>/dev/null || true
run_engine rerun "$PALETTE" >/dev/null || true
if cmp -s "$SB/first" "$RC"; then
    ok "second apply writes the same file"
else
    bad "second apply changed ~/.gtkrc-2.0"
fi
leftover="$(find "$SB/rerun/home" -name '*.dots-tmp')"
if [[ -z "$leftover" ]]; then
    ok "no temp file left in HOME"
else
    bad "left behind: $leftover"
fi

blue "==> a gtkrc of the user's own is never replaced"
make_tree own
printf '# the user own gtkrc\n' >"$SB/own/home/.gtkrc-2.0"
run_engine own "$PALETTE" >/dev/null || true
if grep -qx '# the user own gtkrc' "$SB/own/home/.gtkrc-2.0"; then
    ok "a regular file without the engine header is left alone"
else
    bad "the apply replaced the user's own .gtkrc-2.0"
fi
make_tree link
printf '# the user own gtkrc, kept in a dotfiles repo\n' >"$SB/link/theirs"
ln -s "$SB/link/theirs" "$SB/link/home/.gtkrc-2.0"
run_engine link "$PALETTE" >/dev/null || true
if grep -qx '# the user own gtkrc, kept in a dotfiles repo' "$SB/link/theirs" \
    && [[ -L "$SB/link/home/.gtkrc-2.0" ]]; then
    ok "a symlink to the user's own gtkrc is left alone, and so is its target"
else
    bad "the apply replaced the symlink or wrote through it"
fi

# A symlink to the cache copy itself carries the header. Replacing it must
# go through the temp file and mv: a plain cp onto it fails as "the same
# file", and through any other symlink it would write into the link's target.
make_tree cachelink
mkdir -p "$SB/cachelink/cache/dots/theme"
printf '# Generated by scripts/theme/apply-templates.sh — DO NOT EDIT.\n' \
    >"$SB/cachelink/cache/dots/theme/gtkrc-2.0"
ln -s "$SB/cachelink/cache/dots/theme/gtkrc-2.0" "$SB/cachelink/home/.gtkrc-2.0"
run_engine cachelink "$PALETTE" >/dev/null || true
if [[ -f "$SB/cachelink/home/.gtkrc-2.0" && ! -L "$SB/cachelink/home/.gtkrc-2.0" ]] \
    && grep -q '^style "dots-default"' "$SB/cachelink/home/.gtkrc-2.0"; then
    ok "a symlink to an engine-written file is replaced by the rendered file"
else
    bad "a symlink to an engine-written file was not replaced"
fi

blue "==> the engine header has one spelling in three places"
header="$(sed -n 's/.*\(Generated by scripts\/theme\/apply-templates.sh\).*/\1/p' "$TMPL" | head -n1)"
in_body="$(sed -n 2p "$TMPL")"
in_post="$(head -n1 "$TMPL")"
in_installer="$(sed -n "s/^ENGINE_HEADER='\(.*\)'$/\1/p" "$INSTALLER")"
if [[ -n "$header" && "$in_body" == *"$header"* && "$in_post" == *"'$header'"* &&
    "$in_installer" == "$header" ]]; then
    ok "template line 2, post-command and ENGINE_HEADER agree"
else
    bad "header drift — body: '$in_body', installer: '$in_installer'"
fi

blue "==> the installer claims what the engine wrote, and backs up the rest"
claims="$(
    # shellcheck source=../scripts/install-restore-theme.sh
    source "$INSTALLER"
    DRY_RUN=0
    PREEXISTING_TARGETS=()
    manifest_has_path() { return 1; }
    manifest_append_row() { echo "claim $3"; }
    h="$SB/claim"
    mkdir -p "$h"
    sed -n 2p "$TMPL" >"$h/generated"
    printf '# theirs\n' >"$h/theirs"
    ln -s "$h/generated" "$h/linked"
    for f in absent generated theirs linked; do theme_claim_engine_target "$h/$f"; done
    for f in "${PREEXISTING_TARGETS[@]}"; do echo "backup $f"; done
)"
want="claim $SB/claim/absent
claim $SB/claim/generated
backup $SB/claim/theirs
backup $SB/claim/linked"
if [[ "$claims" == "$want" ]]; then
    ok "absent and engine-written files are claimed; the user's and a symlink are backed up"
else
    bad "theme_claim_engine_target gave: $claims"
fi

blue "==> every applied style is defined"
defined="$(sed -n 's/^style "\([^"]*\)".*/\1/p' "$RC" | sort -u)"
applied="$(sed -n 's/^\(class\|widget_class\|widget\) .* style "\([^"]*\)"$/\2/p' "$RC" | sort -u)"
[[ -n "$applied" ]] || bad "the rc applies no style at all"
missing="$(comm -13 <(printf '%s\n' "$defined") <(printf '%s\n' "$applied"))"
if [[ -z "$missing" ]]; then
    ok "all applied styles are defined"
else
    bad "applied but undefined: $missing"
fi

echo
if [[ $FAIL -eq 0 ]]; then
    green "gtk2-template: $PASS passed"
else
    red "gtk2-template: $FAIL failed, $PASS passed"
    exit 1
fi
