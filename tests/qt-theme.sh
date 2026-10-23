#!/usr/bin/env bash
# Qt theming (scope K slot 2): always/qt.dcol and theme_write_qt_conf
# (scripts/install-restore-theme-qt.sh). Checked:
#   * the template, for every shipped palette: three role lists of exactly 21
#     #aarrggbb colours, no placeholder left;
#   * its post-command re-places a regular qt*ct.conf (new inode, same bytes,
#     no temp file left) and never touches a symlinked one;
#   * the writer: both confs written and claimed; each with its own Qt font
#     format; the colour path absolute under XDG_CACHE_HOME; an installer
#     re-run keeps an edit; a switch rewrites ours from the selected theme;
#     a conf not ours survives both; a font with no size gets no [Fonts];
#     --dry-run writes nothing;
#   * REAL Qt (skipped without g++, Qt5/Qt6 dev files and both plugins): a
#     compiled probe per Qt major, offscreen, gets the palette, icon theme and
#     font, and an open app re-themes after a second apply.
# SAFETY: a throwaway tree holding ONLY qt.dcol (the gtk2-template.sh
# harness), and all four XDG variables under the test's own temp dir.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

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
check() {
    local what="$1"
    shift
    if "$@"; then ok "$what"; else bad "$what"; fi
}

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
H="$SB/home"
C="$H/.config"
K="$H/.cache"
mkdir -p "$SB/dots/scripts/theme" "$SB/dots/config/theme/templates/always" "$C" "$K" "$SB/bin"
cp "$DOTS_DIR/scripts/theme/apply-templates.sh" "$SB/dots/scripts/theme/"
cp "$DOTS_DIR/config/theme/templates/always/qt.dcol" "$SB/dots/config/theme/templates/always/"
for f in pkill xrdb setsid; do
    printf '#!/bin/sh\nexit 0\n' >"$SB/bin/$f" && chmod 755 "$SB/bin/$f"
done

# engine <palette> — the real engine, on the one-template tree.
engine() {
    env -u DISPLAY PATH="$SB/bin:$PATH" HOME="$H" XDG_CONFIG_HOME="$C" XDG_CACHE_HOME="$K" \
        XDG_STATE_HOME="$H/.local/state" XDG_DATA_HOME="$H/.local/share" \
        bash "$SB/dots/scripts/theme/apply-templates.sh" --palette "$1" always >"$SB/engine.log" 2>&1
}
OUT="$K/dots/theme/qt-colors.conf"

# 21 colours per list, every one #aarrggbb, all three lists present.
lists_ok() {
    local key line n=0
    for key in active_colors inactive_colors disabled_colors; do
        line="$(grep "^$key=" "$OUT")" || return 1
        line="${line#*=}"
        [[ "$(tr ',' '\n' <<<"$line" | grep -cE '^ ?#[0-9A-Fa-f]{8}$')" -eq 21 ]] || return 1
        [[ "$(tr ',' '\n' <<<"$line" | grep -c .)" -eq 21 ]] || return 1
        n=$((n + 1))
    done
    [[ $n -eq 3 ]] && ! grep -q '<wallbash' "$OUT"
}

