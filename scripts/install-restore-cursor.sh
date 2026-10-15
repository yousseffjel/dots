#!/usr/bin/env bash
# Deploys the vendored cursor theme. Sourced by install-restore-theme.sh,
# never standalone: assumes the caller has `set -euo pipefail`, sourced
# global_fn.sh (manifest_has_path/manifest_append_row), set DRY_RUN, and
# defined the red/green/yellow/blue helpers.
#
# usage: source "$THEME_DIR/install-restore-cursor.sh"; restore_cursor_theme
#
# No distro this repo has targeted packages Bibata, so the release tarball is
# vendored under assets/cursors/ and extracted here. See that directory's
# README.md for provenance and the manual update procedure. This is what the
# reference implementation does too: HyDE's restore_fnt.sh extracts vendored
# archives and never downloads.
#
# The extraction itself is shared with the vendored font
# (install-restore-vendored.sh). The cursor_* names stay because
# tests/cursor-theme.sh and the theme stage call them.
#
# Resolved from BASH_SOURCE rather than the caller's DOTS_DIR, matching
# install-restore-theme.sh's own choice: this file is SOURCED, and a test may
# source it with no DOTS_DIR set at all.
CURSOR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURSOR_ASSET_DIR="$(cd "$CURSOR_SCRIPT_DIR/.." && pwd)/assets/cursors"
# shellcheck source=install-restore-vendored.sh
source "$CURSOR_SCRIPT_DIR/install-restore-vendored.sh"

# The tarball's single top-level directory: the cursor theme's name as
# XCURSOR_PATH consumers see it, and the value themes/*/theme.conf must carry.
# Read out of the archive rather than hardcoded, so swapping variants is a
# file swap plus the theme.conf lines tests/cursor-theme.sh checks.
cursor_theme_name() { vendored_top_dir "$1"; }

cursor_verify_checksum() { vendored_verify_checksum "$1"; }

cursor_select_tarball() { vendored_select_tarball "$CURSOR_ASSET_DIR" cursor; }

restore_cursor_theme() {
    vendored_extract "$CURSOR_ASSET_DIR" "${XDG_DATA_HOME:-$HOME/.local/share}/icons" cursor
}
