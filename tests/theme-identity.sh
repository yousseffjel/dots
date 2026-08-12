#!/usr/bin/env bash
# Guards the theme IDENTITY path — the non-colour half of a theme (GTK theme
# name, icons, cursor, font) that scripts/install-restore-theme-identity.sh
# renders into settings.ini and xsettingsd.conf.
#
# WHY THIS TEST EXISTS. Until 2026-08-12 theme.conf was *printed* by
# theme-apply.sh and nothing more, and the writers read a hardcoded
# themes/dark/theme.conf. Both halves of that are easy to reintroduce, and
# neither announces itself: the palette still changes on a switch, so the
# desktop visibly re-themes while the GTK theme, icons and font stay frozen at
# whatever the install wrote. The bug looks like "GTK is just slow to notice".
#
# The three claims under test, in the order they can break:
#   1. the SELECTED theme's identity is what lands — not always dark's
#   2. an installer re-run never clobbers an existing file (THEME_IDENTITY_CLOBBER=0)
#   3. a switch clobbers only files the manifest claims as ours — a hand-written
#      settings.ini survives, with a warning, in both modes
#
# Claim 1 cannot be proved against the shipped themes: all four currently carry
# identical identity values, because this repo declares exactly one dark GTK
# theme (see any themes/*/theme.conf). So the fixture below adds a sandbox-only
# "probe" theme whose values are deliberately unlike every shipped one. Without
# it, a regression that hardcoded themes/dark would stay green forever.
#
# NOTHING HERE RUNS THE REAL apply-templates.sh OR reload.sh. Both are replaced
# by stubs in the sandbox repo, because the real ones fire post-commands that
# `pkill` dunst and dwmblocks system-wide — env sandboxing does not stop that,
# and a test that kills the developer's status bar gets deleted rather than
# fixed. The stubs also record their arguments, so the switch is still proved
# to have reached the engine with the right palette.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Sandbox every XDG variable, not just HOME: the manifest lives under
# XDG_STATE_HOME, and a HOME-only sandbox would point the writers at the real
# install manifest that uninstall.sh acts on.
export HOME="$TMP/home"
export XDG_CONFIG_HOME="$TMP/home/.config"
export XDG_STATE_HOME="$TMP/home/.local/state"
export XDG_CACHE_HOME="$TMP/home/.cache"
export XDG_DATA_HOME="$TMP/home/.local/share"
mkdir -p "$HOME"

# global_fn.sh supplies red/green/blue, so this file deliberately does NOT
# define its own — local copies would be overwritten here and become dead code
# (SC2329). Same exception tests/manifest-has-path.sh documents.
# shellcheck source=../scripts/global_fn.sh
source "$DOTS_DIR/scripts/global_fn.sh"

rc=0

# Assertion helpers rather than `cmd && pass || fail`: in that idiom a failing
# `pass` runs `fail` too (SC2015), so a green suite could hide a broken reporter.
assert_eq() {
    local desc="$1" want="$2" got="$3"
    if [[ "$want" == "$got" ]]; then
        green "  ok: $desc"
    else
        red "  FAIL: $desc"
        red "        want: $want"
        red "        got:  $got"
        rc=1
    fi
}

assert_contains() {
    local desc="$1" file="$2" needle="$3"
    if grep -qF -- "$needle" "$file" 2>/dev/null; then
        green "  ok: $desc"
    else
        red "  FAIL: $desc (no '$needle' in $file)"
        rc=1
    fi
}

assert_absent() {
    local desc="$1" file="$2" needle="$3"
    if grep -qF -- "$needle" "$file" 2>/dev/null; then
        red "  FAIL: $desc ('$needle' still in $file)"
        rc=1
    else
        green "  ok: $desc"
    fi
}

# --- sandbox repo -----------------------------------------------------------

REPO="$TMP/repo"
mkdir -p "$REPO"
cp -r "$DOTS_DIR/scripts" "$REPO/scripts"
cp -r "$DOTS_DIR/themes" "$REPO/themes"

STUB_LOG="$TMP/stub.log"
: >"$STUB_LOG"
for stub in apply-templates.sh reload.sh; do
    cat >"$REPO/scripts/theme/$stub" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "$stub" "\$*" >>"$STUB_LOG"
EOF
    chmod +x "$REPO/scripts/theme/$stub"
done

# The fixture theme. Every value differs from every shipped theme, so "the
# selected theme was used" and "dark was used" cannot both be true.
mkdir -p "$REPO/themes/probe"
cp "$REPO/themes/dark/colors.dcol" "$REPO/themes/probe/colors.dcol"
cat >"$REPO/themes/probe/theme.conf" <<'EOF'
gtk_theme=Probe-Gtk
icon_theme=Probe-Icons
cursor_theme=Probe-Cursor
cursor_size=42
font=Probe Sans 13
EOF

# A theme with a palette and no theme.conf at all — legal, and documented as
# "colours only, identity unchanged".
mkdir -p "$REPO/themes/nakedpalette"
cp "$REPO/themes/dark/colors.dcol" "$REPO/themes/nakedpalette/colors.dcol"

GTK_INI="$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
XS_CONF="$XDG_CONFIG_HOME/xsettingsd/xsettingsd.conf"

