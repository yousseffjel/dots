#!/usr/bin/env bash
# Generated-header refresh, run before every suckless build.
#
# Sourced by install-suckless.sh only, never standalone: it assumes the caller
# has `set -euo pipefail`, DOTS_DIR, DRY_RUN and the red/green/yellow/blue
# helpers.
#
# usage: source "$SCRIPT_DIR/install-suckless-headers.sh"
#        refresh_generated_headers <suckless program dir>
#
# WHY. Each suckless Makefile copies <name>.def.h to its generated header
# (config.h, dwmblocks' blocks.h) only when the header is absent, so an
# install kept its first copy forever and a later *.def.h change — dwm's
# MODKEY moving to Super, 2026-10-12 — never reached it. The 0.1.0 -> 0.2.0
# migration fixed that once; this does it on every build, so the next
# *.def.h change needs no release.
#
# WHAT, per generated header — the rule of scope G decision 1, unchanged:
#   * absent, or equal to its *.def.h        -> nothing to do;
#   * equal to SOME past committed *.def.h   -> never edited: moved to
#     <name>.pre-<timestamp>, so this build regenerates it;
#   * anything else -> you edited it: KEPT, with the command that shows what
#     to merge. Printed on every build until the two agree;
#   * no git repository to compare with      -> kept, and said so.
# Never deletes; the one write is a rename, and never over an existing file.

# headers_git <args> — git against the repo, quiet.
headers_git() { git -C "$DOTS_DIR" "$@" 2>/dev/null; }

# header_matches_history <generated> <def, repo-relative> — true when the
# generated header equals the *.def.h of any commit that touched it. Compared
# by blob id, so nothing beyond git (core.lst) is needed.
header_matches_history() {
    local want commit
    want="$(headers_git hash-object -- "$1")" || return 1
    while read -r commit; do
        [[ "$(headers_git rev-parse -q --verify "$commit:$2")" == "$want" ]] && return 0
    done < <(headers_git log --format=%H -- "$2")
    return 1
}

# refresh_one_header <generated> <def path>
refresh_one_header() {
    local gen="$1" def_path="$2" def rel backup
    def="${def_path#"$DOTS_DIR"/}"
    rel="${gen#"$DOTS_DIR"/}"
    if [[ "$(<"$gen")" == "$(<"$def_path")" ]]; then
        return 0
    elif ! headers_git rev-parse --is-inside-work-tree >/dev/null; then
        yellow "kept    $rel differs from $def, and there is no git history to tell"
        yellow "        whether you edited it. To take the defaults: rm it and rebuild."
    elif header_matches_history "$gen" "$def"; then
        backup="$gen.pre-$(date +%Y%m%d-%H%M%S)"
        if [[ $DRY_RUN -eq 1 ]]; then
            blue "  (dry-run) would refresh $rel (unedited, older than $def)"
            return 0
        fi
        if [[ -e "$backup" ]]; then
            red "cannot refresh $rel: $backup already exists — move it aside"
            exit 1
        fi
        mv "$gen" "$backup"
        green "refresh $rel (unedited, older than $def) — old copy: ${backup#"$DOTS_DIR"/}"
    else
        yellow "kept    $rel — you edited it, so it was not regenerated from $def."
        yellow "        To see what changed upstream:  diff -u $gen $def_path"
    fi
}

refresh_generated_headers() {
    local def_path gen
    for def_path in "$1"/*.def.h; do
        [[ -f "$def_path" ]] || continue
        gen="${def_path%.def.h}.h"
        [[ -f "$gen" ]] || continue
        refresh_one_header "$gen" "$def_path"
    done
}
