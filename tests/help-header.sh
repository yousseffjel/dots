#!/usr/bin/env bash
# --help that prints a script's own header comment prints all of it, and a
# --help that prints a fixed excerpt of it ends at a paragraph break.
#
# WHY. symlinks.sh printed `sed -n '2,15p'` of its header and stopped
# mid-sentence ("currently one of this script's own symlinks —") once the
# header grew; install-void.sh's `2,50p` silently dropped every paragraph
# added after line 50. Nothing noticed either for months.
#
# HOW. Three parts, all read from the scripts rather than listed here:
#   1. every scripts/ file using the whole-header idiom (`sed -n '2,/^[^#]/'`)
#      is RUN with --help in a sandboxed HOME and all four XDG vars, and its
#      output must equal the header as this test reads it independently;
#   2. install-void.sh --help must not append to the repo's install.log — a
#      help request is not a run;
#   3. every remaining fixed range, `sed -n 'A,Bp' "${BASH_SOURCE[0]}"`, must
#      end on a bare `#` or right before one (or before the code), so the
#      excerpt cannot end mid-paragraph.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home"

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

# The header as a reader sees it: line 2 onward, up to the first line that is
# not a comment, with the leading "# " removed.
header_of() {
    local line n=0
    while IFS= read -r line; do
        n=$((n + 1))
        ((n >= 2)) || continue
        [[ -z "$line" || "$line" == "#"* ]] || break
        [[ "$line" == "#"* ]] || continue
        line="${line#\#}"
        printf '%s\n' "${line# }"
    done <"$1"
}

# [[ ]] rather than test(1): header text can hold "(", "!" or "-a".
same() { [[ -n "$1" && "$1" == "$2" ]]; }
# A range ending on a bare "#", right before one, or right before the code.
para_end() { [[ "$1" == "#" || "$2" == "#" || "$2" != "#"* ]]; }

run_help() {
    env -i PATH="$PATH" HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/home/.config" \
        XDG_DATA_HOME="$TMP/home/.local/share" XDG_STATE_HOME="$TMP/home/.local/state" \
        XDG_CACHE_HOME="$TMP/home/.cache" "$(type -P bash)" "$1" --help
}

blue "==> --help prints the whole header"
mapfile -t whole < <(grep -rlF "sed -n '2,/^[^#]/" "$DOTS_DIR/scripts" | sort)
check "found the whole-header scripts (install-void.sh, symlinks.sh at least)" \
    test "${#whole[@]}" -ge 2
for f in "${whole[@]}"; do
    rel="${f#"$DOTS_DIR"/}"
    want="$(header_of "$f")"
    # `|| got=...`: under set -e a failing --help would end the test silently.
    got="$(run_help "$f" 2>&1)" || got="--help exited $?: $got"
    check "$rel: --help is the full header ($(wc -l <<<"$want") lines)" \
        same "$want" "$got"
done

blue "==> install-void.sh --help is not logged as a run"
LOG="$DOTS_DIR/install.log"
before="$(cat "$LOG" 2>/dev/null || echo absent)"
check "install-void.sh --help exits 0" run_help "$DOTS_DIR/scripts/install-void.sh" >/dev/null
after="$(cat "$LOG" 2>/dev/null || echo absent)"
check "install.log unchanged" [ "$before" == "$after" ]

blue "==> fixed-range excerpts end at a paragraph break"
n=0
while IFS=: read -r f lineno text; do
    [[ "$text" =~ sed\ -n\ \'([0-9]+),([0-9]+)p\' ]] || continue
    end="${BASH_REMATCH[2]}"
    n=$((n + 1))
    last="$(sed -n "${end}p" "$f")"
    next="$(sed -n "$((end + 1))p" "$f")"
    check "${f#"$DOTS_DIR"/}:$lineno: line $end ends a paragraph" para_end "$last" "$next"
done < <(grep -rnE "sed -n '[0-9]+,[0-9]+p' \"\\$\{BASH_SOURCE\[0\]\}\"" "$DOTS_DIR/scripts")
check "found at least one excerpt printer" test "$n" -ge 1

if ((rc != 0)); then
    red "✗ --help headers"
    exit 1
fi
green "✓ --help headers: whole headers complete, excerpts end at a paragraph"
