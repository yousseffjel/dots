#!/usr/bin/env bash
# Every handler config/mimeapps.list names must be something an install puts
# on disk. A name with no provider is silently skipped by GIO, which then
# opens the file in whatever else claims the type: the default just quietly
# stops being the default.
#
# What is asserted:
#   * each .desktop id is provided by one of
#       - a file this repo ships in config/applications/,
#       - a vendored program that installs it (suckless/<prog>/etc/<id>), and
#         that program is in install-suckless.sh's PROGRAMS with a target that
#         installs the desktop file,
#       - a package declared in packages/*.lst, or installed by
#         install-pkg-repos.sh;
#   * an id this test cannot map is a FAILURE, not a skip, so a new handler
#     has to be wired here rather than slipping past;
#   * no MIME type is listed twice in [Default Applications];
#   * every Sublime Text default keeps dots-nvim.desktop as its fallback.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

MIMEAPPS="$DOTS_DIR/config/mimeapps.list"
REPOS="$DOTS_DIR/scripts/install-pkg-repos.sh"
SUCKLESS="$DOTS_DIR/scripts/install-suckless.sh"

# desktop id -> the package that ships it. This is the one fact the repo
# cannot derive without dnf (CLAUDE.md rule 8: no dnf on the dev host). Each
# was read from the package itself: sublime_text.desktop from the
# sublime-text-4215 rpm, mpv.desktop from mpv's upstream etc/.
declare -A PACKAGE_OF=(
    ["firefox.desktop"]=firefox
    ["thunar.desktop"]=thunar
    ["org.gnome.FileRoller.desktop"]=file-roller
    ["mpv.desktop"]=mpv
    ["sublime_text.desktop"]=sublime-text
)

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}

# Values of both sections, one desktop id per line.
handler_ids() {
    grep -E '^[a-z]+/[^=]+=' "$MIMEAPPS" | cut -d= -f2 | tr ';' '\n' | grep -v '^$' | sort -u
}

declared_in_lst() {
    sed 's/#.*//' "$DOTS_DIR"/packages/*.lst | tr -s '[:space:]' '\n' | grep -qxF "$1"
}

# install-pkg-repos.sh installs by literal name: `drivers_pkg <name>`.
installed_by_repos() {
    grep -qE "drivers_pkg $1( |\$)" "$REPOS"
}

vendored_provider() {
    local id="$1" etc prog
    for etc in "$DOTS_DIR"/suckless/*/etc/"$id"; do
        [[ -f "$etc" ]] || continue
        prog="$(basename "$(dirname "$(dirname "$etc")")")"
        grep -m1 '^PROGRAMS=(' "$SUCKLESS" | grep -qw "$prog" || return 1
        grep -qE "^\s*\[$prog\]=\"[^\"]*install-desktop" "$SUCKLESS" || return 1
        return 0
    done
    return 1
}

has_provider() {
    local id="$1" pkg="${PACKAGE_OF[$1]:-}"
    [[ -f "$DOTS_DIR/config/applications/$id" ]] && return 0
    vendored_provider "$id" && return 0
    [[ -n "$pkg" ]] || return 1
    declared_in_lst "$pkg" || installed_by_repos "$pkg"
}

# result <what> <status> — check for a function of this file. Passed through
# check's "$@" instead, shellcheck sees none of them called and flags each
# (SC2329). The status comes from `cmd && rc=0 || rc=$?`, so a failure is
# recorded rather than ending the run under set -e.
result() {
    if [[ $2 -eq 0 ]]; then green "  ok    $1"; else
        red "  FAIL  $1"
        FAILS=$((FAILS + 1))
    fi
}

blue "==> every handler has a provider"
mapfile -t ids < <(handler_ids)
check "found handlers to check (${#ids[@]})" test "${#ids[@]}" -ge 5
for id in "${ids[@]}"; do
    has_provider "$id" && rc=0 || rc=$?
    result "$id" "$rc"
done

blue "==> the lookup can fail"
has_provider nope.desktop && rc=1 || rc=0
result "an id nothing provides is reported, not passed" "$rc"
check "nsxiv.desktop comes from suckless/nsxiv, not a package" \
    test -f "$DOTS_DIR/suckless/nsxiv/etc/nsxiv.desktop"

blue "==> [Default Applications] is well-formed"
defaults="$(sed -n '/^\[Default Applications\]/,/^\[/p' "$MIMEAPPS" | grep -E '^[a-z]+/[^=]+=')"
dupes="$(cut -d= -f1 <<<"$defaults" | sort | uniq -d)"
check "no type listed twice${dupes:+ ($dupes)}" test -z "$dupes"
no_fallback="$(grep 'sublime_text.desktop' <<<"$defaults" | grep -v 'dots-nvim.desktop' || true)"
check "every sublime_text default falls back to dots-nvim${no_fallback:+ ($no_fallback)}" test -z "$no_fallback"

if [[ $FAILS -eq 0 ]]; then
    green "✓ default apps: every handler is installed by something"
else
    red "✗ $FAILS check(s) failed"
fi
exit "$FAILS"
