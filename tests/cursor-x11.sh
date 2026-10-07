#!/usr/bin/env bash
# Guards the cursor for everything that is NOT GTK — the two outputs
# theme_write_cursor_default and theme_write_xcursor_resources render from
# theme.conf (scripts/install-restore-theme-identity.sh).
#
# WHY THIS TEST EXISTS. Until 2026-10-07 the cursor reached settings.ini and
# xsettingsd only, so Firefox drew Bibata while dwm — the wallpaper and the
# bar — st and alacritty drew the distro default. Nothing failed; the pointer
# just changed shape between windows. tests/theme-identity.sh proves the GTK
# half; this proves the libXcursor half, and the same contract around it:
#   1. both outputs carry theme.conf's values, the SELECTED theme's on a switch
#   2. an installer re-run changes nothing and claims nothing twice
#   3. an icons/default/ we did not create is never touched, in either mode
#   4. the X resources survive xrdb's cpp pass (no apostrophe, no slash-star)
#   5. both entry points — installer and theme switch — call both writers
#
# The writers are called directly. Nothing here runs reload.sh or xrdb: the
# merge order at login is tests/xinitrc-theme.sh's job, and reload.sh pkills
# desktop daemons system-wide.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Every XDG variable, not just HOME: the manifest lives under XDG_STATE_HOME.
export HOME="$TMP/home"
export XDG_CONFIG_HOME="$TMP/home/.config"
export XDG_STATE_HOME="$TMP/home/.local/state"
export XDG_CACHE_HOME="$TMP/home/.cache"
export XDG_DATA_HOME="$TMP/home/.local/share"
mkdir -p "$HOME"

# global_fn.sh supplies the colour helpers — see tests/theme-identity.sh.
# shellcheck source=../scripts/global_fn.sh
source "$DOTS_DIR/scripts/global_fn.sh"

rc=0
assert_eq() {
    if [[ "$2" == "$3" ]]; then
        green "  ok: $1"
    else
        red "  FAIL: $1"
        red "        want: $2"
        red "        got:  $3"
        rc=1
    fi
}

# A sandbox repo with a probe theme whose cursor differs from every shipped one.
REPO="$TMP/repo"
mkdir -p "$REPO/themes/probe"
cp -r "$DOTS_DIR/themes/dark" "$REPO/themes/dark"
printf 'cursor_theme=Probe-Cursor\ncursor_size=48\n' >"$REPO/themes/probe/theme.conf"

IDX="$XDG_DATA_HOME/icons/default/index.theme"
XC="$XDG_CACHE_HOME/dots/theme/xcursor"
want_cursor="$(sed -n 's/^cursor_theme=//p' "$DOTS_DIR/themes/dark/theme.conf")"
want_size="$(sed -n 's/^cursor_size=//p' "$DOTS_DIR/themes/dark/theme.conf")"

# Mirrors the callers: DRY_RUN and CONF_HOME are set by them, never defaulted.
# A child bash, so DOTS_DIR can point at the sandbox repo for the writers alone.
run_writers() {
    # shellcheck disable=SC2016 # $1 expands in the child
    DOTS_DIR="$REPO" DRY_RUN=0 CONF_HOME="$XDG_CONFIG_HOME" \
        THEME_CONF_REL="$1" THEME_IDENTITY_CLOBBER="$2" "$(type -P bash)" -c 'set -euo pipefail
        source "$1/scripts/global_fn.sh"
        source "$1/scripts/install-restore-theme-identity.sh"
        theme_write_cursor_default
        theme_write_xcursor_resources' _ "$SCRIPT_DIR/.." >/dev/null
}
rows() { manifest_rows THEME | cut -f3 | grep -cxF "$XDG_DATA_HOME/icons/default" || true; }

blue "==> fresh install"
run_writers themes/dark/theme.conf 0
assert_eq "index.theme inherits theme.conf's cursor" "Inherits=$want_cursor" "$(grep '^Inherits=' "$IDX" || true)"
assert_eq "Xcursor.theme" "Xcursor.theme: $want_cursor" "$(grep '^Xcursor.theme:' "$XC" || true)"
assert_eq "Xcursor.size" "Xcursor.size: $want_size" "$(grep '^Xcursor.size:' "$XC" || true)"
assert_eq "the icons/default DIRECTORY is claimed, once" 1 "$(rows)"

