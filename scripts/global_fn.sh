#!/usr/bin/env bash
# Shared helpers for the versioning/uninstall/migration tooling
# (version.sh, uninstall.sh, migrate.sh, migrations/*.sh) plus the manifest
# writers wired into the install-*.sh stages. Source this AFTER the caller
# has already run `set -euo pipefail` and resolved its own SCRIPT_DIR/
# DOTS_DIR — this file does not set shell options or paths itself.
#
# The install-*.sh stage scripts keep their own pre-existing inline
# red()/green()/yellow()/blue() definitions untouched (this repo's
# convention); they additionally source this file only for confirm(),
# refuse_root(), and the manifest_* functions below.
#
# usage (from a script that has already resolved SCRIPT_DIR):
#   source "$SCRIPT_DIR/global_fn.sh"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# ~/.local/state/dots/manifest — a single tab-separated file, one row per
# line, first field is the row type (META/CONFIG/SUCKLESS/PACKAGE/SERVICE).
# Plain sed/awk/grep-parseable by design — no jq or other new dependency.
MANIFEST_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dots"
MANIFEST_FILE="$MANIFEST_DIR/manifest"

# Prompts "$1 [y/N]" and returns 0 (yes) / 1 (no). ASSUME_YES=1 (set by a
# caller's --yes flag) auto-confirms without prompting.
confirm() {
    local prompt="$1"
    if [[ "${ASSUME_YES:-0}" -eq 1 ]]; then
        blue "  (auto-yes) $prompt"
        return 0
    fi
    local reply=""
    read -r -p "$prompt [y/N] " reply || true
    [[ "$reply" =~ ^[Yy]$ ]]
}

# Hard-stops scripts that manage a per-user install/uninstall — running as
# root would write state under the wrong $HOME and silently corrupt it.
refuse_root() {
    if [[ $EUID -eq 0 ]]; then
        red "refusing to run as root — this manages a per-user dotfiles install."
        exit 1
    fi
}

# --- manifest: meta (version/commit/date) -----------------------------------

# Replaces any existing META row for $1 with $1=$2 (idempotent — safe to
# call on every install run, not just the first).
manifest_set_meta() {
    local key="$1" value="$2"
    mkdir -p "$MANIFEST_DIR"
    touch "$MANIFEST_FILE"
    local tmp
    tmp="$(mktemp)"
    awk -F'\t' -v k="$key" 'BEGIN{OFS="\t"} !($1=="META" && $2==k)' "$MANIFEST_FILE" >"$tmp"
    printf 'META\t%s\t%s\n' "$key" "$value" >>"$tmp"
    mv "$tmp" "$MANIFEST_FILE"
}

manifest_get_meta() {
    local key="$1"
    [[ -f "$MANIFEST_FILE" ]] || return 0
    awk -F'\t' -v k="$key" '$1=="META" && $2==k {v=$3} END{if (v!="") print v}' "$MANIFEST_FILE"
}

# Call once near the start of an install run: stamps version/commit/date.
manifest_init() {
    local version="$1" commit="$2"
    mkdir -p "$MANIFEST_DIR"
    touch "$MANIFEST_FILE"
    manifest_set_meta version "$version"
    manifest_set_meta commit "$commit"
    manifest_set_meta date "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

# --- manifest: category rows (CONFIG/SUCKLESS/PACKAGE/SERVICE) --------------

# Appends "$category<TAB>$2<TAB>$3..." unless that exact row already exists
# (idempotent — re-running an install stage never duplicates a row).
manifest_append_row() {
    local category="$1"
    shift
    local line
    line="$(printf '%s\t' "$category" "$@")"
    line="${line%$'\t'}"
    mkdir -p "$MANIFEST_DIR"
    touch "$MANIFEST_FILE"
    if ! grep -qxF "$line" "$MANIFEST_FILE"; then
        printf '%s\n' "$line" >>"$MANIFEST_FILE"
    fi
}

# Like manifest_append_row, but for a row whose last field can change
# between runs (CONFIG's backup path: a real path the first time a
# conflicting file gets backed up, "-" on every idempotent re-run after
# that) — replaces any existing row sharing the same category + first two
# fields instead of appending a second, stale copy that plain exact-line
# dedup can't catch.
manifest_upsert_row() {
    local category="$1" key1="$2" key2="$3" value="$4"
    mkdir -p "$MANIFEST_DIR"
    touch "$MANIFEST_FILE"
    local tmp
    tmp="$(mktemp)"
    awk -F'\t' -v c="$category" -v k1="$key1" -v k2="$key2" \
        '!($1==c && $2==k1 && $3==k2)' "$MANIFEST_FILE" >"$tmp"
    printf '%s\t%s\t%s\t%s\n' "$category" "$key1" "$key2" "$value" >>"$tmp"
    mv "$tmp" "$MANIFEST_FILE"
}

# Prints every row of $1 (tab-separated, category column included).
manifest_rows() {
    local category="$1"
    [[ -f "$MANIFEST_FILE" ]] || return 0
    awk -F'\t' -v c="$category" '$1==c' "$MANIFEST_FILE"
}

# True when $2 appears as the path field (field 3) of any $1 row.
#
# The callers use this to answer "did WE create this file?" — the rule being
# that only files an installer actually creates get a manifest row, because
# uninstall deletes every row of a category outright. Registering a
# pre-existing file we deliberately left untouched would turn "we did not
# clobber your config" into "we deleted your config on uninstall". A stray
# file left behind is recoverable; someone else's config removed is not.
#
# Written as a read loop rather than `manifest_rows "$1" | cut -f3 |
# grep -qxF "$2"`, and that is not a style preference. `grep -q` exits on its
# first match, which SIGPIPEs `cut`; under the `set -o pipefail` every caller
# inherits, the pipeline then reports 141 — a FAILURE — even though the path
# was found. The caller reads "not ours" and does the destructive thing.
# (`|| true` is not the fix: it maps 141 to 0, which is the opposite wrong
# answer — every path becomes "ours", including the user's own files.)
# Nothing here inspects the producer's exit status, so the early `return 0`
# cannot trip an ERR trap. See tests/manifest-has-path.sh, which reproduces
# the broken shape, and `comm | head` at install-restore.sh:72 for the third
# instance of the same trap.
manifest_has_path() {
    local category="$1" target="$2" row
    while IFS= read -r row; do
        [[ "$row" == "$target" ]] && return 0
    done < <(manifest_rows "$category" 2>/dev/null | cut -f3)
    return 1
}
