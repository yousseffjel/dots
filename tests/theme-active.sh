#!/usr/bin/env bash
# A re-run of the restore stage re-applies the theme in use, not `dark`.
#
# WHY. theme_initial_apply runs on every restore with a DISPLAY, and
# `dots update` from a session terminal is one. It used to apply `dark` every
# time, which threw away a wallpaper-derived palette or a static theme the user
# had switched to (the Fedora VM, 2026-10-13).
#
# HOW. theme_active (scripts/install-restore-theme-active.sh) is run against a
# sandbox theme cache whose theme.set / wall.set mtimes are set with touch -d.
# Then theme_initial_apply itself runs against a fake DOTS_DIR whose
# theme-apply.sh only records its argument — nothing reaches the real engine,
# whose post-commands act on the live desktop.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

rc=0
expect() {
    if [[ "$2" == "$3" ]]; then
        green "  ok: $1"
    else
        red "  FAIL: $1 — expected '$2', got '$3'"
        rc=1
    fi
}

TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
export XDG_CACHE_HOME="$TMP/cache"
CACHE="$XDG_CACHE_HOME/dots/theme"
IMG="$TMP/wall.png"
DOTS_DIR="$REPO"
# shellcheck source=../scripts/install-restore-theme-active.sh
source "$REPO/scripts/install-restore-theme-active.sh"

# <theme.set content|-> <its mtime> <wall.set content|-> <its mtime>
cache() {
    rm -rf "$CACHE"
    mkdir -p "$CACHE"
    if [[ "$1" != - ]]; then
        printf '%s\n' "$1" >"$CACHE/theme.set"
        touch -d "$2" "$CACHE/theme.set"
    fi
    if [[ "$3" != - ]]; then
        printf '%s\n' "$3" >"$CACHE/wall.set"
        touch -d "$4" "$CACHE/wall.set"
    fi
}
: >"$IMG"

blue "==> theme_active"
cache - '' - ''
expect "nothing applied yet: dark" dark "$(theme_active)"
cache nord '2026-10-01 10:00' - ''
expect "a static theme only: that theme" nord "$(theme_active)"
cache nord '2026-10-01 10:00' "$IMG" '2026-10-02 10:00'
expect "a wallpaper chosen after it: --wallbash" --wallbash "$(theme_active)"
cache nord '2026-10-03 10:00' "$IMG" '2026-10-02 10:00'
expect "a static theme chosen after the wallpaper: that theme" nord "$(theme_active)"
cache nord '2026-10-02 10:00' "$IMG" '2026-10-02 10:00'
expect "a tie counts as static" nord "$(theme_active)"
cache - '' "$IMG" '2026-10-02 10:00'
expect "a wallpaper and no theme.set: --wallbash" --wallbash "$(theme_active)"
cache nord '2026-10-01 10:00' "$TMP/deleted.png" '2026-10-02 10:00'
expect "the wallpaper was deleted since: falls back to theme.set" nord "$(theme_active)"
cache no-such-theme '2026-10-01 10:00' - ''
expect "theme.set names a theme no longer shipped: dark" dark "$(theme_active)"

blue "==> theme_initial_apply passes it on"
FAKE="$TMP/fake"
mkdir -p "$FAKE/scripts/theme" "$FAKE/themes/dark" "$FAKE/themes/nord"
: >"$FAKE/themes/dark/colors.dcol"
: >"$FAKE/themes/nord/colors.dcol"
# shellcheck disable=SC2016 # expands when the fake runs
printf '#!/bin/sh\necho "$*" >>"%s"\n' "$TMP/applied" >"$FAKE/scripts/theme/theme-apply.sh"
chmod 755 "$FAKE/scripts/theme/theme-apply.sh"
# install-restore-theme.sh only defines functions (it locates its siblings
# itself), so sourcing it runs nothing.
# shellcheck source=../scripts/install-restore-theme.sh
source "$REPO/scripts/install-restore-theme.sh"
DOTS_DIR="$FAKE"
DRY_RUN=0
cache nord '2026-10-01 10:00' "$IMG" '2026-10-02 10:00'
DISPLAY=:99 theme_initial_apply >/dev/null
cache nord '2026-10-03 10:00' "$IMG" '2026-10-02 10:00'
DISPLAY=:99 theme_initial_apply >/dev/null
expect "re-runs apply --wallbash, then the static theme — never a hard-coded dark" \
    "--wallbash nord" "$(tr '\n' ' ' <"$TMP/applied" | sed 's/ $//')"

blue "==> theme-apply.sh leaves the record theme_active reads"
# The real theme-apply.sh in a copy of the repo whose engine steps are stubs
# (their post-commands act on the live desktop), with every XDG directory,
# HOME and ly's config sandboxed, and no display or session bus.
COPY="$TMP/repo"
mkdir -p "$COPY" "$TMP/home"
cp -r "$REPO/scripts" "$REPO/themes" "$COPY/"
for stub in colorgen.sh apply-templates.sh reload.sh wallpaper-default.sh ly-theme.sh; do
    printf '#!/bin/sh\nexit 0\n' >"$COPY/scripts/theme/$stub"
done
apply() {
    env -u DISPLAY -u DBUS_SESSION_BUS_ADDRESS -u WAYLAND_DISPLAY HOME="$TMP/home" \
        XDG_CONFIG_HOME="$TMP/home/.config" XDG_STATE_HOME="$TMP/home/.local/state" \
        XDG_DATA_HOME="$TMP/home/.local/share" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
        DOTS_LY_CONFIG="$TMP/no-ly/config.ini" \
        bash "$COPY/scripts/theme/theme-apply.sh" "$@" >/dev/null 2>&1
}
DOTS_DIR="$COPY"
cache - '' "$IMG" '2026-10-01 10:00'
apply nord
touch -d '2026-10-02 10:00' "$CACHE/theme.set" # an earlier switch, not this second
apply --wallbash
expect "--wallbash after a static theme: a re-run keeps --wallbash (Void VM)" --wallbash "$(theme_active)"
apply nord
expect "...and a static theme after it wins again" nord "$(theme_active)"

if ((rc != 0)); then
    red "✗ theme re-apply"
    exit 1
fi
green "✓ theme re-apply: a re-run keeps the active theme"
