#!/usr/bin/env bash
# The live-ISO installer's docs against its code (scope J, J-5). Each
# check reads both sides, so neither can change alone:
#   - docs/LIVE-INSTALL.md's answers table lists exactly LIVE_ANSWER_KEYS,
#     in order, and marks exactly LIVE_REQUIRED_KEYS "yes";
#   - docs/live-answers.example names every key, is refused as shipped
#     (empty USER_PASSWORD_HASH) on that line alone, and loads with the
#     shipped parser once it is filled in;
#   - every flag install-live.sh parses is in its --help and in the page.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

DOC="$DOTS_DIR/docs/LIVE-INSTALL.md"
EXAMPLE="$DOTS_DIR/docs/live-answers.example"
LIVE="$DOTS_DIR/scripts/install-live.sh"

# shellcheck source=../scripts/install-live-answers.sh
source "$DOTS_DIR/scripts/install-live-answers.sh"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/zoneinfo" "$SB/keymaps/i386/qwerty"
: >"$SB/zoneinfo/UTC"
: >"$SB/keymaps/i386/qwerty/us.map.gz"
printf '%s\n' '#en_US.UTF-8 UTF-8' >"$SB/libc-locales"
export LIVE_ZONEINFO_DIR="$SB/zoneinfo" LIVE_KEYMAP_DIR="$SB/keymaps" LIVE_LOCALES_FILE="$SB/libc-locales"
# The passphrase file must be root's; the test's own uid stands in.
LIVE_PASSFILE_UID="$(id -u)"
export LIVE_PASSFILE_UID

rc=0
check() {
    if [[ $2 == "$3" ]]; then
        green "  ok: $1"
    else
        red "  FAIL: $1"
        printf '      want: %s\n      got:  %s\n' "$2" "$3"
        rc=1
    fi
}

# The rows of the "## Answers file" table: "<key> <required>", one a line.
# The backticks in the sed are literal Markdown, not a command substitution.
# shellcheck disable=SC2016
doc_rows() {
    sed -n '/^## Answers file/,/^## /p' "$DOC" \
        | sed -n 's/^| `\([A-Z_]*\)` | \([^|]*\) |.*/\1 \2/p' | sed 's/ *$//'
}

blue "==> the page's answers table"
check "every key, in LIVE_ANSWER_KEYS order" "${LIVE_ANSWER_KEYS[*]}" \
    "$(doc_rows | cut -d' ' -f1 | paste -sd' ')"
check "\"yes\" exactly on LIVE_REQUIRED_KEYS" "${LIVE_REQUIRED_KEYS[*]}" \
    "$(doc_rows | awk '$2 == "yes" { print $1 }' | paste -sd' ')"

blue "==> docs/live-answers.example"
named="$(sed -n 's/^#\{0,1\}\([A-Z_]*\)=.*/\1/p' "$EXAMPLE" | paste -sd' ')"
check "names every key, in order" "${LIVE_ANSWER_KEYS[*]}" "$named"

# load <file> — the shipped parser in a subshell; prints its output, and
# "LOADED <user kind> <disk>" when it accepted the file.
load() {
    chmod 600 "$1"
    (live_answers_load "$1" && echo "LOADED $LIVE_USER_KIND $LIVE_DISK_ANSWER $LIVE_LUKS_FILE_SEEN") 2>&1 || true
}
# The LUKS loader is the real one; record that it ran rather than what it
# read (a secret).
live_luks_load_passfile() { LIVE_LUKS_FILE_SEEN=passfile; }
LIVE_LUKS_FILE_SEEN=none

cp "$EXAMPLE" "$SB/shipped"
check "refused as shipped, on USER_PASSWORD_HASH alone" \
    "answers line $(grep -n '^USER_PASSWORD_HASH=' "$EXAMPLE" | cut -d: -f1): invalid USER_PASSWORD_HASH|answers file: missing USER_PASSWORD_HASH" \
    "$(load "$SB/shipped" | sed 's/\x1b\[[0-9;]*m//g' | paste -sd'|')"

# Filled in the way the page says: a real hash, the disk named twice, a
# passphrase file. Every commented key line is switched on.
# shellcheck disable=SC2016
H6='$6$dotsTEST1$hmwaRIQo9Gf15e0pP1zaFWg8J31000TkbvDkltXxWUhZJNkfvT6pbnQUxQsow95stlBOn44W9KusWc/vVmZW1/'
(
    umask 077
    printf '%s\n' 'a passphrase' >"$SB/luks-pass"
)
sed -e "s|^USER_PASSWORD_HASH=\$|USER_PASSWORD_HASH='$H6'|" \
    -e 's/^#\([A-Z_]*=\)/\1/' -e "s|^LUKS_PASSFILE=.*|LUKS_PASSFILE=$SB/luks-pass|" \
    "$EXAMPLE" >"$SB/filled"
check "loads once filled in" "LOADED hash /dev/vda passfile" \
    "$(load "$SB/filled" | grep '^LOADED' || true)"

blue "==> flags"
help="$(bash "$LIVE" --help)"
flags="$(sed -n 's/^ *\(-h | \)\{0,1\}\(--[a-z-]*\)).*/\2/p' "$LIVE")"
[[ -n $flags ]] || {
    red "  FAIL: no flags found in install-live.sh's case statement"
    exit 1
}
for flag in $flags; do
    [[ $flag == --help ]] && continue
    grep -qF -- "$flag" <<<"$help" && in_help=yes || in_help=no
    grep -q "^| \`$flag" "$DOC" && in_doc=yes || in_doc=no
    check "$flag in --help and the page's flag table" "yes yes" "$in_help $in_doc"
done

exit "$rc"
