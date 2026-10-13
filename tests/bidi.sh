#!/usr/bin/env bash
# The bidi() helpers of the fribidi patches (suckless/{dwm,dmenu}/patches/
# PATCHES.md), compiled out of the SHIPPED dwm.c and dmenu.c — extracted, not
# reimplemented — and run against fribidi under AddressSanitizer:
#   * pure ASCII comes back as the same pointer (the bar's common case pays
#     nothing, and an ASCII query in dmenu is drawn untouched);
#   * Arabic comes back shaped (presentation forms, the lam-alef ligature)
#     and in visual order;
#   * inputs at and past each buffer cap — 2-byte letters that grow into
#     3-byte forms, a cap that splits a UTF-8 sequence — stay in bounds.
#     The upstream patches overflowed exactly here; with their 256-byte
#     buffer this test's long-title case is an ASan global-buffer-overflow.
#
# Needs cc and the fribidi headers, so the tests job skips it and the
# build-suckless job — which has build.lst installed — runs it as --strict,
# where a missing compiler, header or ASan runtime is a failure, not a skip.
#
# usage: tests/bidi.sh [--strict]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

STRICT=0
case "${1:-}" in
    --strict) STRICT=1 ;;
    "") ;;
    *)
        echo "usage: tests/bidi.sh [--strict]"
        exit 2
        ;;
esac

skip() {
    if [[ $STRICT -eq 1 ]]; then
        red "FAIL: bidi.sh needs $1 (--strict)"
        exit 1
    fi
    yellow "SKIP: bidi.sh needs $1 and it is not available."
    exit 0
}

command -v cc >/dev/null 2>&1 || skip "a C compiler (cc)"
if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists fribidi; then
    read -r -a FRIBIDI_CFLAGS <<<"$(pkg-config --cflags fribidi)"
    read -r -a FRIBIDI_LIBS <<<"$(pkg-config --libs fribidi)"
elif [[ -f /usr/include/fribidi/fribidi.h ]]; then
    FRIBIDI_CFLAGS=(-I/usr/include/fribidi)
    FRIBIDI_LIBS=(-lfribidi)
else
    skip "the fribidi headers (fribidi-devel)"
fi

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

# From the line before `bidi(const char *str)` (its return type) to the
# closing brace. dmenu's buffers are sized by BIDI_MAX, defined just above.
extract_bidi() {
    awk '/^bidi\(const char \*str\)$/ { print prev; p = 1 }
         p { print }
         p && /^}$/ { exit }
         { prev = $0 }' "$1"
}

HARNESS="$(
    cat <<'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fribidi.h>
#include "impl.c"

static int fails;
static void check(int cond, const char *what) {
	printf("  %s: %s\n", cond ? "ok" : "FAIL", what);
	fails += !cond;
}
static char *repeat(const char *unit, int n) {
	size_t u = strlen(unit);
	char *s = malloc(u * n + 1);
	for (int i = 0; i < n; i++)
		memcpy(s + u * i, unit, u);
	s[u * n] = 0;
	return s;
}
int main(int argc, char **argv) {
	int cap = atoi(argv[1]);
	const char *ascii = "Firefox - plain ASCII title";
	check(bidi(ascii) == ascii, "pure ASCII returns the same pointer");

	/* meem reh hah beh alef -> alef-final beh-medial hah-initial reh-final meem-initial */
	check(!strcmp(bidi("\xd9\x85\xd8\xb1\xd8\xad\xd8\xa8\xd8\xa7"),
	    "\xef\xba\x8e\xef\xba\x92\xef\xba\xa3\xef\xba\xae\xef\xbb\xa3"),
	    "Arabic is shaped into presentation forms, in visual order");
	check(strstr(bidi("\xd9\x84\xd8\xa7"), "\xef\xbb\xbb") != NULL,
	    "lam + alef becomes the U+FEFB ligature");
	check(!strncmp(bidi("abc \xd8\xa8"), "abc ", 4),
	    "an LTR-first line keeps its Latin run on the left");

	/* 2-byte letters past the cap: each grows to 3 bytes when shaped, and
	 * the byte cap lands mid-sequence when it is odd. */
	char *lam = repeat("\xd9\x84", cap);
	check(strlen(bidi(lam)) <= (size_t)4 * cap, "a title past the cap stays in bounds");
	char *xlam = malloc(2 * cap + 2);
	xlam[0] = 'x';
	strcpy(xlam + 1, lam);
	check(strlen(bidi(xlam)) <= (size_t)4 * cap, "an odd split of the last sequence stays in bounds");
	/* 4-byte codepoints (emoji) mixed in: the widest UTF-8 a cap can split */
	char *emoji = repeat("\xd8\xa8\xf0\x9f\x98\x80", cap);
	check(strlen(bidi(emoji)) <= (size_t)4 * cap, "4-byte sequences around the cap stay in bounds");
	return fails != 0;
}
EOF
)"

