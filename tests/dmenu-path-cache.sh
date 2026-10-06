#!/usr/bin/env bash
# dmenu_path's cache (suckless/dmenu/dmenu_path, pathcache-local patch).
#
# Upstream rebuilds ~/.cache/dmenu_run only when a PATH directory is NEWER than
# the cache, so a directory that joins PATH later — and is older than the cache
# — is never scanned. That hid every Flatpak app from Mod+p on the Fedora 44 VM
# (2026-10-06). The patch also rebuilds when $PATH differs from the PATH the
# cache was built for. Checked here, against the REAL stest compiled from the
# vendored stest.c (its mtime comparison is the whole point; a fake would only
# restate what this test expects):
#   * a first run lists what is on PATH and records that PATH;
#   * a directory joining PATH, older than the cache, is listed — and the
#     unpatched script (same file minus the new condition) misses it, so this
#     test can tell the two apart;
#   * an unchanged PATH with nothing newer is served from the cache;
#   * an install from before the patch (cache, no .path file) rebuilds once.
# Skipped, in yellow, where there is no C compiler.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

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

SRC="$DOTS_DIR/suckless/dmenu"
CC="$(type -P cc || type -P gcc || true)"
if [[ -z "$CC" ]]; then
    yellow "dmenu-path-cache: skip — no C compiler to build stest"
    exit 0
fi

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
BIN="$SB/bin"
seal_path "$BIN" sort tee cat mkdir
"$CC" -I"$SRC" -o "$BIN/stest" "$SRC/stest.c"
# The unpatched script: the shipped one minus the condition the patch added.
# shellcheck disable=SC2016 # a literal piece of the script being matched
sed 's/ || \[ "$(cat "$pathfile" 2>\/dev\/null)" != "$PATH" \]//' "$SRC/dmenu_path" >"$SB/dmenu_path.upstream"
if cmp -s "$SRC/dmenu_path" "$SB/dmenu_path.upstream"; then
    red "could not derive the unpatched dmenu_path — the patched condition moved; fix this test"
    exit 1
fi

# exe <dir> <name> <age> — an executable in a directory, both <age> old.
exe() {
    mkdir -p "$1"
    printf '#!/bin/sh\n' >"$1/$2"
    chmod 755 "$1/$2"
    touch -d "$3" "$1/$2" "$1"
}
# run <script> <PATH dirs...> — dmenu_path with only those dirs on PATH.
run() {
    local script="$1" p="$BIN"
    shift
    for d in "$@"; do p="$p:$d"; done
    env -i PATH="$p" XDG_CACHE_HOME="$SB/cache" "$(type -P sh)" "$script"
}

exe "$SB/old" aaa '2 hours ago'
out="$(run "$SRC/dmenu_path" "$SB/old")"
if grep -qx aaa <<<"$out" && [[ "$(cat "$SB/cache/dmenu_run.path")" == "$BIN:$SB/old" ]]; then
    ok "first run lists PATH and records the PATH it was built for"
else
    bad "first run: $out / $(cat "$SB/cache/dmenu_run.path" 2>&1)"
fi

# A directory older than the cache joins PATH — the VM's flatpak exports/bin.
exe "$SB/joined" org.example.App '3 hours ago'
cp -p "$SB/cache/dmenu_run" "$SB/cache.before"
cp -p "$SB/cache/dmenu_run.path" "$SB/path.before"
up="$(run "$SB/dmenu_path.upstream" "$SB/old" "$SB/joined")"
cp -p "$SB/cache.before" "$SB/cache/dmenu_run"
cp -p "$SB/path.before" "$SB/cache/dmenu_run.path"
out="$(run "$SRC/dmenu_path" "$SB/old" "$SB/joined")"
if grep -qx org.example.App <<<"$out" && ! grep -qx org.example.App <<<"$up"; then
    ok "a directory joining PATH, older than the cache, is listed (unpatched: missed)"
else
    bad "joined dir: patched=$(grep -c org.example.App <<<"$out") unpatched=$(grep -c org.example.App <<<"$up")"
fi

printf 'served-from-cache\n' >"$SB/cache/dmenu_run"
touch "$SB/cache/dmenu_run"
out="$(run "$SRC/dmenu_path" "$SB/old" "$SB/joined")"
if [[ "$out" == served-from-cache ]]; then
    ok "unchanged PATH, nothing newer: served from the cache"
else
    bad "expected the cache verbatim, got: $out"
fi

rm -f "$SB/cache/dmenu_run.path"
out="$(run "$SRC/dmenu_path" "$SB/old" "$SB/joined")"
if grep -qx org.example.App <<<"$out" && [[ -f "$SB/cache/dmenu_run.path" ]]; then
    ok "a pre-patch cache (no .path file) is rebuilt once"
else
    bad "pre-patch cache not rebuilt: $out"
fi

echo
if [[ $FAIL -eq 0 ]]; then
    green "dmenu-path-cache: $PASS passed"
else
    red "dmenu-path-cache: $FAIL failed, $PASS passed"
    exit 1
fi
