#!/usr/bin/env bash
# wiki-publish.sh — push wiki/ to the GitHub wiki (a separate git repo,
# <origin>.wiki.git). wiki/ in this repo is the source; the GitHub wiki is a
# mirror of it, so a page edited on GitHub is overwritten by the next publish.
#
#   wiki-publish.sh             mirror wiki/ at HEAD to the wiki and push
#   wiki-publish.sh --dry-run   clone, mirror and show the diff; push nothing
#
# Publishes what is COMMITTED (HEAD's wiki/), never the working tree, so the
# wiki only ever shows pages that went through review and tests/wiki-links.sh.
# Refuses while wiki/ has uncommitted changes, so that is never a surprise.
#
# GitHub creates the wiki repo only when its first page is made in the web
# UI (Wiki tab -> "Create the first page"; any content, it is replaced here).
# Until then the clone fails, and this says so.
#
# A developer tool: not run by the installer, not a `dots` subcommand.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

usage() { sed -n '6,7p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

DRY_RUN=""
case "${1:-}" in
    "") ;;
    --dry-run) DRY_RUN=1 ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        red "wiki-publish.sh: unknown option '$1'"
        usage >&2
        exit 1
        ;;
esac

gitd() { git -C "$DOTS_DIR" "$@"; }

# wiki_url — origin's URL with .wiki.git in place of .git (or appended).
wiki_url() {
    local url
    url="$(gitd remote get-url origin)"
    url="${url%/}"
    printf '%s.wiki.git\n' "${url%.git}"
}

if [[ -n "$(gitd status --porcelain -- wiki/)" ]]; then
    red "wiki/ has uncommitted changes; commit them first (only HEAD is published)"
    exit 1
fi
if ! gitd ls-tree -r --name-only HEAD -- wiki/ | grep -q '\.md$'; then
    red "HEAD has no wiki/*.md to publish"
    exit 1
fi

URL="$(wiki_url)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

blue "==> cloning $URL"
if ! git clone --quiet --depth 1 "$URL" "$WORK/wiki" 2>"$WORK/clone.err"; then
    red "could not clone the wiki repo:"
    sed 's/^/  /' "$WORK/clone.err" >&2
    yellow "  If the wiki has no page yet, GitHub has not created its repo: open the"
    yellow "  repo's Wiki tab, click \"Create the first page\", save it, and re-run."
    exit 1
fi

# Mirror: every .md the wiki has is replaced or removed, so a page deleted
# from wiki/ disappears there too. Anything else in the wiki repo (uploaded
# images) is left alone.
# The archive's paths start with wiki/, so it unpacks straight into the clone.
find "$WORK/wiki" -maxdepth 1 -name '*.md' -delete
gitd archive HEAD wiki/ | tar -x -C "$WORK"

git -C "$WORK/wiki" add -A
if git -C "$WORK/wiki" diff --cached --quiet; then
    green "the wiki already matches wiki/ at $(gitd rev-parse --short HEAD)"
    exit 0
fi

git -C "$WORK/wiki" diff --cached --stat
if [[ -n "$DRY_RUN" ]]; then
    yellow "dry run: nothing pushed"
    exit 0
fi

git -C "$WORK/wiki" commit --quiet -m "Sync from dots $(gitd rev-parse --short HEAD)"
blue "==> pushing"
git -C "$WORK/wiki" push --quiet origin HEAD
green "wiki published from $(gitd rev-parse --short HEAD)"
