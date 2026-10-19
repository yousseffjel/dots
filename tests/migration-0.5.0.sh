#!/usr/bin/env bash
# Exercises scripts/migrations/0.4.0-to-0.5.0.sh — removing the nsxiv build
# 0.4.0 vendored into /usr/local — in a throwaway git repo and prefix, never
# this checkout or the real /usr/local.
#
# What is asserted:
#   * with a `SUCKLESS nsxiv <prefix>/bin/nsxiv` row: exactly the files the
#     vendored `make uninstall` removed are gone, a neighbour in the prefix
#     is kept, the nsxiv rows are dropped and every other row is kept;
#   * the checkout's untracked suckless/nsxiv/ leftovers are deleted when
#     config.h equals a committed config.def.h, and kept (with the reason)
#     when config.h was edited or the directory still has tracked files;
#   * no row, or a row that does not end in /bin/nsxiv: nothing is touched,
#     even with nsxiv files in the prefix (they are not ours);
#   * a re-run is a no-op;
#   * sudo only when the prefix is not writable, and a failed sudo fails the
#     step with the fix (a fake sudo first on PATH: never the real one).
#
# Sandboxed: all four XDG variables under a temp dir, `env -i`, minimal PATH.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

TMP="$(mktemp -d)"
trap 'chmod -R u+w "$TMP" 2>/dev/null || true; rm -rf "$TMP"' EXIT
R="$TMP/repo" P="$TMP/prefix" BIN="$TMP/bin"
MANIFEST="$TMP/state/dots/manifest"
mkdir -p "$R" "$BIN" "$TMP/state/dots"
printf '#!/bin/sh\necho "$@" >>"%s/sudo.log"\nexit 1\n' "$TMP" >"$BIN/sudo"
chmod +x "$BIN/sudo"

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}
g() { git -C "$R" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@" >/dev/null; }

# The repo: scripts/, and nsxiv's config.def.h committed, then deleted, as
# the real history has it.
cp -r "$DOTS_DIR/scripts" "$R/"
git init -q "$R"
mkdir -p "$R/suckless/nsxiv"
echo 'config v1' >"$R/suckless/nsxiv/config.def.h"
g add -A
g commit -m vendored
g rm -q suckless/nsxiv/config.def.h
g commit -m package

FILES=(bin/nsxiv share/man/man1/nsxiv.1 share/applications/nsxiv.desktop
    share/icons/hicolor/{16x16,32x32,48x48,64x64,128x128}/apps/nsxiv.png
    share/doc/nsxiv/examples/key-handler)
build() {
    local f
    for f in "${FILES[@]}" bin/dwm; do
        mkdir -p "$P/${f%/*}"
        : >"$P/$f"
    done
}
leftovers() {
    mkdir -p "$R/suckless/nsxiv"
    echo "${1:-config v1}" >"$R/suckless/nsxiv/config.h"
    : >"$R/suckless/nsxiv/nsxiv.o"
}
# Predicates below run only through check, which shellcheck cannot see.
# shellcheck disable=SC2329
none_left() {
    local f
    for f in "${FILES[@]}"; do [[ ! -e $P/$f ]] || return 1; done
    [[ ! -e $P/share/doc/nsxiv ]]
}
# shellcheck disable=SC2329
all_left() {
    local f
    for f in "${FILES[@]}"; do [[ -e $P/$f ]] || return 1; done
}
# shellcheck disable=SC2329
no_row() { ! grep -qP '^SUCKLESS\tnsxiv\t' "$MANIFEST"; }
# shellcheck disable=SC2329
untouched() { [[ $RC -eq 0 ]] && all_left; }
rows() { printf 'META\tversion\t0.4.0\nSUCKLESS\tdwm\t%s/bin/dwm\nSUCKLESS\tnsxiv\t%s\nPACKAGE\tgit\n' "$P" "$1" >"$MANIFEST"; }
migrate() {
    RC=0
    OUT="$(env -i PATH="$BIN:/usr/bin:/bin" HOME="$TMP/home" XDG_STATE_HOME="$TMP/state" \
        XDG_CONFIG_HOME="$TMP/config" XDG_DATA_HOME="$TMP/data" XDG_CACHE_HOME="$TMP/cache" \
        bash "$R/scripts/migrations/0.4.0-to-0.5.0.sh" 2>&1)" || RC=$?
}

blue "==> the recorded build and the leftovers"
build
leftovers
rows "$P/bin/nsxiv"
migrate
check "exits 0" test "$RC" -eq 0
check "every file make uninstall named is gone" none_left
check "a neighbour in the prefix is kept" test -e "$P/bin/dwm"
check "no nsxiv row is left" no_row
check "the other rows are kept" test "$(grep -cP '^(META|SUCKLESS\tdwm|PACKAGE)\t' "$MANIFEST")" -eq 3
check "the unedited leftovers are deleted" test ! -e "$R/suckless/nsxiv"
check "sudo was not needed" test ! -e "$TMP/sudo.log"

blue "==> a re-run"
migrate
check "exits 0 and says there is nothing to remove" grep -q 'nothing to remove' <<<"$OUT"
check "...and changed nothing" test "$RC:$(grep -c . "$MANIFEST")" = "0:3"

blue "==> an edited config.h"
leftovers 'config mine'
migrate
check "the directory is kept" test -f "$R/suckless/nsxiv/config.h"
check "...and the user is told why" grep -q 'has your edits' <<<"$OUT"
rm -rf "${R:?}/suckless/nsxiv"

blue "==> tracked files in suckless/nsxiv (an older checkout)"
mkdir -p "$R/suckless/nsxiv"
echo tracked >"$R/suckless/nsxiv/Makefile"
g add suckless/nsxiv/Makefile
migrate
check "the directory is kept" test -f "$R/suckless/nsxiv/Makefile"
g rm -rqf suckless/nsxiv

blue "==> nsxiv files nobody recorded"
build
for row in "" "$P/lib/nsxiv"; do
    if [[ -z $row ]]; then
        printf 'META\tversion\t0.4.0\n' >"$MANIFEST"
    else
        rows "$row"
    fi
    migrate
    check "row '${row:-none}': exits 0, every file kept" untouched
done

blue "==> a prefix only root can write"
rows "$P/bin/nsxiv"
chmod a-w "$P"
migrate
chmod u+w "$P"
check "sudo is used" grep -q '^rm -f -- ' "$TMP/sudo.log"
check "a failed sudo fails the step" test "$RC" -ne 0
check "...naming the fix" grep -q 'converges' <<<"$OUT"
check "...and keeps the rows for the re-run" grep -qP "^SUCKLESS\tnsxiv\t" "$MANIFEST"

if [[ $FAILS -eq 0 ]]; then
    green "✓ migration 0.4.0 -> 0.5.0: only the recorded nsxiv build is removed"
else
    red "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