blue "==> installer re-run"
before="$(cat "$IDX")"
run_writers themes/dark/theme.conf 0
assert_eq "index.theme unchanged" "$before" "$(cat "$IDX")"
assert_eq "no second manifest row" 1 "$(rows)"

blue "==> theme switch"
run_writers themes/probe/theme.conf 1
assert_eq "index.theme follows the selected theme" "Inherits=Probe-Cursor" "$(grep '^Inherits=' "$IDX" || true)"
assert_eq "Xcursor.theme follows the selected theme" "Xcursor.theme: Probe-Cursor" "$(grep '^Xcursor.theme:' "$XC" || true)"
assert_eq "Xcursor.size follows the selected theme" "Xcursor.size: 48" "$(grep '^Xcursor.size:' "$XC" || true)"
assert_eq "still one manifest row" 1 "$(rows)"

blue "==> cpp safety"
if grep -qF "'" "$XC" || grep -qF '/*' "$XC"; then
    red "  FAIL: $XC carries an apostrophe or slash-star — xrdb's cpp pass breaks on it"
    rc=1
else
    green "  ok: no apostrophe or slash-star in the X resources"
fi

blue "==> an icons/default/ that is not ours"
rm -rf "$HOME"
mkdir -p "$(dirname "$IDX")"
printf '[Icon Theme]\nInherits=Users-Own\n' >"$IDX"
for clobber in 0 1; do
    run_writers themes/dark/theme.conf "$clobber"
    assert_eq "left untouched (clobber=$clobber)" "Inherits=Users-Own" "$(grep '^Inherits=' "$IDX")"
done
assert_eq "and never claimed" 0 "$(rows)"
assert_eq "the X resources are still written" "Xcursor.theme: $want_cursor" "$(grep '^Xcursor.theme:' "$XC" || true)"

blue "==> an existing ~/.xinitrc"
# The report half; the merge order in the generated file is
# tests/xinitrc-theme.sh's. install-session.sh only defines functions.
# shellcheck source=../scripts/install-session.sh
source "$DOTS_DIR/scripts/install-session.sh"
report() { session_xinitrc_report "$1" 2>&1 | sed 's/\x1b\[[0-9;]*m//g'; }
SB="$TMP/xinitrc"
mkdir -p "$SB"
session_xinitrc_template >"$SB/xinitrc.shipped"
printf '#!/bin/sh\nexec dwm\n' >"$SB/old-xinitrc"
# 2026-10-05 to 2026-10-07: themed, but no cursor merge. The current template
# minus its xcursor lines, so the rest of the file is exactly what ships.
grep -v 'xcursor' "$SB/xinitrc.shipped" >"$SB/pre-cursor-xinitrc"
out="$(report "$SB/pre-cursor-xinitrc")"
if grep -q -- 'never loads the cursor size' <<<"$out" && ! grep -q -- 'never restores' <<<"$out" \
    && ! grep -q -- 'never starts dots-session.target' <<<"$out" && ! grep -q -- 'never stops clipmenud' <<<"$out"; then
    green "  ok: a pre-cursor ~/.xinitrc gets only the cursor line"
else
    red "  the pre-cursor ~/.xinitrc report is wrong: $out"
    rc=1
fi
cursor_line="$(sed -n 's/^          //p' <<<"$out")"
if [[ -n "$cursor_line" ]] && grep -qF -- "$cursor_line" "$DOTS_DIR/docs/THEMING.md"; then
    green "  ok: docs/THEMING.md carries the cursor paste line"
else
    red "  docs/THEMING.md lacks the cursor paste line: $cursor_line"
    rc=1
fi
# shellcheck disable=SC2016 # the paste line's own $c, matched literally
if grep -qF -- '[ -r "$c/xcursor" ]' <<<"$(report "$SB/old-xinitrc")"; then
    green "  ok: the full theme paste block includes the cursor merge"
else
    red "  the theme paste block for an un-themed ~/.xinitrc omits the cursor merge"
    rc=1
fi

blue "==> both entry points call both writers"
for caller in scripts/install-restore-theme.sh scripts/theme/theme-apply.sh; do
    for fn in theme_write_cursor_default theme_write_xcursor_resources; do
        if grep -qE "^[[:space:]]+$fn$" "$DOTS_DIR/$caller"; then
            green "  ok: $caller calls $fn"
        else
            red "  FAIL: $caller never calls $fn"
            rc=1
        fi
    done
done

if ((rc != 0)); then
    red "✗ non-GTK cursor"
    exit 1
fi
green "✓ non-GTK cursor"
