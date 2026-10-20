#!/usr/bin/env bash
# dots update — bring an existing install up to the latest pushed version:
# pull the repo (fast-forward only), then re-run install-void.sh, which runs
# the migrations, installs any newly declared packages, rebuilds the suckless
# programs and prints any lines your own autostart.sh/.xinitrc still need.
#
#   update.sh               pull, then re-run the installer
#   update.sh --dry-run     fetch and list what would come in; change nothing
#   update.sh <args...>     pull, then pass <args> on to install-void.sh
#
# Refuses — before touching anything — a dirty tracked tree, a detached HEAD,
# a branch with no upstream, an upstream deleted on the remote, and an
# upstream that is not a fast-forward: each of those needs a decision this
# script must not make for you.
#
# "Up to date" means the INSTALL is, not just the checkout: the manifest
# records the commit the installer last ran from, and when that is not HEAD
# (a `git pull` done by hand — which is how every 0.1.0 install gets this
# script in the first place) the installer is re-run even with nothing to
# pull. The commit compared is the manifest's `complete` stamp, which only a
# full install-void.sh run writes, and only once every stage has finished:
# an install stopped partway (Ctrl-C, a failed stage) or a lone --only-<stage>
# run reads as stale and is re-run. DECISION REVERSAL (2026-10-13): this used
# to read the `commit` each stage stamps as it STARTS, so an interrupted
# install looked current.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/global_fn.sh
source "$SCRIPT_DIR/global_fn.sh"

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

# Refuse unless the current branch's upstream resolves. A branch still
# configured to track one the remote deleted (gone once a fetch pruned its
# remote-tracking ref) is told apart from a branch that never had one.
need_upstream() {
    local branch merge
    gitd rev-parse -q --verify '@{u}' >/dev/null 2>&1 && return 0
    branch="$(gitd symbolic-ref --short HEAD)"
    merge="$(gitd config "branch.$branch.merge" || true)"
    [[ -n "$merge" ]] \
        || fail "the current branch has no upstream to pull from" \
            "set one: git -C $DOTS_DIR branch --set-upstream-to=origin/main"
    fail "the branch '$branch' tracks '${merge#refs/heads/}', which no longer exists on the remote" \
        "switch to the main branch: git -C $DOTS_DIR switch main"
}

# Every refusal happens here, before the fetch, so a refused update has
# changed nothing at all. The one exception is an upstream deleted on the
# remote, which only the fetch's prune reveals (need_upstream runs again
# after it); a fetch touches no file in the checkout.
preflight() {
    gitd rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || fail "$DOTS_DIR is not a git checkout — dots update needs one" \
            "re-clone the repo, or update it by hand and run scripts/install-void.sh"
    gitd symbolic-ref -q HEAD >/dev/null \
        || fail "the repo is on a detached HEAD" "check out your branch first (git -C $DOTS_DIR switch main)"
    need_upstream
    [[ -z "$(gitd status --porcelain --untracked-files=no)" ]] \
        || fail "the repo has uncommitted changes to tracked files" \
            "commit or stash them first (git -C $DOTS_DIR status shows them)"
}

# 0 when the last FINISHED install ran from HEAD. A missing manifest, or a commit git
# cannot resolve (the installer writes "unknown" without git), is stale.
install_is_current() {
    local c
    c="$(manifest_get_meta complete)"
    [[ -n "$c" ]] || return 1
    [[ "$(gitd rev-parse -q --verify "$c^{commit}" 2>/dev/null)" == "$(gitd rev-parse HEAD)" ]]
}

stale_reason() {
    local c
    c="$(manifest_get_meta complete)"
    if [[ -z "$c" ]]; then
        echo "no finished install is recorded yet (the checkout is at $(gitd rev-parse --short HEAD))"
    else
        echo "the last finished install ran from $c, the checkout is at $(gitd rev-parse --short HEAD)"
    fi
}

run_installer() {
    blue "==> re-running the installer"
    exec "$DOTS_DIR/scripts/install-void.sh" "$@"
}

# Nothing was pulled: install only if the install is behind the checkout.
# $1 is what to say when it is not, $2 what to lead with when it is.
finish_unpulled() {
    local current="$1" stale="$2"
    shift 2
    if install_is_current; then
        green "$current"
        yellow "  to re-apply the install anyway: scripts/install-void.sh"
        exit 0
    fi
    yellow "$stale, but $(stale_reason)"
    run_installer "$@"
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
    # --prune, or a branch deleted on the remote (`void`, once the port
    # merged into main) keeps its stale remote-tracking ref and reads as
    # "nothing to pull" forever.
    gitd fetch --prune --quiet || fail "git fetch failed — check the network and the remote"
    need_upstream

    if ((dry)); then
        if [[ -n "$(gitd rev-list HEAD..'@{u}')" ]]; then
            blue "would bring in, then re-run the installer:"
            gitd log --oneline HEAD..'@{u}'
        elif install_is_current; then
            green "already up to date ($(tr -d '[:space:]' <"$DOTS_DIR/VERSION"))"
        else
            yellow "nothing to pull, but $(stale_reason) — would re-run the installer"
        fi
        exit 0
    fi

    old="$(tr -d '[:space:]' <"$DOTS_DIR/VERSION")"
    before="$(gitd rev-parse HEAD)"
    # Ahead-only and diverged are told apart before merging: a failed merge
    # can also mean an untracked file in the way, which needs its own hint.
    if ! gitd merge-base --is-ancestor HEAD '@{u}'; then
        if gitd merge-base --is-ancestor '@{u}' HEAD; then
            finish_unpulled "nothing to pull — your branch is ahead of its upstream ($old)" \
                "nothing to pull (your branch is ahead of its upstream)" "${args[@]}"
        fi
        fail "your branch and its upstream have diverged — not merging for you" \
            "look at: git -C $DOTS_DIR log --oneline --graph HEAD...@{u}"
    fi
    gitd merge --ff-only --quiet '@{u}' \
        || fail "git could not fast-forward (see its message above) — nothing was installed"
    if [[ "$(gitd rev-parse HEAD)" == "$before" ]]; then
        finish_unpulled "already up to date ($old) — nothing to install" "nothing to pull" "${args[@]}"
    fi
    new="$(tr -d '[:space:]' <"$DOTS_DIR/VERSION")"
    green "updated $old -> $new ($(gitd rev-list --count "$before"..HEAD) commits)"
    run_installer "${args[@]}"
}

# Called last, so bash has parsed the whole file before running any of it:
# the merge above can replace this very script on disk.
main "$@"
