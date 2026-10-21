#!/usr/bin/env bash
# dwm-display (Super+Shift+d) against a faked xrandr, autorandr and dmenu:
# which modes and which primary its presets use, and its "save this layout"
# entry. Sibling of tests/dwm-display.sh, split at the 250-line cap; the
# harness is duplicated on purpose (CLAUDE.md rule 2).
#
# WHY. On two screens (the Void VM laid out like a 2x1080p desk, 2026-10-21)
# "extend" ran `--auto` on the screen that was already on, resetting it to
# its preferred mode — 1920x1080 became 850x1001, twice — and on real
# hardware the same flag undoes a mode the user chose (a refresh rate that is
# not the preferred one). It also took the first connected output as the
# primary, moving the primary flag off the one xrandr says is primary.
#
# What is asserted:
#   * an output already on keeps its mode: no --auto for it in any preset;
#   * an output that is off gets --auto, so it comes on at all;
#   * the primary is the output xrandr marks primary, else the first;
#   * "save this layout as a profile" is offered only with autorandr, saves
#     a new name, asks before overwriting, and refuses a name autorandr would
#     treat as a path; Escape at any prompt saves nothing.
#
# SAFETY: everything on a sealed PATH of fakes — a real xrandr would rearrange
# the tester's displays and a real dmenu would wait forever.
# shellcheck disable=SC2016 # the bash -c bodies take $1.. as their own arguments
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

DISPLAY_SH="$DOTS_DIR/config/dwm/bin/dwm-display"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home"
seal_path "$TMP/bin" bash awk grep cat sed head tail rm
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

