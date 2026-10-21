#!/usr/bin/env bash
# `dots uninstall --dry-run` previews every category and changes nothing,
# with no terminal to answer its prompts; and an interactive uninstall that
# removes the state dir but keeps no copy of its log still exits 0.
#
# WHY. Both found on the Void VM, 2026-10-20. Each category asked its y/N
# prompt before looking at DRY_RUN, so a dry run without a terminal (or
# answered N) printed "skipped …" everywhere and previewed nothing, though
# docs/UNINSTALL.md promises "preview every action". And uninstall_state ended
# on `[[ -n "$keep_path" ]] && echo`, false when no copy was kept, so the
# function returned 1 and set -e stopped the script before
# "✓ uninstall complete". tests/install-uninstall-symmetry.sh runs --yes,
# which always keeps the copy, so it could not see either.
#
# HOW. tests/lib/install-symmetry.sh's sandbox: the real restore stage into an
# empty HOME, then the real uninstall.sh --dry-run with stdin from /dev/null.
# HOME is compared file for file; the sudo/xbps/usermod/pkill sentinels must
# stay silent; the fake dconf and flatpak stores must not move.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/install-symmetry.sh
source "$SCRIPT_DIR/lib/install-symmetry.sh"

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

TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
make_fakes
HOME_SB="$TMP/home"
mkdir -p "$HOME_SB"

blue "==> restore, then uninstall --dry-run with no terminal"
if ! in_sandbox "$HOME_SB" "$DOTS_DIR/scripts/install-restore.sh" >"$TMP/restore.log" 2>&1; then
    red "restore failed:"
    tail -15 "$TMP/restore.log"
    exit 1
fi
snapshot "$HOME_SB" >"$TMP/before"
cp "$DCONF_STORE" "$TMP/dconf.before"
cp "$FLATPAK_STATE/remotes" "$TMP/remotes.before"
: >"$SENTINEL_LOG"
RC=0
in_sandbox "$HOME_SB" "$DOTS_DIR/scripts/uninstall.sh" --dry-run </dev/null >"$TMP/dry.log" 2>&1 || RC=$?
OUT="$(sed 's/\x1b\[[0-9;]*m//g' "$TMP/dry.log")"
check "exit 0" test "$RC" -eq 0
check "reaches its last line" grep -q 'uninstall complete' <<<"$OUT"
check "HOME is byte-identical" cmp -s "$TMP/before" <(snapshot "$HOME_SB")
check "no sudo/xbps/usermod/pkill call" test ! -s "$SENTINEL_LOG"
check "dconf untouched" cmp -s "$TMP/dconf.before" "$DCONF_STORE"
check "flatpak remotes untouched" cmp -s "$TMP/remotes.before" "$FLATPAK_STATE/remotes"
check "previews what it would remove" grep -q '(dry-run) would remove' <<<"$OUT"
# Every category the restore claimed is previewed, none passed over.
no_skips() { ! grep -E '^ +(skipped|kept) ' <<<"$1"; }
check "no category skipped or kept for want of an answer" no_skips "$OUT"

blue "==> remove the state dir, keep no copy of the log"
STATE="$TMP/state-only/.local/state"
mkdir -p "$STATE/dots"
: >"$STATE/dots/manifest"
# The real global_fn.sh and uninstall_steps.sh; confirm() answers as a user
# would at a terminal: yes to removing the state dir, no to keeping the log.
# shellcheck disable=SC2016 # expands in the inner bash
OUT="$(env -i PATH="$PATH" HOME="$TMP/state-only" XDG_STATE_HOME="$STATE" bash -c '
    set -euo pipefail
    source "$1/scripts/global_fn.sh"
    source "$1/scripts/uninstall_steps.sh"
    confirm() { [[ "$1" == Remove* ]]; }
    DRY_RUN=0 ASSUME_YES=0 LOG_FILE="$MANIFEST_DIR/uninstall.log"
    : >"$LOG_FILE"
    uninstall_state
    echo REACHED
' _ "$DOTS_DIR" 2>&1 || true)"
check "uninstall_state returns 0 when no copy is kept" grep -q REACHED <<<"$OUT"
check "...and the state dir is gone" test ! -e "$STATE/dots"

if ((rc != 0)); then
    red "✗ uninstall dry run"
    exit 1
fi
green "✓ uninstall dry run: every category previewed, nothing changed"
