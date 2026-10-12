#!/usr/bin/env bash
# dots update — bring an existing install up to the latest pushed version:
# pull the repo (fast-forward only), then re-run install-fedora.sh, which runs
# the migrations, installs any newly declared packages, rebuilds the suckless
# programs and prints any lines your own autostart.sh/.xinitrc still need.
#
#   update.sh               pull, then re-run the installer
#   update.sh --dry-run     fetch and list what would come in; change nothing
#   update.sh <args...>     pull, then pass <args> on to install-fedora.sh
#
# Refuses — before touching anything — a dirty tracked tree, a detached HEAD,
# a branch with no upstream, and an upstream that is not a fast-forward:
# each of those needs a decision this script must not make for you.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

usage() {
    sed -n '7,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' \
        | sed "s|update\.sh|${DOTS_CMD:-update.sh}|g"
}

fail() {
    red "$1"
    [[ -z "${2:-}" ]] || yellow "  $2"
    exit 1
}

gitd() { git -C "$DOTS_DIR" "$@"; }

# Every refusal happens here, before the fetch, so a refused update has
# changed nothing at all.
preflight() {
    gitd rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || fail "$DOTS_DIR is not a git checkout — dots update needs one" \
            "re-clone the repo, or update it by hand and run scripts/install-fedora.sh"
    gitd symbolic-ref -q HEAD >/dev/null \
        || fail "the repo is on a detached HEAD" "check out your branch first (git -C $DOTS_DIR switch main)"
    gitd rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 \
        || fail "the current branch has no upstream to pull from" \
            "set one: git -C $DOTS_DIR branch --set-upstream-to=origin/main"
    [[ -z "$(gitd status --porcelain --untracked-files=no)" ]] \
        || fail "the repo has uncommitted changes to tracked files" \
            "commit or stash them first (git -C $DOTS_DIR status shows them)"
}

main() {
    local dry=0 arg old new before args=()
    for arg in "$@"; do
        case "$arg" in
            --dry-run) dry=1 ;;
            -h | --help)
                usage
                exit 0
                ;;
            *) args+=("$arg") ;;
        esac
    done

    preflight
    blue "==> fetching"
    gitd fetch --quiet || fail "git fetch failed — check the network and the remote"

    if ((dry)); then
        if [[ -z "$(gitd rev-list HEAD..'@{u}')" ]]; then
            green "already up to date ($(tr -d '[:space:]' <"$DOTS_DIR/VERSION"))"
        else
            blue "would bring in:"
            gitd log --oneline HEAD..'@{u}'
        fi
        exit 0
    fi

    old="$(tr -d '[:space:]' <"$DOTS_DIR/VERSION")"
    before="$(gitd rev-parse HEAD)"
    # Ahead-only and diverged are told apart before merging: a failed merge
    # can also mean an untracked file in the way, which needs its own hint.
    if ! gitd merge-base --is-ancestor HEAD '@{u}'; then
        if gitd merge-base --is-ancestor '@{u}' HEAD; then
            green "nothing to pull — your branch is ahead of its upstream ($old)"
            exit 0
        fi
        fail "your branch and its upstream have diverged — not merging for you" \
            "look at: git -C $DOTS_DIR log --oneline --graph HEAD...@{u}"
    fi
    gitd merge --ff-only --quiet '@{u}' \
        || fail "git could not fast-forward (see its message above) — nothing was installed"
    if [[ "$(gitd rev-parse HEAD)" == "$before" ]]; then
        green "already up to date ($old) — nothing to install"
        yellow "  to re-apply the install anyway: scripts/install-fedora.sh"
        exit 0
    fi
    new="$(tr -d '[:space:]' <"$DOTS_DIR/VERSION")"
    green "updated $old -> $new ($(gitd rev-list --count "$before"..HEAD) commits)"

    blue "==> re-running the installer"
    exec "$DOTS_DIR/scripts/install-fedora.sh" "${args[@]}"
}

# Called last, so bash has parsed the whole file before running any of it:
# the merge above can replace this very script on disk.
main "$@"
