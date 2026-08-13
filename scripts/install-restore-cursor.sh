#!/usr/bin/env bash
# Deploys the vendored cursor theme. Sourced by install-restore-theme.sh,
# never standalone: assumes the caller has `set -euo pipefail`, sourced
# global_fn.sh (manifest_has_path/manifest_append_row), set DRY_RUN, and
# defined the red/green/yellow/blue helpers.
#
# usage: source "$THEME_DIR/install-restore-cursor.sh"; restore_cursor_theme
#
# Fedora does not package Bibata (COPR only, and rule 4 makes a COPR the user's
# decision), so the release tarball is vendored under assets/cursors/ and
# extracted here. See that directory's README.md for provenance and the manual
# update procedure. This is what the reference implementation does too —
# HyDE's restore_fnt.sh extracts vendored archives and never downloads.
#
# Resolved from BASH_SOURCE rather than the caller's DOTS_DIR, matching
# install-restore-theme.sh's own choice: this file is SOURCED, and a test may
# source it with no DOTS_DIR set at all.
CURSOR_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURSOR_ASSET_DIR="$(cd "$CURSOR_SCRIPT_DIR/.." && pwd)/assets/cursors"

# Prints the tarball's single top-level directory — the cursor theme's name as
# XCURSOR_PATH consumers see it, and the value themes/*/theme.conf must carry.
#
# Read out of the archive rather than hardcoded: the name then follows the
# artifact, so swapping variants is a file swap plus the theme.conf lines that
# tests/cursor-theme.sh checks, with no third copy here to forget.
#
# NOT `tar -tJf ... | head -1`. head closing the pipe early SIGPIPEs tar, and
# under the pipefail every caller inherits, the pipeline reports 141 — a
# failure — even though the read succeeded. This repo has hit that exact trap
# three times; see manifest_has_path's header in global_fn.sh.
cursor_theme_name() {
    local tarball="$1" listing first
    listing="$(tar -tJf "$tarball")" || return 1
    first="${listing%%$'\n'*}"
    printf '%s\n' "${first%%/*}"
}

# Verifies the artifact against the recorded checksum before unpacking it.
# Cheap, and it means a corrupted or swapped tarball fails loudly here instead
# of extracting something unexpected into the user's icon directory.
cursor_verify_checksum() {
    local tarball="$1" sums="$1.sha256"
    [[ -f "$sums" ]] || return 0
    command -v sha256sum >/dev/null 2>&1 || return 0
    # Subshell cd: the .sha256 records a bare filename so `sha256sum -c` works
    # regardless of where the repo sits.
    (cd "$(dirname "$tarball")" && sha256sum -c --status "$(basename "$sums")")
}

# Prints the single vendored tarball's path, or returns non-zero after saying
# why there isn't one. Split out of restore_cursor_theme purely for the 60-line
# function cap — that function sat exactly at 60, so any later edit to it would
# have been a hard stop (file-architecture.md).
cursor_select_tarball() {
    local tarballs=()
    # Globbed, not named, so the variant lives in exactly one place: the file
    # that is actually committed.
    shopt -s nullglob
    tarballs=("$CURSOR_ASSET_DIR"/*.tar.xz)
    shopt -u nullglob

    if [[ ${#tarballs[@]} -eq 0 ]]; then
        yellow "warn    no cursor tarball in $CURSOR_ASSET_DIR — cursor theme not deployed"
        return 1
    fi
    if [[ ${#tarballs[@]} -gt 1 ]]; then
        red "refusing to guess: ${#tarballs[@]} cursor tarballs in $CURSOR_ASSET_DIR"
        yellow "        exactly one variant is supported — see that directory's README.md"
        return 1
    fi
    printf '%s\n' "${tarballs[0]}"
}

restore_cursor_theme() {
    local icons_dir="${XDG_DATA_HOME:-$HOME/.local/share}/icons"
    local tarball name dst

    # The guard messages are printed by the helper; a non-zero return here just
    # means "nothing to deploy", which is never fatal to an install.
    tarball="$(cursor_select_tarball)" || return 0

    if ! name="$(cursor_theme_name "$tarball")" || [[ -z "$name" ]]; then
        red "could not read the theme name out of $(basename "$tarball")"
        return 0
    fi
    dst="$icons_dir/$name"

    if [[ ${DRY_RUN:-0} -eq 1 ]]; then
        blue "  (dry-run) would extract $name -> $dst"
        return 0
    fi

    if [[ -e "$dst" ]]; then
        if manifest_has_path THEME "$dst"; then
            green "ok      $name already deployed by us"
        else
            # Same no-clobber rule the rest of the theme deploy follows: a
            # THEME row authorises uninstall to rm -rf this path, so never
            # claim a directory we did not create.
            green "ok      $dst exists (left untouched, not tracked for removal)"
        fi
        return 0
    fi

    if ! cursor_verify_checksum "$tarball"; then
        red "checksum mismatch on $(basename "$tarball") — refusing to extract"
        yellow "        re-fetch it; see $CURSOR_ASSET_DIR/README.md"
        return 0
    fi

    mkdir -p "$icons_dir"
    # -J: these are .tar.xz. HyDE's restore_fnt.sh uses -xzf for its .tar.gz
    # archives; copying that idiom verbatim here fails.
    if tar -xJf "$tarball" -C "$icons_dir"; then
        manifest_append_row THEME theme "$dst"
        green "wrote   $dst"
    else
        red "failed to extract $(basename "$tarball")"
    fi
}
