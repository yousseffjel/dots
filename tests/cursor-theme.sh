#!/usr/bin/env bash
# Guards the vendored cursor theme: the artifact under assets/cursors/, its
# extraction (restore_cursor_theme in scripts/install-restore-cursor.sh), and
# the one coupling that can silently break the desktop.
#
# WHY THIS TEST EXISTS. The cursor theme's name exists in two places that must
# agree: the top-level directory inside the tarball, and `cursor_theme=` in
# every themes/*/theme.conf. Nothing at runtime notices when they disagree —
# GTK and xsettingsd just fall back to a default cursor, so the symptom is "my
# cursor looks wrong", weeks later, with no error anywhere. Swapping the
# vendored variant without updating all four theme files produces exactly that.
#
# Neither side is restated here. The name is read out of the archive by the
# shipped cursor_theme_name(), and the declared value by the shipped
# theme_conf_get() — so this test cannot drift from what the installer does.
#
# The tarball is also NOT faked. A fixture archive would test this file against
# its own generator; the point is that the committed artifact is intact and
# shaped the way the installer assumes.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT_DIR="$DOTS_DIR/scripts"
ASSET_DIR="$DOTS_DIR/assets/cursors"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Every XDG variable, not just HOME: the extraction target derives from
# XDG_DATA_HOME and the manifest from XDG_STATE_HOME, so a HOME-only sandbox
# would write into the real install state that uninstall.sh acts on.
export HOME="$TMP/home"
export XDG_CONFIG_HOME="$TMP/home/.config"
export XDG_DATA_HOME="$TMP/home/.local/share"
export XDG_CACHE_HOME="$TMP/home/.cache"
export XDG_STATE_HOME="$TMP/home/.local/state"
mkdir -p "$HOME"

# global_fn.sh owns red/green/yellow/blue — this file must not define its own
# (they would be overwritten here and become dead code, SC2329).
# shellcheck source=../scripts/global_fn.sh
source "$SCRIPT_DIR/global_fn.sh"

# theme_conf_get reads "$DOTS_DIR/$THEME_CONF_REL"; the identity writers want
# these set before the file is sourced, same as theme-apply.sh does.
DRY_RUN=0
CONF_HOME="$XDG_CONFIG_HOME"
# shellcheck source=../scripts/install-restore-theme-identity.sh
source "$SCRIPT_DIR/install-restore-theme-identity.sh"
# shellcheck source=../scripts/install-restore-cursor.sh
source "$SCRIPT_DIR/install-restore-cursor.sh"

rc=0

pass() { green "  ok: $1"; }
fail() {
    red "  FAIL: $1"
    rc=1
}

blue "==> the vendored artifact"

shopt -s nullglob
TARBALLS=("$ASSET_DIR"/*.tar.xz)
shopt -u nullglob

if [[ ${#TARBALLS[@]} -eq 1 ]]; then
    pass "exactly one cursor tarball in assets/cursors/"
else
    fail "${#TARBALLS[@]} tarballs in assets/cursors/ — restore_cursor_theme refuses to guess"
    red "cursor-theme: FAIL"
    exit 1
fi
TARBALL="${TARBALLS[0]}"

# The checksum is the only thing standing between a corrupted or swapped
# artifact and 145 unpacked files in the user's icon directory.
if [[ -f "$TARBALL.sha256" ]]; then
    if (cd "$ASSET_DIR" && sha256sum -c --status "$(basename "$TARBALL.sha256")"); then
        pass "artifact matches its recorded sha256"
    else
        fail "artifact does NOT match $TARBALL.sha256"
    fi
else
    fail "no .sha256 beside the tarball — nothing pins what is committed"
fi

if [[ -f "$ASSET_DIR/LICENSE.Bibata" ]]; then
    pass "upstream license vendored alongside the artifact"
else
    fail "LICENSE.Bibata missing — the release tarball carries no license of its own"
fi

blue "==> the name coupling"

NAME="$(cursor_theme_name "$TARBALL")"
if [[ -n "$NAME" ]]; then
    pass "theme name read from the archive: $NAME"
else
    fail "could not read a top-level directory out of the archive"
    red "cursor-theme: FAIL"
    exit 1
fi

# Globbed, never enumerated: a fifth theme added later is covered for free.
themes_checked=0
for conf in "$DOTS_DIR"/themes/*/theme.conf; do
    theme="$(basename "$(dirname "$conf")")"
    THEME_CONF_REL="themes/$theme/theme.conf"
    declared="$(theme_conf_get cursor_theme)"
    themes_checked=$((themes_checked + 1))
    if [[ "$declared" == "$NAME" ]]; then
        pass "themes/$theme declares cursor_theme=$NAME"
    else
        fail "themes/$theme declares cursor_theme='$declared', archive ships '$NAME'"
    fi
done
if [[ $themes_checked -eq 0 ]]; then
    fail "no themes/*/theme.conf found — the coupling went unchecked"
else
    pass "$themes_checked theme.conf file(s) checked"
fi

blue "==> extraction"

ICONS="$XDG_DATA_HOME/icons"
DST="$ICONS/$NAME"

DRY_RUN=1 restore_cursor_theme >/dev/null 2>&1
if [[ -e "$DST" ]]; then
    fail "dry-run extracted something"
else
    pass "dry-run touched nothing"
fi

DRY_RUN=0 restore_cursor_theme >/dev/null 2>&1
if [[ -f "$DST/index.theme" ]]; then
    pass "fresh extract produced $NAME/index.theme"
else
    fail "fresh extract did not produce $NAME/index.theme"
fi
if [[ -d "$DST/cursors" ]]; then
    pass "cursors/ directory present"
else
    fail "cursors/ directory missing — nothing would render"
fi
if manifest_has_path THEME "$DST"; then
    pass "extraction recorded a THEME row"
else
    fail "no THEME row — uninstall.sh could not remove the tree"
fi

DRY_RUN=0 restore_cursor_theme >/dev/null 2>&1
DRY_RUN=0 restore_cursor_theme >/dev/null 2>&1
rows="$(manifest_rows THEME | grep -c "$DST" || true)"
if [[ "$rows" -eq 1 ]]; then
    pass "exactly one THEME row after three runs"
else
    fail "$rows THEME rows for $DST (rule 1: re-running must not duplicate)"
fi

blue "==> a pre-existing directory is neither clobbered nor claimed"
rm -rf "$HOME/.local" "$XDG_STATE_HOME"
mkdir -p "$DST"
printf 'not ours\n' >"$DST/MINE"
DRY_RUN=0 restore_cursor_theme >/dev/null 2>&1
if [[ -f "$DST/MINE" ]]; then
    pass "pre-existing directory left untouched"
else
    fail "pre-existing directory was overwritten"
fi
if manifest_has_path THEME "$DST"; then
    fail "pre-existing directory claimed — uninstall.sh would rm -rf it"
else
    pass "pre-existing directory not claimed in the manifest"
fi

blue "==> a tampered artifact is rejected"
cp "$TARBALL" "$TMP/t.tar.xz"
(cd "$TMP" && sha256sum t.tar.xz >t.tar.xz.sha256)
if cursor_verify_checksum "$TMP/t.tar.xz"; then
    pass "intact copy verifies"
else
    fail "intact copy failed verification"
fi
printf 'corrupt' >>"$TMP/t.tar.xz"
if cursor_verify_checksum "$TMP/t.tar.xz"; then
    fail "tampered artifact passed verification"
else
    pass "tampered artifact rejected"
fi

if [[ $rc -eq 0 ]]; then
    green "cursor-theme: PASS"
else
    red "cursor-theme: FAIL"
fi
exit $rc
