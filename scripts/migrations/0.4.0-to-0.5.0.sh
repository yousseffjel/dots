#!/usr/bin/env bash
# 0.4.0 -> 0.5.0: remove the nsxiv build 0.4.0 vendored, now that nsxiv is
# Void's package (packages/extra.lst, 2026-10-19).
#
# Run once by scripts/migrate.sh before the install stage. migrate.sh records
# the new version itself on success; this script edits only the manifest's
# SUCKLESS nsxiv rows, which describe the files it removes.
#
# WHY. 0.4.0 built nsxiv from suckless/nsxiv into /usr/local, which comes
# before /usr on PATH and in XDG_DATA_DIRS, so that copy would shadow the
# package forever. And `dots uninstall` removes a suckless program with
# `make uninstall` in its source dir, which 0.5.0 no longer ships.
#
# WHAT:
#   * only when the manifest has a `SUCKLESS nsxiv <prefix>/bin/nsxiv` row,
#     i.e. this installer put it there. The prefix comes from that row;
#   * the files the vendored `make uninstall` removed, nothing else: the
#     binary, its man page, its .desktop file, five hicolor icons and the
#     examples directory. sudo only when the prefix is not ours to write;
#   * the SUCKLESS nsxiv rows, then the build leftovers in this checkout's
#     suckless/nsxiv/ (git pull left them; .gitignore hides them). A
#     config.h you edited is KEPT, with the directory, and named.
# Idempotent: a re-run finds no rows and no directory, and says so.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../global_fn.sh
source "$SCRIPT_DIR/../global_fn.sh"
stop_on_interrupt

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

ICON_SIZES=(16x16 32x32 48x48 64x64 128x128)

# nsxiv_prefix — the prefix of the recorded binary, or nothing.
nsxiv_prefix() {
    local path
    path="$(manifest_rows SUCKLESS | awk -F'\t' '$2 == "nsxiv" && $3 ~ /\/bin\/nsxiv$/ { print $3; exit }')"
    [[ -n $path ]] && printf '%s\n' "${path%/bin/nsxiv}"
    return 0
}

# remove_build <prefix> — exactly the vendored Makefile's uninstall target.
remove_build() {
    local prefix="$1" size sudo=()
    [[ -w $prefix ]] || sudo=(sudo)
    local files=("$prefix/bin/nsxiv" "$prefix/share/man/man1/nsxiv.1"
        "$prefix/share/applications/nsxiv.desktop")
    for size in "${ICON_SIZES[@]}"; do
        files+=("$prefix/share/icons/hicolor/$size/apps/nsxiv.png")
    done
    if ! "${sudo[@]}" rm -f -- "${files[@]}" || ! "${sudo[@]}" rm -rf -- "$prefix/share/doc/nsxiv/examples"; then
        red "could not remove the old nsxiv build under $prefix (needs sudo)."
        red "Run the install again from a terminal: this step converges."
        exit 1
    fi
    "${sudo[@]}" rmdir -- "$prefix/share/doc/nsxiv" 2>/dev/null || true
    green "removed the nsxiv build 0.4.0 put in $prefix; the package's /usr/bin/nsxiv is the one now"
}

# drop_rows — every SUCKLESS nsxiv row, the other rows untouched.
drop_rows() {
    local tmp
    tmp="$(mktemp)"
    awk -F'\t' '!($1 == "SUCKLESS" && $2 == "nsxiv")' "$MANIFEST_FILE" >"$tmp"
    mv "$tmp" "$MANIFEST_FILE"
}

# clean_checkout — the untracked leftovers in suckless/nsxiv/, unless
# config.h was edited (it is unedited when it equals any committed
# config.def.h: the same test every build uses, install-suckless-headers.sh).
clean_checkout() {
    local dir="$DOTS_DIR/suckless/nsxiv"
    [[ -d $dir ]] || return 0
    if [[ -n "$(dots_git ls-files -- suckless/nsxiv)" ]]; then
        yellow "kept    suckless/nsxiv/ — it still has tracked files (an older checkout?)"
        return 0
    fi
    if [[ -f $dir/config.h ]] && ! dots_git rev-parse --is-inside-work-tree >/dev/null; then
        yellow "kept    suckless/nsxiv/ — no git history to tell whether you edited its config.h"
        return 0
    fi
    if [[ -f $dir/config.h ]] && ! file_matches_history "$dir/config.h" suckless/nsxiv/config.def.h; then
        yellow "kept    suckless/nsxiv/ — its config.h has your edits. The package uses the"
        yellow "        default config; delete the directory once you no longer need them."
        return 0
    fi
    rm -rf -- "$dir"
    green "removed suckless/nsxiv/ (build leftovers from the vendored copy)"
}

prefix="$(nsxiv_prefix)"
if [[ -n $prefix ]]; then
    remove_build "$prefix"
    drop_rows
else
    blue "no vendored nsxiv recorded in the manifest — nothing to remove"
fi
clean_checkout
green "0.4.0 -> 0.5.0: done"
