#!/usr/bin/env bash
# The ~/.fehbg that scripts/theme/wallpaper.sh writes must be /bin/sh syntax
# for ANY image path — reload.sh and the autorandr postswitch hook both run it.
#
# WHY. It used bash's `printf %q`, which for a control character (a tab, a
# newline) emits $'...' — bash syntax that dash rejects. The same bug was
# found by review in wallpaper-default.sh on 2026-10-05 and fixed there first.
# A picked wallpaper must also carry NO "# dots: generated wallpaper" marker,
# or the next static theme apply would regenerate over the user's choice.
#
# HOW. A sandbox COPY of scripts/ is run, with colorgen.sh, apply-templates.sh
# and reload.sh replaced by no-op fakes — the real ones pkill live daemons —
# and a fake feh first on PATH that records the path it is given. The image
# lives at a path containing a space, a quote, a dollar sign and a tab: the
# tab is what makes %q emit $'...', so without it a %q revert passes.

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
mkdir -p "$REPO" "$TMP/bin" "$TMP/home"
cp -r "$DOTS_DIR/scripts" "$REPO/"
for s in colorgen.sh apply-templates.sh reload.sh; do
    printf '#!/bin/sh\nexit 0\n' >"$REPO/scripts/theme/$s"
done
# The fakes' own $-expressions belong to them, not to this script.
# shellcheck disable=SC2016
printf '#!/bin/sh\nfor a; do last=$a; done\nprintf "%%s\\n" "$last" >>"%s"\n' "$TMP/feh.log" >"$TMP/bin/feh"
printf '#!/bin/sh\n:\n' >"$TMP/bin/notify-send"
chmod 755 "$TMP/bin"/*

TAB="$(printf '\t')"
IMG_DIR="$TMP/walls/it's a \$x${TAB}dir"
mkdir -p "$IMG_DIR"
IMG="$IMG_DIR/pic.png"
printf 'PNG' >"$IMG"

blue "==> wallpaper.sh on a path with a space, a quote, a dollar sign and a tab"
check "wallpaper.sh exits 0" env -i PATH="$TMP/bin:/usr/bin:/bin" HOME="$TMP/home" \
    XDG_CACHE_HOME="$TMP/home/.cache" XDG_CONFIG_HOME="$TMP/home/.config" \
    bash "$REPO/scripts/theme/wallpaper.sh" "$IMG"
FEHBG="$TMP/home/.fehbg"
check ".fehbg written and executable" test -x "$FEHBG"
check "no bash-only \$'...' quoting in .fehbg" fails grep -qF "\$'" "$FEHBG"
check "no generated-wallpaper marker (it is the user's choice)" \
    fails grep -qxF '# dots: generated wallpaper' "$FEHBG"

: >"$TMP/feh.log"
check ".fehbg runs under /bin/sh" env -i PATH="$TMP/bin" HOME="$TMP/home" /bin/sh "$FEHBG"
check "feh receives the exact path" grep -qxF "$IMG" "$TMP/feh.log"

if ((rc != 0)); then
    red "✗ wallpaper.sh .fehbg quoting"
    exit 1
fi
green "✓ wallpaper.sh .fehbg quoting"
