#!/usr/bin/env bash
# Every link in wiki/ leads somewhere.
#
# The wiki is published as a separate repo (scripts/wiki-publish.sh), so a
# relative link like (docs/THEMING.md) that works in this repo is a dead link
# there. Pages link each other as (Page-Name) and this repo's files as
# absolute https://github.com/<owner>/dots/blob|tree/main/<path> URLs, and
# this checks both kinds:
#
#   * an internal link names an existing wiki/<Page-Name>.md;
#   * a blob/tree link names a path that exists in this checkout;
#   * no link is a relative path (contains / or ends in .md);
#   * every page is in _Sidebar.md, so none is unreachable.
#
# Docs drift as files move; this turns a renamed file into a red build
# instead of a 404 a reader finds.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

WIKI="${DOTS_WIKI_DIR:-$DOTS_DIR/wiki}"
# This repo on GitHub; the owner is matched case-insensitively, like GitHub.
REPO_RE='^https://github\.com/[Yy]oussef[Ff]jel/dots/(blob|tree)/main/'

rc=0
fail() {
    red "  FAIL: $1"
    rc=1
}

shopt -s nullglob
pages=("$WIKI"/*.md)
if ((${#pages[@]} == 0)); then
    red "no pages in $WIKI"
    exit 1
fi

# links <file> — every markdown link target, one per line, with code spans
# and fenced blocks dropped first (a `[a](b)` in a code sample is no link).
links() {
    awk '/^```/ { f = !f; next } !f' "$1" \
        | sed 's/`[^`]*`//g' \
        | grep -oE '\]\([^) ]+' | sed 's/^](//' || true
}

blue "==> links in wiki/"
checked=0
for page in "${pages[@]}"; do
    name="${page##*/}"
    while IFS= read -r target; do
        [[ -n "$target" ]] || continue
        checked=$((checked + 1))
        case "$target" in
            "#"*) ;;
            https://github.com/*/dots/blob/* | https://github.com/*/dots/tree/*)
                if [[ ! "$target" =~ $REPO_RE ]]; then
                    fail "$name: $target is not this repo's main branch"
                    continue
                fi
                path="${target#https://github.com/*/dots/*/main/}"
                path="${path%%#*}"
                path="${path%/}"
                [[ -e "$DOTS_DIR/$path" ]] || fail "$name: $target -> $path does not exist"
                ;;
            http://* | https://* | mailto:*) ;;
            */* | *.md | *.md#*)
                fail "$name: relative link ($target) is dead on the wiki; use (Page-Name) or a github.com URL"
                ;;
            *)
                [[ -f "$WIKI/${target%%#*}.md" ]] || fail "$name: ($target) names no wiki page"
                ;;
        esac
    done < <(links "$page")
done

blue "==> every page is in the sidebar"
if [[ -f "$WIKI/_Sidebar.md" ]]; then
    for page in "${pages[@]}"; do
        name="${page##*/}"
        name="${name%.md}"
        [[ "$name" == _* ]] && continue
        grep -qE "\]\($name(#[^)]*)?\)" "$WIKI/_Sidebar.md" || fail "$name is not linked from _Sidebar.md"
    done
else
    fail "wiki/_Sidebar.md is missing"
fi

if ((rc == 0)); then
    green "✓ wiki-links: ${#pages[@]} pages, $checked links, all resolve"
fi
exit "$rc"
