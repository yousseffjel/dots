#!/usr/bin/env bash
# Guards the vendored Nerd Font (assets/fonts/, scope I decision D3) and its
# deployment (restore_font_assets in scripts/install-restore-font.sh).
#
# WHY THIS TEST EXISTS. Every terminal, the bar, dmenu and nsxiv name the
# family "Cascadia Code NF" (tests/fontconfig-stack.sh lists where). If the
# vendored files registered under any other family, or the install left them
# uncached, nothing would error: fontconfig silently substitutes another
# monospace face, and every Nerd Font glyph turns to tofu.
#
# The artifact is the committed one, never a fixture. The install runs no
# fc-cache (install-restore-font.sh says why), and this test fails if it
# starts to: a fake fc-cache on PATH logs any call. Everything else is the
# shipped code running in a sandbox HOME with all four XDG variables set.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$TEST_DIR/.." && pwd)"
SCRIPT_DIR="$DOTS_DIR/scripts"
ASSET_DIR="$DOTS_DIR/assets/fonts"
FAMILY="Cascadia Code NF"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
export XDG_CONFIG_HOME="$TMP/home/.config"
export XDG_DATA_HOME="$TMP/home/.local/share"
export XDG_CACHE_HOME="$TMP/home/.cache"
export XDG_STATE_HOME="$TMP/home/.local/state"
mkdir -p "$HOME" "$TMP/bin"

FC_LOG="$TMP/fc-cache.log"
cat >"$TMP/bin/fc-cache" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$FC_LOG"
EOF
chmod 755 "$TMP/bin/fc-cache"
REAL_PATH="$PATH"
export PATH="$TMP/bin:$PATH"

# global_fn.sh owns red/green/yellow/blue (rule 2's exception for tests that
# source it; defining our own would be dead code, SC2329).
# shellcheck source=../scripts/global_fn.sh
source "$SCRIPT_DIR/global_fn.sh"
# shellcheck source=../scripts/install-restore-font.sh
source "$SCRIPT_DIR/install-restore-font.sh"

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
if [[ ${#TARBALLS[@]} -ne 1 ]]; then
    fail "${#TARBALLS[@]} tarballs in assets/fonts/ — restore_font_assets refuses to guess"
    red "font-asset: FAIL"
    exit 1
fi
TARBALL="${TARBALLS[0]}"
pass "exactly one font tarball: $(basename "$TARBALL")"

if [[ -f "$TARBALL.sha256" ]] && (cd "$ASSET_DIR" && sha256sum -c --status "$(basename "$TARBALL.sha256")"); then
    pass "artifact matches its recorded sha256"
else
    fail "artifact missing or not matching $TARBALL.sha256"
fi
if [[ -f "$ASSET_DIR/LICENSE.CascadiaCode" ]] && grep -q 'SIL Open Font License' "$ASSET_DIR/LICENSE.CascadiaCode"; then
    pass "OFL license vendored alongside the artifact"
else
    fail "LICENSE.CascadiaCode missing or not the OFL"
fi

NAME="$(vendored_top_dir "$TARBALL")"
listing="$(tar -tJf "$TARBALL")"
ttfs="$(grep -c '\.ttf$' <<<"$listing" || true)"
if [[ -n "$NAME" && "$ttfs" -ge 1 ]] && ! grep -qv "^$NAME/" <<<"$listing"; then
    pass "one top-level directory ($NAME) holding $ttfs .ttf file(s)"
else
    fail "archive is not one directory of .ttf files: $(tr '\n' ' ' <<<"$listing")"
fi

blue "==> the family the configs name"
mkdir -p "$TMP/scan"
tar -xJf "$TARBALL" -C "$TMP/scan"
if PATH="$REAL_PATH" command -v fc-scan >/dev/null 2>&1; then
    families="$(PATH="$REAL_PATH" fc-scan --format '%{family}\n' "$TMP/scan/$NAME" | sort -u)"
    if [[ "$families" == "$FAMILY" ]]; then
        pass "every face registers as '$FAMILY'"
    else
        fail "faces register as: $(tr '\n' '|' <<<"$families") — expected only '$FAMILY'"
    fi
else
    yellow "  skip: no fc-scan on this host — family name unchecked"
fi

blue "==> extraction"
DST="$XDG_DATA_HOME/fonts/$NAME"
DRY_RUN=1 restore_font_assets >/dev/null 2>&1
if [[ ! -e "$DST" ]]; then
    pass "dry-run extracted nothing"
else
    fail "dry-run extracted into $DST"
fi

DRY_RUN=0 restore_font_assets >/dev/null 2>&1
if [[ "$(find "$DST" -name '*.ttf' 2>/dev/null | wc -l)" -eq "$ttfs" ]]; then
    pass "fresh extract produced all $ttfs faces under fonts/$NAME"
else
    fail "fresh extract did not produce the faces under $DST"
fi
if manifest_has_path THEME "$DST"; then
    pass "extraction recorded a THEME row (uninstall removes it)"
else
    fail "no THEME row — uninstall.sh could not remove the fonts"
fi
if [[ ! -s "$FC_LOG" ]]; then
    pass "no fc-cache run (it would leave ~/.cache/fontconfig behind after uninstall)"
else
    fail "fc-cache was run: $(tr '\n' '|' <"$FC_LOG")"
fi

DRY_RUN=0 restore_font_assets >/dev/null 2>&1
rows="$(manifest_rows THEME | grep -c "$DST" || true)"
if [[ "$rows" -eq 1 ]]; then
    pass "exactly one THEME row after a re-run"
else
    fail "$rows THEME rows for $DST (rule 1: re-running must not duplicate)"
fi

blue "==> a pre-existing directory is neither clobbered nor claimed"
rm -rf "$HOME/.local" "$XDG_STATE_HOME"
mkdir -p "$DST"
printf 'not ours\n' >"$DST/MINE"
DRY_RUN=0 restore_font_assets >/dev/null 2>&1
if [[ -f "$DST/MINE" ]] && ! manifest_has_path THEME "$DST"; then
    pass "left untouched and unclaimed"
else
    fail "pre-existing font directory was overwritten or claimed"
fi

if [[ $rc -eq 0 ]]; then
    green "font-asset: PASS"
else
    red "font-asset: FAIL"
fi
exit $rc
