#!/usr/bin/env bash
# Exercises scripts/theme/ly-theme.sh against a copy of a REAL ly 1.4.0
# config.ini (tests/fixtures/ly-config-1.4.0.ini, taken from the Fedora 44 VM),
# never /etc/ly. HOME and all four XDG dirs are sandboxed, and sudo is a fake
# first on PATH, so nothing here can reach the host's config or manifest.
#
# What is asserted:
#   * a theme writes exactly four lines — fg and border_fg from the theme's own
#     palette (read from its colors.dcol, never restated here), bigclock = en,
#     hide_version_string = true — and leaves every other line alone;
#   * the original lines are saved once, and a later switch keeps them;
#   * the active theme (theme.set) is the default when none is named;
#   * a re-run writes nothing; --dry-run writes nothing;
#   * --restore puts the file back byte-identical and forgets the originals;
#   * with no terminal: `sudo -n` is used when allowed, and when it is refused
#     the file is untouched, the exit is 3 and `dots login-theme` is named;
#   * a key this ly lacks is reported and never appended;
#   * no config at all (ly not installed) is exit 0.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUT="$DOTS_DIR/scripts/theme/ly-theme.sh"
FIXTURE="$SCRIPT_DIR/fixtures/ly-config-1.4.0.ini"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

TMP="$(mktemp -d)"
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
H="$TMP/home"
CONF="$TMP/etc/ly/config.ini"
ORIG="$H/.local/state/dots/ly-config.orig"
LOG="$TMP/sudo.log"
export LOG

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}
has_line() { grep -qx -- "$2" "$1"; }
same() { [[ "$(<"$1")" == "$(<"$2")" ]]; }
palette() { sed -n "s/^dcol_$2=\"\([0-9A-F]*\)\"$/\1/p" "$DOTS_DIR/themes/$1/colors.dcol"; }
value() { sed -n "s/^$1 = 0x00\([0-9A-F]\{6\}\)$/\1/p" "$CONF"; }