USE_ASAN=1
echo 'int main(void){return 0;}' >"$SB/probe.c"
if ! cc -fsanitize=address -o "$SB/probe" "$SB/probe.c" 2>/dev/null; then
    [[ $STRICT -eq 1 ]] && skip "the AddressSanitizer runtime (libasan)"
    yellow "  note: no ASan runtime here — running without overflow detection"
    USE_ASAN=0
fi

FAIL=0
run_one() { # <program> <source> <cap> [extra preamble]
    local prog="$1" src="$2" cap="$3" pre="${4:-}" dir="$SB/$1"
    blue "==> $prog: bidi() from ${src#"$DOTS_DIR"/}"
    mkdir -p "$dir"
    if ! grep -q '^bidi(const char \*str)$' "$src"; then
        red "  FAIL: no bidi() definition in $src"
        FAIL=1
        return
    fi
    {
        printf '%s\n' "$pre"
        extract_bidi "$src"
    } >"$dir/impl.c"
    printf '%s\n' "$HARNESS" >"$dir/harness.c"
    local flags=(-std=c99 -g -Wall -D_DEFAULT_SOURCE)
    [[ $USE_ASAN -eq 1 ]] && flags+=(-fsanitize=address -fno-omit-frame-pointer)
    if ! cc "${flags[@]}" "${FRIBIDI_CFLAGS[@]}" -I"$dir" -o "$dir/t" "$dir/harness.c" "${FRIBIDI_LIBS[@]}"; then
        red "  FAIL: the extracted bidi() does not compile"
        FAIL=1
        return
    fi
    ASAN_OPTIONS=detect_leaks=0 "$dir/t" "$cap" || FAIL=1
}

# A correct bidi() that nothing calls fixes nothing: each draw site the patch
# covers must pass its text through it.
callsite() { # <file> <fixed string> <what>
    if grep -qF "$2" "$1"; then
        green "  ok: $3 is drawn through bidi()"
    else
        red "  FAIL: $3 is no longer drawn through bidi() in ${1#"$DOTS_DIR"/}"
        FAIL=1
    fi
}
blue "==> draw sites"
callsite "$DOTS_DIR/suckless/dwm/dwm.c" 'bidi(m->sel->name)' "dwm's window title"
callsite "$DOTS_DIR/suckless/dmenu/dmenu.c" 'bidi(item->text)' "each dmenu item"
callsite "$DOTS_DIR/suckless/dmenu/dmenu.c" 'bidi(text), 0)' "dmenu's input line"

# dwm: the title is Client.name, char[256], so at most 255 bytes reach bidi().
run_one dwm "$DOTS_DIR/suckless/dwm/dwm.c" 255
# dmenu: a stdin line has no length limit; bidi() cuts at BIDI_MAX.
run_one dmenu "$DOTS_DIR/suckless/dmenu/dmenu.c" 8191 \
    "$(grep '^#define BIDI_MAX' "$DOTS_DIR/suckless/dmenu/dmenu.c")"

echo
if [[ $FAIL -eq 0 ]]; then
    green "bidi.sh: all checks passed$([[ $USE_ASAN -eq 1 ]] && echo ' under ASan')"
else
    red "bidi.sh: failures above"
    exit 1
fi