# fake xrandr: no arguments prints $TMP/screens; anything else is logged.
cat >"$TMP/bin/xrandr" <<EOF
#!/bin/sh
if [ \$# -eq 0 ]; then cat "$TMP/screens"; exit 0; fi
printf 'xrandr %s\n' "\$*" >>"$TMP/applied.log"
EOF
# fake autorandr: --list prints $TMP/profiles, the rest is logged.
cat >"$TMP/bin/autorandr" <<EOF
#!/bin/sh
if [ "\$1" = --list ]; then cat "$TMP/profiles"; exit 0; fi
printf 'autorandr %s\n' "\$*" >>"$TMP/applied.log"
EOF
# fake dmenu: answers with the next line of $TMP/answers (none = Escape) and
# records its prompt (-p) in $TMP/prompts.
cat >"$TMP/bin/dmenu" <<EOF
#!/bin/sh
cat >/dev/null
while [ \$# -gt 0 ]; do [ "\$1" = -p ] && printf '%s\n' "\$2" >>"$TMP/prompts"; shift; done
[ -s "$TMP/answers" ] || exit 1
head -n1 "$TMP/answers"
tail -n +2 "$TMP/answers" >"$TMP/answers.rest"; cat "$TMP/answers.rest" >"$TMP/answers"
EOF
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s/notify.log"\n' "$TMP" >"$TMP/bin/notify-send"
chmod 755 "$TMP/bin"/{xrandr,autorandr,dmenu,notify-send}
: >"$TMP/profiles"

screens() { printf '%s\n' "$@" >"$TMP/screens"; }
menu() { HOME="$TMP/home" PATH="$TMP/bin" bash "$DISPLAY_SH" --list; }
cmd_of() { menu | awk -F'\t' -v e="$1" '$1 == e { print $2 }'; }
# run <answers...> — the menu as a key press would, answering each prompt.
run() {
    printf '%s\n' "$@" >"$TMP/answers"
    [[ $# -gt 0 ]] || : >"$TMP/answers"
    : >"$TMP/applied.log"
    : >"$TMP/prompts"
    RC=0
    HOME="$TMP/home" PATH="$TMP/bin" bash "$DISPLAY_SH" >/dev/null 2>&1 || RC=$?
}

blue "==> one screen on, one plugged in but off"
screens 'Screen 0: minimum 320 x 200, current 1920 x 1080, maximum 16384 x 16384' \
    'eDP-1 connected primary 1920x1080+0+0 (normal left inverted right) 344mm x 194mm' \
    'HDMI-1 connected (normal left inverted right x axis y axis)' \
    'DP-2 disconnected (normal left inverted right)'
ext="$(cmd_of 'extend HDMI-1 right of eDP-1')"
check "extend keeps eDP-1's mode (no --auto for it)" \
    test "$ext" == "xrandr --output eDP-1 --primary --output HDMI-1 --auto --right-of eDP-1"
check "only HDMI-1 switches it on with --auto" \
    test "$(cmd_of 'only HDMI-1')" == "xrandr --output HDMI-1 --auto --primary --output eDP-1 --off"
check "only eDP-1 keeps its mode" \
    test "$(cmd_of 'only eDP-1')" == "xrandr --output eDP-1 --primary --output HDMI-1 --off"
check "all on: --auto only for the one that is off" \
    test "$(cmd_of 'all on')" == "xrandr --output eDP-1 --output HDMI-1 --auto"

blue "==> both on, the second one primary"
screens 'eDP-1 connected 1920x1080+0+0 (normal left inverted right) 344mm x 194mm' \
    'HDMI-1 connected primary 2560x1440+1920+0 (normal left inverted right) 600mm x 340mm'
labels="$(menu | cut -f1)"
check "presets are built around the real primary, HDMI-1" \
    grep -qxF 'extend eDP-1 right of HDMI-1' <<<"$labels"
check "...not around the first output" bash -c '! grep -q "of eDP-1$" <<<"$1"' _ "$labels"
check "mirror keeps both modes" \
    test "$(cmd_of 'mirror eDP-1 onto HDMI-1')" == "xrandr --output HDMI-1 --primary --output eDP-1 --same-as HDMI-1"
check "no preset resets an output that is on" bash -c '! grep -q -- --auto <<<"$1"' _ "$(menu | cut -f2)"

blue "==> save this layout as a profile"
SAVE='save this layout as a profile'
rm "$TMP/bin/autorandr"
check "not offered without autorandr" bash -c '! grep -qxF "$1" <<<"$2"' _ "$SAVE" "$(menu | cut -f1)"
cat >"$TMP/bin/autorandr" <<EOF
#!/bin/sh
if [ "\$1" = --list ]; then cat "$TMP/profiles"; exit 0; fi
printf 'autorandr %s\n' "\$*" >>"$TMP/applied.log"
EOF
chmod 755 "$TMP/bin/autorandr"
printf 'docked\n' >"$TMP/profiles"
check "offered with autorandr, after the presets" test "$(menu | cut -f1 | tail -1)" == "$SAVE"
run "$SAVE" desk
check "a new name is saved" test "$(cat "$TMP/applied.log")" == "autorandr --save desk"
check "...and asked for by name" grep -q 'name' "$TMP/prompts"
check "...and announced" grep -q 'desk' "$TMP/notify.log"
run "$SAVE" docked no
check "an existing name asks first; 'no' saves nothing" \
    bash -c '[[ ! -s $1 ]] && grep -q overwrite "$2"' _ "$TMP/applied.log" "$TMP/prompts"
run "$SAVE" docked yes
check "...'yes' overwrites it" test "$(cat "$TMP/applied.log")" == "autorandr --save docked --force"
for bad in '../x' 'a b' '-x'; do
    run "$SAVE" "$bad"
    check "refuses the name '$bad'" bash -c '[[ $1 -ne 0 && ! -s $2 ]]' _ "$RC" "$TMP/applied.log"
done
run "$SAVE"
check "Escape at the name prompt: exit 0, nothing saved" bash -c '[[ $1 -eq 0 && ! -s $2 ]]' _ "$RC" "$TMP/applied.log"

if ((rc != 0)); then
    red "✗ dwm-display modes"
    exit 1
fi
green "✓ dwm-display modes: active outputs keep their mode, the real primary, save a profile"
