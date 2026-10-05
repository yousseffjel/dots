#!/usr/bin/env bash
# Exercises config/dwm/bin/dwm-emoji with fake dmenu, xclip and notify-send
# on a sealed PATH, against a fixture in the real emoji-test.txt format.
#
# The fixture's lines are copied from Unicode's emoji-test.txt (version 18.0,
# fetched 2026-10-05), including a header comment that itself contains the
# word "fully-qualified", so a parser matching the bare word is caught.
#
# What is asserted:
#   * only fully-qualified DATA lines are listed (not the header comment, not
#     unqualified or component lines), each with its name and group;
#   * the picked emoji reaches xclip byte-for-byte with no trailing newline,
#     including multi-code-point ones (skin tone, flag);
#   * Escape in dmenu copies nothing and exits 0;
#   * no data file or no xclip is exit 1.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SUT="$DOTS_DIR/config/dwm/bin/dwm-emoji"
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
export SB

cat >"$SB/emoji-test.txt" <<'EOF'
# emoji-test.txt
# Version: 18.0
#   Status
#       fully-qualified     — a fully-qualified emoji (see ED-18 in UTS #51),

# group: Smileys & Emotion

# subgroup: face-smiling
1F600                                                  ; fully-qualified     # 😀 E1.0 grinning face
263A FE0F                                              ; fully-qualified     # ☺️ E0.6 smiling face
263A                                                   ; unqualified         # ☺ E0.6 smiling face

# group: People & Body

# subgroup: hand-fingers-open
1F44B 1F3FB                                            ; fully-qualified     # 👋🏻 E1.0 waving hand: light skin tone

# group: Component

1F3FB                                                  ; component           # 🏻 E1.0 light skin tone

# group: Flags

1F1EF 1F1F5                                            ; fully-qualified     # 🇯🇵 E0.6 flag: Japan
EOF

seal_path "$SB/real" awk cat grep
mkdir -p "$SB/fake"
# The fake dmenu records the menu, then answers with the first line matching
# $PICK — or exits 1, as dmenu does on Escape, when PICK is empty.
# shellcheck disable=SC2016
fake "$SB/fake" dmenu 'cat >"$SB/menu.txt"; [ -n "$PICK" ] || exit 1; grep -m1 -- "$PICK" "$SB/menu.txt"'
# shellcheck disable=SC2016
fake "$SB/fake" xclip 'cat >"$SB/clip.txt"'
fake "$SB/fake" notify-send ':'

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}

# pick <pattern> [data file] — runs the SUT; exit code in $RC.
pick() {
    rm -f "$SB/clip.txt" "$SB/menu.txt"
    RC=0
    PICK="$1" DWM_EMOJI_DATA="${2:-$SB/emoji-test.txt}" PATH="$SB/fake:$SB/real" \
        "$(type -P bash)" "$SUT" >/dev/null 2>&1 || RC=$?
}
clip_is() { [[ "$(cat "$SB/clip.txt" 2>/dev/null)" == "$1" ]] && [[ "$(wc -c <"$SB/clip.txt")" -eq "$(printf '%s' "$1" | wc -c)" ]]; }

blue "the list"
pick "grinning"
check "four fully-qualified entries" test "$(wc -l <"$SB/menu.txt")" -eq 4
check "name and group" grep -qxF "😀 grinning face  [Smileys & Emotion]" "$SB/menu.txt"
check "no unqualified duplicate" test "$(grep -c 'smiling face' "$SB/menu.txt")" -eq 1
absent() { ! grep -q -- "$1" "$SB/menu.txt"; }
check "no component line" absent Component
check "no header comment" absent ED-18

blue "copying"
check "exit 0" test "$RC" -eq 0
check "grinning face copied exactly" clip_is "😀"
pick "light skin tone"
check "skin-tone sequence copied whole" clip_is "👋🏻"
pick "flag: Japan"
check "flag (two code points) copied whole" clip_is "🇯🇵"

blue "Escape"
pick ""
check "exit 0" test "$RC" -eq 0
check "nothing copied" test ! -e "$SB/clip.txt"

blue "missing pieces"
pick "grinning" "$SB/nope.txt"
check "no data file: exit 1" test "$RC" -eq 1
mv "$SB/fake/xclip" "$SB/xclip.off"
pick "grinning"
check "no xclip: exit 1" test "$RC" -eq 1

if [[ $FAILS -gt 0 ]]; then
    red "$FAILS check(s) failed"
    exit 1
fi
green "✓ dwm-emoji"