blue "==> the template, every shipped palette"
for pal in "$DOTS_DIR"/themes/*/colors.dcol; do
    t="$(basename "$(dirname "$pal")")"
    engine "$pal" || {
        bad "$t: the engine failed: $(tail -1 "$SB/engine.log")"
        continue
    }
    check "$t: 3 lists x 21 #aarrggbb colours" lists_ok
done

blue "==> the post-command"
mkdir -p "$C/qt5ct" "$C/qt6ct" "$SB/mine"
printf '[Appearance]\nstyle=Fusion\n' >"$C/qt5ct/qt5ct.conf"
printf 'MINE\n' >"$SB/mine/qt6ct.conf"
ln -s "$SB/mine/qt6ct.conf" "$C/qt6ct/qt6ct.conf"
before="$(stat -c %i "$C/qt5ct/qt5ct.conf")"
engine "$DOTS_DIR/themes/dark/colors.dcol"
check "post-command reported ok" grep -q 'post-command ok' "$SB/engine.log"
check "a regular conf is re-placed (new inode: the watcher's rename)" \
    test "$(stat -c %i "$C/qt5ct/qt5ct.conf")" != "$before"
check "...with the same bytes" grep -qx 'style=Fusion' "$C/qt5ct/qt5ct.conf"
check "a symlinked conf stays a link to the same file" test -L "$C/qt6ct/qt6ct.conf"
check "...whose target is untouched" grep -qx MINE "$SB/mine/qt6ct.conf"
check "no temp file left" test -z "$(find "$C" -name '*.dots-tmp')"
rm -rf "$C/qt5ct" "$C/qt6ct"
engine "$DOTS_DIR/themes/dark/colors.dcol"
check "no conf at all: the post-command still succeeds" grep -q 'post-command ok' "$SB/engine.log"

# writer <theme-dir> <clobber> [dry-run] — theme_write_qt_conf as the installer
# (clobber 0) or a switch (clobber 1) calls it.
# A child bash, not a subshell: the writer reads theme.conf through DOTS_DIR,
# which must point at the sandbox repo there and nowhere else.
writer() {
    # shellcheck disable=SC2016 # expanded by the child bash
    env HOME="$H" XDG_CONFIG_HOME="$C" XDG_CACHE_HOME="$K" XDG_STATE_HOME="$H/.local/state" \
        XDG_DATA_HOME="$H/.local/share" SRC="$DOTS_DIR/scripts" DOTS_DIR="$SB/repo" \
        DRY_RUN="${3:-0}" CONF_HOME="$C" THEME_CONF_REL="$1/theme.conf" THEME_IDENTITY_CLOBBER="$2" \
        bash -c 'set -euo pipefail; source "$SRC/global_fn.sh"
            source "$SRC/install-restore-theme-identity.sh"; theme_write_qt_conf' >"$SB/writer.log" 2>&1
}
mkdir -p "$SB/repo/themes/dark" "$SB/repo/themes/probe" "$SB/repo/themes/nosize"
cp "$DOTS_DIR/themes/dark/theme.conf" "$SB/repo/themes/dark/"
printf 'icon_theme=ProbeIcons\nfont=Probe Sans 13\n' >"$SB/repo/themes/probe/theme.conf"
printf 'icon_theme=ProbeIcons\nfont=Monospace\n' >"$SB/repo/themes/nosize/theme.conf"
Q5="$C/qt5ct/qt5ct.conf"
Q6="$C/qt6ct/qt6ct.conf"
not_in() { ! grep -q "$1" "$2"; }
# A THEME row for <path>, read from the manifest file itself.
claimed() { grep -qP "^THEME\ttheme\t\Q$1\E\$" "$H/.local/state/dots/manifest" 2>/dev/null; }

blue "==> the writer"
writer themes/dark 0 1
check "--dry-run writes nothing" test ! -e "$Q5" -a ! -e "$Q6"
writer themes/dark 0
check "install: both confs written" test -f "$Q5" -a -f "$Q6"
both_claimed() { claimed "$Q5" && claimed "$Q6"; }
check "...and both claimed in the manifest" both_claimed
check "...colour path absolute under XDG_CACHE_HOME" grep -qx "color_scheme_path=$K/dots/theme/qt-colors.conf" "$Q6"
check "...icons from theme.conf" grep -qx "icon_theme=$(sed -n 's/^icon_theme=//p' "$DOTS_DIR/themes/dark/theme.conf")" "$Q5"
check "...Qt5 font: 10 fields" grep -qxE 'general="Noto Sans,10(,-?[0-9]+){8}"' "$Q5"
check "...Qt6 font: 16 fields" grep -qxE 'general="Noto Sans,10(,-?[0-9]+){14}"' "$Q6"
printf 'USER-EDIT=1\n' >>"$Q5"
writer themes/dark 0
check "installer re-run keeps an edit to ours" grep -qx USER-EDIT=1 "$Q5"
writer themes/probe 1
check "switch rewrites ours from the selected theme" grep -qx icon_theme=ProbeIcons "$Q5"
check "...the edit is gone" not_in USER-EDIT "$Q5"
check "...font from it, in Qt5's format" grep -q '"Probe Sans,13,' "$Q5"
check "...and in Qt6's" grep -q '"Probe Sans,13,' "$Q6"
writer themes/nosize 1
check "a font with no size: no [Fonts] section" not_in '^\[Fonts\]' "$Q6"
rm -rf "$C/qt5ct" "$C/qt6ct" "$H/.local/state"
mkdir -p "$C/qt5ct"
printf 'THEIRS\n' >"$Q5"
writer themes/probe 0
check "not ours, installer: untouched" grep -qx THEIRS "$Q5"
writer themes/probe 1
check "not ours, switch: untouched" grep -qx THEIRS "$Q5"
check "...and said so" grep -q "skipped $Q5" "$SB/writer.log"
check "...while qt6ct.conf, absent, was written" test -f "$Q6"

# shellcheck source=lib/qt-probe.sh
source "$SCRIPT_DIR/lib/qt-probe.sh"
qt_probe_real

echo
if [[ $FAIL -eq 0 ]]; then
    green "qt-theme: $PASS passed"
else
    red "qt-theme: $FAIL failed, $PASS passed"
    exit 1
fi
