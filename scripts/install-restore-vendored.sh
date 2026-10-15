#!/usr/bin/env bash
# Shared extraction for vendored assets/<kind>/*.tar.xz artifacts: the
# cursor theme (install-restore-cursor.sh) and the Nerd Font
# (install-restore-font.sh). Sourced, never standalone: assumes the caller
# has `set -euo pipefail`, sourced global_fn.sh
# (manifest_has_path/manifest_append_row), set DRY_RUN, and defined the
# red/green/yellow/blue helpers.
#
# The contract every artifact follows (see each assets/*/README.md):
# exactly one *.tar.xz per directory, a .sha256 beside it naming the bare
# file, and one top-level directory inside, which is what gets extracted
# and claimed with a THEME row. uninstall-theme.sh then rm -rf's exactly
# that directory.
#
# Split out of install-restore-cursor.sh when the font became the second
# vendored artifact (scope I, I-2b), so the two cannot drift apart.

# vendored_top_dir <tarball> — the archive's single top-level directory.
#
# NOT `tar -tJf ... | head -1`. head closing the pipe early SIGPIPEs tar, and
# under the pipefail every caller inherits, the pipeline reports 141 — a
# failure — even though the read succeeded. This repo has hit that exact trap
# three times; see manifest_has_path's header in global_fn.sh.
vendored_top_dir() {
    local tarball="$1" listing first
    listing="$(tar -tJf "$tarball")" || return 1
    first="${listing%%$'\n'*}"
    printf '%s\n' "${first%%/*}"
}

# vendored_verify_checksum <tarball> — checks it against <tarball>.sha256.
# Cheap, and it means a corrupted or swapped tarball fails loudly here instead
# of extracting something unexpected into the user's data directory.
vendored_verify_checksum() {
    local tarball="$1" sums="$1.sha256"
    [[ -f "$sums" ]] || return 0
    command -v sha256sum >/dev/null 2>&1 || return 0
    # Subshell cd: the .sha256 records a bare filename so `sha256sum -c` works
    # regardless of where the repo sits.
    (cd "$(dirname "$tarball")" && sha256sum -c --status "$(basename "$sums")")
}

# vendored_select_tarball <asset_dir> <what> — prints the single tarball's
# path, or returns non-zero after saying why there isn't one. Globbed, not
# named, so the artifact's name lives only in the committed file.
vendored_select_tarball() {
    local dir="$1" what="$2" tarballs=()
    shopt -s nullglob
    tarballs=("$dir"/*.tar.xz)
    shopt -u nullglob

    if [[ ${#tarballs[@]} -eq 0 ]]; then
        yellow "warn    no $what tarball in $dir — $what not deployed"
        return 1
    fi
    if [[ ${#tarballs[@]} -gt 1 ]]; then
        red "refusing to guess: ${#tarballs[@]} $what tarballs in $dir"
        yellow "        exactly one is supported — see that directory's README.md"
        return 1
    fi
    printf '%s\n' "${tarballs[0]}"
}

# vendored_extract <asset_dir> <dest_parent> <what> — extracts the asset's
# top-level directory into <dest_parent> and claims it with a THEME row.
# Never fatal to an install: every problem is reported and returns 0.
vendored_extract() {
    local dir="$1" parent="$2" what="$3" tarball name dst

    tarball="$(vendored_select_tarball "$dir" "$what")" || return 0
    if ! name="$(vendored_top_dir "$tarball")" || [[ -z "$name" ]]; then
        red "could not read the $what name out of $(basename "$tarball")"
        return 0
    fi
    dst="$parent/$name"

    if [[ ${DRY_RUN:-0} -eq 1 ]]; then
        blue "  (dry-run) would extract $name -> $dst"
        return 0
    fi

    if [[ -e "$dst" ]]; then
        if manifest_has_path THEME "$dst"; then
            green "ok      $name already deployed by us"
        else
            # A THEME row authorises uninstall to rm -rf this path, so never
            # claim a directory we did not create.
            green "ok      $dst exists (left untouched, not tracked for removal)"
        fi
        return 0
    fi

    if ! vendored_verify_checksum "$tarball"; then
        red "checksum mismatch on $(basename "$tarball") — refusing to extract"
        yellow "        re-fetch it; see $dir/README.md"
        return 0
    fi

    mkdir -p "$parent"
    # -J: these are .tar.xz (GNU tar runs the external xz, which desktop.lst
    # declares).
    if tar -xJf "$tarball" -C "$parent"; then
        manifest_append_row THEME theme "$dst"
        green "wrote   $dst"
    else
        red "failed to extract $(basename "$tarball")"
    fi
}
