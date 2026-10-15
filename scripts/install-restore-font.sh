#!/usr/bin/env bash
# Deploys the vendored Nerd Font (Cascadia Code NF). Sourced by
# install-restore-theme.sh, never standalone: same assumptions as
# install-restore-cursor.sh (set -euo pipefail, global_fn.sh, DRY_RUN, the
# colour helpers).
#
# usage: source "$THEME_DIR/install-restore-font.sh"; restore_font_assets
#
# Void packages no Cascadia Code (scope I, decision D3), so the two variable
# NF faces are vendored under assets/fonts/. See that directory's README.md
# for provenance and the reproducible repack. They go into the per-user font
# directory fontconfig already scans, so no fonts.conf <dir> entry is needed.
#
# No fc-cache here, deliberately. fontconfig compares each font directory's
# mtime with its cache and rescans a new or changed one on the next app start,
# so the glyphs render at first login anyway. Running fc-cache at install
# wrote ~/.cache/fontconfig, which uninstall cannot claim back:
# tests/install-uninstall-symmetry.sh caught it.
FONT_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FONT_ASSET_DIR="$(cd "$FONT_SCRIPT_DIR/.." && pwd)/assets/fonts"
# shellcheck source=install-restore-vendored.sh
source "$FONT_SCRIPT_DIR/install-restore-vendored.sh"

restore_font_assets() {
    vendored_extract "$FONT_ASSET_DIR" "${XDG_DATA_HOME:-$HOME/.local/share}/fonts" font
}