conf_val() { # conf_val <theme> <key> — read straight from the shipped file
    local line
    line="$(grep -m1 "^$2=" "$REPO/themes/$1/theme.conf" 2>/dev/null)" || return 0
    printf '%s\n' "${line#*=}"
}

ini_val() { # ini_val <key>
    local line
    line="$(grep -m1 "^$1=" "$GTK_INI" 2>/dev/null)" || return 0
    printf '%s\n' "${line#*=}"
}

# --- 1. every shipped theme is structurally usable --------------------------

blue "==> shipped themes are structurally complete"

mapfile -t SHIPPED < <(find "$DOTS_DIR/themes" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
assert_eq "themes/ holds more than one theme" "yes" "$([[ ${#SHIPPED[@]} -gt 1 ]] && echo yes || echo no)"

# Derived from dark rather than a hardcoded list of 89 names: an enumeration
# here would go stale the first time the engine gains a key.
DARK_KEYS="$(grep -o '^dcol_[a-z0-9_]*' "$DOTS_DIR/themes/dark/colors.dcol")"
for t in "${SHIPPED[@]}"; do
    if [[ ! -f "$DOTS_DIR/themes/$t/colors.dcol" ]]; then
        red "  FAIL: themes/$t has no colors.dcol"
        rc=1
        continue
    fi
    assert_eq "themes/$t carries dark's full key set" \
        "$DARK_KEYS" "$(grep -o '^dcol_[a-z0-9_]*' "$DOTS_DIR/themes/$t/colors.dcol")"
done

# --- 2. installer mode: writes once, never clobbers -------------------------

blue "==> installer mode (THEME_IDENTITY_CLOBBER=0)"

DRY_RUN=0
CONF_HOME="$XDG_CONFIG_HOME"
# THEME_CONF_REL and THEME_IDENTITY_CLOBBER are deliberately NOT set here.
# install-restore-theme.sh sets neither — it relies entirely on the defaults
# this file ships, so a test that supplied its own would leave those defaults
# unexercised and stay green while the installer started clobbering user
# configs. (Found by mutation: flipping the default to 1 survived until this
# was removed.)
# shellcheck source=../scripts/install-restore-theme-identity.sh
source "$REPO/scripts/install-restore-theme-identity.sh"
DOTS_DIR_REAL="$DOTS_DIR"
DOTS_DIR="$REPO"

assert_eq "shipped default is no-clobber" "0" "$THEME_IDENTITY_CLOBBER"
assert_eq "shipped default theme is dark" "themes/dark/theme.conf" "$THEME_CONF_REL"

theme_write_gtk_ini >/dev/null
theme_write_xsettingsd_conf >/dev/null
assert_eq "install renders gtk-theme-name from themes/dark" \
    "$(conf_val dark gtk_theme)" "$(ini_val gtk-theme-name)"
assert_contains "install renders xsettingsd.conf too" "$XS_CONF" "Net/ThemeName"
assert_contains "xsettingsd.conf keeps the Xft rendering keys" "$XS_CONF" "Xft/HintStyle"

printf 'USER-EDIT\n' >>"$GTK_INI"
theme_write_gtk_ini >/dev/null
assert_contains "installer re-run does not clobber our own file" "$GTK_INI" "USER-EDIT"

# --- 3. a switch applies the SELECTED theme ---------------------------------

blue "==> switch mode (theme-apply.sh)"

DOTS_DIR="$DOTS_DIR_REAL"
"$REPO/scripts/theme/theme-apply.sh" probe >/dev/null
assert_absent "switch replaces our file (the install-run edit is gone)" \
    "$GTK_INI" "USER-EDIT"
assert_eq "gtk-theme-name follows the selected theme" \
    "$(conf_val probe gtk_theme)" "$(ini_val gtk-theme-name)"
assert_eq "gtk-font-name follows the selected theme" \
    "$(conf_val probe font)" "$(ini_val gtk-font-name)"
assert_contains "xsettingsd.conf follows the selected theme" "$XS_CONF" "Probe-Gtk"
assert_contains "the switch still reached the engine" "$STUB_LOG" "themes/probe/colors.dcol"

# Back to a shipped theme: proves the wiring is not one-way (a switch that only
# ever moved away from dark would pass every assertion above).
"$REPO/scripts/theme/theme-apply.sh" nord >/dev/null
assert_eq "switching again follows the new selection" \
    "$(conf_val nord gtk_theme)" "$(ini_val gtk-theme-name)"

# --- 4. a theme with no theme.conf leaves identity alone --------------------

blue "==> theme with no theme.conf"

BEFORE="$(cat "$GTK_INI")"
"$REPO/scripts/theme/theme-apply.sh" nakedpalette >/dev/null
assert_eq "identity untouched when the theme has no theme.conf" "$BEFORE" "$(cat "$GTK_INI")"

# --- 5. a file we did not write is never clobbered --------------------------

blue "==> user-owned settings.ini"

rm -f "$XDG_STATE_HOME/dots/manifest"
printf 'HAND-WRITTEN\n' >"$GTK_INI"
"$REPO/scripts/theme/theme-apply.sh" probe >/dev/null
assert_contains "a switch refuses a settings.ini the manifest does not claim" \
    "$GTK_INI" "HAND-WRITTEN"

if ((rc != 0)); then
    red "✗ theme identity is broken"
    exit 1
fi
green "✓ theme identity: selection, no-clobber and user-owned files all hold"