# vt_colour <RRGGBB> — what a Linux VT draws: rgb_foreground() in the
# kernel's drivers/tty/vt/vt.c, restated here independently of the SUT so the
# test checks the screen, not the SUT's own table. Prints "<hue> <bright>":
# hue bits 4 red, 2 green, 1 blue (7 = white); bright 1 when max > 0xAA.
vt_colour() {
    local r=$((16#${1:0:2})) g=$((16#${1:2:2})) b=$((16#${1:4:2})) max hue=0
    max=$((r > g ? (r > b ? r : b) : (g > b ? g : b)))
    ((r > max / 2)) && hue=$((hue | 4))
    ((g > max / 2)) && hue=$((hue | 2))
    ((b > max / 2)) && hue=$((hue | 1))
    printf '%s %s\n' "$hue" "$((max > 0xAA ? 1 : 0))"
}
# hue_deg <RRGGBB> — the HSV hue in degrees, in awk (floating point), a
# different computation from the SUT's integer one.
hue_deg() {
    # Components converted by bash: strtonum is gawk-only, and CI's awk is mawk.
    awk -v r=$((16#${1:0:2})) -v g=$((16#${1:2:2})) -v b=$((16#${1:4:2})) 'BEGIN {
        mx = r; if (g > mx) mx = g; if (b > mx) mx = b
        mn = r; if (g < mn) mn = g; if (b < mn) mn = b
        d = mx - mn
        if (mx == r) x = 60 * (g - b) / d; else if (mx == g) x = 120 + 60 * (b - r) / d; else x = 240 + 60 * (r - g) / d
        printf "%d\n", (x + 360) % 360 }'
}
# drawn_in_family <theme> — border_fg is drawn bright, NOT white, and the hue
# the console draws is the one nearest the accent's (within 30 degrees).
drawn_in_family() {
    local accent shown hue bright drawn want dist
    local -A vt_deg=([4]=0 [6]=60 [2]=120 [3]=180 [1]=240 [5]=300)
    accent="$(palette "$1" 1xa7)"
    shown="$(value border_fg)"
    read -r hue bright < <(vt_colour "$shown")
    [[ -n "$shown" && $hue -ne 7 && $hue -ne 0 && $bright -eq 1 ]] || return 1
    drawn="${vt_deg[$hue]}"
    want="$(hue_deg "$accent")"
    dist=$(((drawn - want + 360) % 360))
    ((dist > 180)) && dist=$((360 - dist))
    ((dist <= 30))
}
# Lines that differ from the fixture, position by position.
changed() { awk 'NR==FNR { a[FNR] = $0; next } a[FNR] != $0' "$FIXTURE" "$CONF"; }
only_managed_changed() {
    [[ -n "$(changed)" ]] && ! changed | grep -qvE '^(fg|border_fg|bigclock|hide_version_string) = '
}

# A fake sudo that logs, answers `sudo -n true` with $SUDO_N_OK, and can
# write the read-only config the way root could.
mkdir -p "$TMP/fake"
# shellcheck disable=SC2016
fake "$TMP/fake" sudo '[[ "$1" == -n ]] && { shift; [[ "$1" == true ]] && exit "${SUDO_N_OK:-1}"; }
echo "sudo $*" >>"$LOG"; chmod u+w "${@: -1}"; "$@"'

# run [args] — the SUT in the sandbox, stdin NOT a terminal; RC holds its exit.
run() {
    RC=0
    OUT="$(env -i PATH="$TMP/fake:/usr/bin:/bin" HOME="$H" LOG="$LOG" \
        SUDO_N_OK="${SUDO_N_OK:-1}" DOTS_LY_CONFIG="$CONF" \
        XDG_CONFIG_HOME="$H/.config" XDG_STATE_HOME="$H/.local/state" \
        XDG_CACHE_HOME="$H/.cache" XDG_DATA_HOME="$H/.local/share" \
        bash "$SUT" "$@" </dev/null 2>&1)" || RC=$?
}
fresh() {
    rm -rf "${TMP:?}/etc" "$H" "$LOG"
    mkdir -p "$TMP/etc/ly" "$H"
    cp "$FIXTURE" "$CONF"
}

for key in fg border_fg bigclock hide_version_string; do
    check "the fixture has '$key' (every case below needs it)" grep -q "^$key = " "$FIXTURE"
done

blue "==> a theme: four lines, from its own palette"
fresh
run dark
check "exit 0" test "$RC" -eq 0
check "fg: dark's txt1 is drawn white, bright" test "$(vt_colour "$(value fg)")" = "7 1"
check "border_fg: dark's accent drawn bright, in its family, not white ($(value border_fg))" drawn_in_family dark
check "bigclock = en" has_line "$CONF" "bigclock = en"
check "hide_version_string = true" has_line "$CONF" "hide_version_string = true"
check "nothing else changed (fixture line count kept, only the 4 keys differ)" only_managed_changed
check "the originals were saved" has_line "$ORIG" "border_fg = 0x00FFFFFF"
check "...all four, even fg, which dark leaves as it was" test "$(wc -l <"$ORIG")" -eq 4
check "a LY manifest row claims the file" grep -qP "^LY\t\Q$CONF\E\t" "$H/.local/state/dots/manifest"
check "no sudo for a writable file" test ! -e "$LOG"

blue "==> every theme's border survives the console (the 2026-10-12 VM bug)"
for theme in "$DOTS_DIR"/themes/*/; do
    theme="$(basename "$theme")"
    run "$theme"
    raw="$(palette "$theme" 1xa7)"
    check "$theme: written as-is ($raw), the console would draw it white" \
        test "$(vt_colour "$raw" | cut -d' ' -f1)" -eq 7
    check "$theme: as written ($(value border_fg)) it is drawn in its own colour" drawn_in_family "$theme"
done
run dark

blue "==> a re-run writes nothing"
chmod a-w "$CONF"
run dark
check "exit 0, not 3 (it never tried to write)" test "$RC" -eq 0
check "says it is already themed" grep -q "already has theme dark" <<<"$OUT"

blue "==> a switch, by theme.set; originals kept"
chmod u+w "$CONF"
mkdir -p "$H/.cache/dots/theme"
echo nord >"$H/.cache/dots/theme/theme.set"
run
check "no argument: the active theme (nord)" grep -q "theme nord" <<<"$OUT"
check "the saved originals are still ly's own" has_line "$ORIG" "border_fg = 0x00FFFFFF"

blue "==> --dry-run"
cp "$CONF" "$TMP/before"
run --dry-run gruvbox
check "says it would write" grep -q "would write theme gruvbox" <<<"$OUT"
check "wrote nothing" same "$CONF" "$TMP/before"

blue "==> --restore"
run --restore
check "byte-identical to ly's file" same "$CONF" "$FIXTURE"
check "the originals are forgotten" test ! -e "$ORIG"
run --restore
check "a second restore has nothing to do" grep -q "nothing to restore" <<<"$OUT"

blue "==> no terminal, read-only file"
fresh
chmod a-w "$CONF"
if [[ $EUID -eq 0 ]]; then
    blue "  skip  root can write a read-only file; run as a user to cover this"
else
    run dark
    check "sudo -n refused: exit 3" test "$RC" -eq 3
    check "...the file is untouched" same "$CONF" "$FIXTURE"
    check "...and it says what to run" grep -q "dots login-theme dark" <<<"$OUT"
    check "...and saved no originals it never replaced" test ! -e "$ORIG"
    SUDO_N_OK=0 run dark
    check "sudo -n allowed: exit 0" test "$RC" -eq 0
    check "...written through sudo -n" grep -q "^sudo cp " "$LOG"
    check "...with the theme" has_line "$CONF" "bigclock = en"
fi

blue "==> a key this ly does not have"
fresh
sed -i '/^bigclock = /d' "$CONF"
run dark
check "reported" grep -q "skip    'bigclock'" <<<"$OUT"
check "never appended" test "$(grep -c '^bigclock = ' "$CONF")" -eq 0
check "the other three still written" has_line "$CONF" "hide_version_string = true"

blue "==> ly not installed"
rm -rf "${TMP:?}/etc"
run dark
check "exit 0" test "$RC" -eq 0
check "says so" grep -q "ly is not installed" <<<"$OUT"

blue "==> its three callers"
# Structural: running theme-apply.sh or the installer here would reach far
# beyond ly. The install-container CI job runs the services stage for real and
# asserts the themed /etc/ly/config.ini.
calls() { grep -qE "$2" "$DOTS_DIR/scripts/$1"; }
# shellcheck disable=SC2016 # the pattern matches a literal $SCRIPT_DIR
check "theme-apply.sh runs it on a static switch" calls theme/theme-apply.sh '"\$SCRIPT_DIR/ly-theme.sh" "\$THEME"'
check "the services stage runs it" calls install-services.sh 'scripts/theme/ly-theme.sh"'
order="$(grep -nE '^uninstall_(ly|packages)$' "$DOTS_DIR/scripts/uninstall.sh" | cut -d: -f2 | paste -sd' ' -)"
check "uninstall restores ly before removing packages ($order)" test "$order" = "uninstall_ly uninstall_packages"

if [[ $FAILS -gt 0 ]]; then
    red "✗ ly-theme: $FAILS check(s) failed"
    exit 1
fi
green "✓ ly-theme: four keys from the palette, originals restored, no prompt without a terminal"
