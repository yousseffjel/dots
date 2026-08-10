#!/usr/bin/env bash
# Guards manifest_has_path() in scripts/global_fn.sh — the single lookup that
# three installer predicates were collapsed onto (theme_is_ours,
# theme_backed_up, app_is_ours).
#
# WHY THIS TEST EXISTS. The obvious spelling of that function is
#
#     manifest_rows "$1" | cut -f3 | grep -qxF "$2"
#
# and it is wrong in a way that reads as correct. `grep -q` exits the moment it
# matches, which SIGPIPEs `cut`; under the `set -o pipefail` every caller
# inherits, the pipeline's status becomes 141 — a FAILURE — even though the
# path WAS found. The caller concludes "not ours" and does the destructive
# thing: backs up a file it wrote itself, or re-backs-up a file on every
# install, the second time capturing generated content instead of the user's
# original. `|| true` is not the fix either; it maps 141 to 0, so every path
# becomes "ours", including files the installer promised never to touch.
#
# The failure is timing-dependent — it needs enough rows after the match for
# grep to exit before cut finishes writing — so a small fixture passes with the
# broken shape and proves nothing. Hence the 200k-row manifest with the target
# in FIRST position, which is the worst case for the buggy version and the best
# case for hiding the bug on a toy input.
#
# The shipped function is sourced, never re-typed. A reimplementation here
# would test this file against itself and stay green while global_fn.sh rotted.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

GLOBAL_FN="$DOTS_DIR/scripts/global_fn.sh"
if [[ ! -f "$GLOBAL_FN" ]]; then
    printf '\033[31mmissing: %s\033[0m\n' "$GLOBAL_FN"
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Sandbox every XDG variable global_fn.sh reads, not just HOME: MANIFEST_DIR is
# derived from XDG_STATE_HOME, so a HOME-only sandbox would point this test at
# the real install manifest that uninstall.sh acts on.
export HOME="$TMP"
export XDG_STATE_HOME="$TMP/state"

# Sourced before anything else needs a colour helper: global_fn.sh supplies
# red/green/blue itself, so this file deliberately does NOT define its own.
# Local copies would be silently overwritten at this line and become dead code
# (shellcheck SC2329) — the one place in the repo where rule 2's "every script
# defines its own helpers" does not apply, because this script sources the file
# that owns them.
# shellcheck source=../scripts/global_fn.sh
source "$GLOBAL_FN"

rc=0

# Assertion helpers rather than `manifest_has_path … && pass || fail`: in that
# idiom a failing `pass` would go on to run `fail` as well (SC2015), so a
# green-looking suite could be hiding a broken reporter.
assert_hit() {
    local desc="$1" tag="$2" path="$3"
    if manifest_has_path "$tag" "$path"; then
        green "  ok: $desc"
    else
        red "  FAIL: $desc"
        rc=1
    fi
}

assert_miss() {
    local desc="$1" tag="$2" path="$3"
    if manifest_has_path "$tag" "$path"; then
        red "  FAIL: $desc"
        rc=1
    else
        green "  ok: $desc"
    fi
}

# --- fixture ----------------------------------------------------------------

mkdir -p "$MANIFEST_DIR"
{
    printf 'META\tversion\t0.1.0\n'
    printf 'THEME\ttheme\t/home/probe/.config/gtk-3.0/gtk.css\n'
    printf 'THEME\ttheme\t/home/probe/.config/with space/dunstrc\n'
    printf 'THEMEBACKUP\ttheme\t/home/probe/.config/picom/picom.conf\n'
    printf 'APP\tapp\t/home/probe/.config/Thunar/thunarrc\n'
} >"$MANIFEST_FILE"

blue "==> lookups against the shipped helper"

assert_hit "THEME hit" THEME /home/probe/.config/gtk-3.0/gtk.css
assert_hit "THEME hit containing a space" THEME "/home/probe/.config/with space/dunstrc"
assert_hit "THEMEBACKUP hit" THEMEBACKUP /home/probe/.config/picom/picom.conf
assert_hit "APP hit" APP /home/probe/.config/Thunar/thunarrc

# Category is part of the key: a THEME path must not answer for APP. This is
# what keeps uninstall from deleting a file recorded under a category it does
# not own.
assert_miss "category is honoured (THEME row does not answer for APP)" \
    APP /home/probe/.config/gtk-3.0/gtk.css

assert_miss "miss returns non-zero" THEME /home/probe/.config/nope

# A partial path must not match: rows are compared whole, so claiming
# ".../gtk.cs" or ".../gtk.css.bak" must both miss.
assert_miss "prefix does not match" THEME /home/probe/.config/gtk-3.0/gtk.cs
assert_miss "superstring does not match" THEME /home/probe/.config/gtk-3.0/gtk.css.bak

# No manifest at all is the fresh-install state and must be a clean miss, not
# an error — the callers run before anything has been written.
rm -f "$MANIFEST_FILE"
assert_miss "missing manifest is a clean miss" THEME /home/probe/.config/gtk-3.0/gtk.css

# --- the regression this function exists for --------------------------------

blue "==> SIGPIPE/pipefail: shipped shape vs. the shape it replaced"

TARGET=/home/probe/.config/gtk-3.0/gtk.css
{
    printf 'THEME\ttheme\t%s\n' "$TARGET"
    for i in $(seq 1 200000); do printf 'THEME\ttheme\t/home/probe/filler-%s\n' "$i"; done
} >"$MANIFEST_FILE"

# The shape that was removed, reproduced verbatim so the test fails if someone
# ever "simplifies" global_fn.sh back to it.
broken_has_path() (
    set -o pipefail
    manifest_rows "$1" 2>/dev/null | cut -f3 | grep -qxF "$2"
)

broken_hits=0 shipped_hits=0
for _ in 1 2 3 4 5; do
    broken_has_path THEME "$TARGET" && broken_hits=$((broken_hits + 1))
    manifest_has_path THEME "$TARGET" && shipped_hits=$((shipped_hits + 1))
done

if ((shipped_hits == 5)); then
    green "  ok: shipped shape found the target 5/5 times on a 200k-row manifest"
else
    red "  FAIL: shipped shape found the target only $shipped_hits/5 times — the SIGPIPE bug is back"
    rc=1
fi

# Not asserted as exactly 0/5: this is a race, and a machine slow enough for
# cut to finish first would make the old shape pass by luck. Anything under 5
# still proves the shapes are not equivalent, which is the claim being made.
if ((broken_hits < 5)); then
    green "  ok: the replaced shape still misses ($broken_hits/5) — the hazard is real, not historical"
else
    red "  NOTE: the replaced shape scored 5/5 here, so this run did not"
    red "        reproduce the race. That does NOT make the pipeline safe —"
    red "        it means this machine finished cut before grep exited."
    red "        Do not take it as licence to reintroduce the pipeline."
fi

if ((rc != 0)); then
    red "✗ manifest_has_path is broken"
    exit 1
fi
green "✓ manifest_has_path: lookups, category scoping and the SIGPIPE regression all hold"
