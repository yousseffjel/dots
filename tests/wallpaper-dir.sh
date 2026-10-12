#!/usr/bin/env bash
# Where scripts/theme/wallpaper.sh looks for wallpapers, and that it never
# fails silently. Super+w / Super+Shift+w run it through sxhkd, which discards
# stderr: on a fresh install with no ~/Pictures/wallpapers the keys did nothing
# visible (found on the Fedora VM, 2026-10-12).
#
# What is asserted:
#   * the default dir is wallpapers/ in the XDG pictures dir (`xdg-user-dir
#     PICTURES`, localised here as Bilder), and ~/Pictures when xdg-user-dir
#     answers $HOME (its answer for a dir it has no entry for);
#   * a missing default dir is created and seeded with the newest wallpaper
#     the theme engine generated, which --random then sets;
#   * a dir that already exists is never seeded;
#   * a missing DOTS_WALLPAPER_DIR is NOT created, and fails with a notification;
#   * a seeded-but-empty dir (nothing generated yet) and a missing feh both fail
#     with a notification, never silently.
#
# HOW. Same as tests/wallpaper-fehbg-quoting.sh: a sandbox COPY of scripts/
# (plus the dwm-lib-xdg.sh it sources) with colorgen.sh, apply-templates.sh
# and reload.sh replaced by no-op fakes — the real ones pkill live daemons —
# and fakes for feh, notify-send and xdg-user-dir first on PATH. HOME and all
# four XDG base dirs point into the sandbox.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

rc=0
check() {
    local name="$1"
    shift
    if "$@"; then
        green "  ok: $name"
    else
        red "  FAIL: $name"
        rc=1
    fi
}
fails() { ! "$@"; }

REPO="$TMP/repo"
H="$TMP/home"
mkdir -p "$REPO/config/dwm/bin" "$TMP/bin"
cp -r "$DOTS_DIR/scripts" "$REPO/"
cp "$DOTS_DIR/config/dwm/bin/dwm-lib-xdg.sh" "$REPO/config/dwm/bin/"
for s in colorgen.sh apply-templates.sh reload.sh; do
    printf '#!/bin/sh\nexit 0\n' >"$REPO/scripts/theme/$s"
done
# The fakes' own $-expressions belong to them, not to this script.
# shellcheck disable=SC2016
{
    printf '#!/bin/sh\nfor a; do last=$a; done\nprintf "%%s\\n" "$last" >>"%s"\n' "$TMP/feh.log" >"$TMP/bin/feh"
    printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s"\n' "$TMP/notify.log" >"$TMP/bin/notify-send"
    printf '#!/bin/sh\nprintf "%%s\\n" "${FAKE_XDG:-$HOME}"\n' >"$TMP/bin/xdg-user-dir"
}
chmod 755 "$TMP/bin"/*

# fresh — an empty sandbox HOME with one generated wallpaper in the cache.
fresh() {
    rm -rf "$H"
    mkdir -p "$H/.cache/dots/theme/wallpapers"
    printf 'PNG' >"$H/.cache/dots/theme/wallpapers/dark-generated.png"
    : >"$TMP/feh.log"
    : >"$TMP/notify.log"
}
# wall [VAR=val...] -- args — wallpaper.sh as a key runs it; sets RC.
wall() {
    local envs=()
    while [[ "$1" != -- ]]; do
        envs+=("$1")
        shift
    done
    shift
    RC=0
    env -i PATH="$TMP/bin:/usr/bin:/bin" HOME="$H" XDG_CACHE_HOME="$H/.cache" \
        XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" \
        XDG_STATE_HOME="$H/.local/state" "${envs[@]}" \
        bash "$REPO/scripts/theme/wallpaper.sh" "$@" >/dev/null 2>&1 || RC=$?
}
notified() { grep -qF -- "$1" "$TMP/notify.log"; }

blue "==> the default dir follows xdg-user-dir, and is created and seeded"
fresh
wall FAKE_XDG="$H/Bilder" -- --random
check "exit 0" test "$RC" -eq 0
check "created Bilder/wallpapers (the localised pictures dir)" test -d "$H/Bilder/wallpapers"
check "seeded with the generated wallpaper" test -f "$H/Bilder/wallpapers/dark-generated.png"
check "and --random set it" grep -qxF "$H/Bilder/wallpapers/dark-generated.png" "$TMP/feh.log"
check "nothing went to ~/Pictures" fails test -e "$H/Pictures"

fresh
wall -- --random
check "xdg-user-dir answering \$HOME means ~/Pictures/wallpapers" test -f "$H/Pictures/wallpapers/dark-generated.png"

blue "==> never seeds a dir that already exists"
fresh
mkdir -p "$H/Pictures/wallpapers"
printf 'PNG' >"$H/Pictures/wallpapers/mine.png"
wall -- --random
check "the user's own image is used" grep -qxF "$H/Pictures/wallpapers/mine.png" "$TMP/feh.log"
check "the generated one is not copied in" fails test -e "$H/Pictures/wallpapers/dark-generated.png"

blue "==> failures are notifications, never silent"
fresh
wall DOTS_WALLPAPER_DIR="$H/nope" -- --random
check "missing DOTS_WALLPAPER_DIR: exit 1" test "$RC" -eq 1
check "...with a notification naming it" notified "wallpaper directory not found: $H/nope"
check "...and the dir is NOT created" fails test -e "$H/nope"
fresh
rm -f "$H/.cache/dots/theme/wallpapers"/*.png
wall -- --random
check "nothing generated yet: the dir is created, empty, and that is a notification" notified "no images in $H/Pictures/wallpapers"
check "...exit 1" test "$RC" -eq 1
fresh
mv "$TMP/bin/feh" "$TMP/feh.off"
wall -- --random
mv "$TMP/feh.off" "$TMP/bin/feh"
if command -v feh >/dev/null 2>&1; then
    blue "  (a real feh is on this host's PATH — the missing-feh case cannot be isolated, skipped)"
else
    check "no feh: a notification" notified "feh not installed"
fi

if ((rc != 0)); then
    red "✗ wallpaper dir"
    exit 1
fi
green "✓ wallpaper dir: XDG path, seeding, and no silent failure"
