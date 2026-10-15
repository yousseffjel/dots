#!/usr/bin/env bash
# Exercises scripts/update.sh (`dots update`) against throwaway git repos — a
# bare "origin" and an "install" clone holding the real update.sh beside a
# stub install-void.sh that only records its arguments.
#
# What is asserted:
#   * new commits upstream: fast-forwarded, then the installer runs with the
#     caller's arguments passed through;
#   * already up to date: the installer does NOT run;
#   * --dry-run lists what would come in and changes nothing;
#   * refused, with HEAD untouched: dirty tracked files, a detached HEAD, no
#     upstream, a diverged branch;
#   * a branch that is only AHEAD has nothing to pull — exit 0, not "diverged";
#   * a checkout pulled BY HAND (how a 0.1.0 install gets update.sh at all)
#     has nothing to pull but an install from an older commit: the installer
#     runs, and --dry-run says it would. So does a missing manifest;
#   * an install stopped partway (`commit` stamped, `complete` not) and a lone
#     --only-<stage> run (`complete` older than `commit`) both read as stale.
# shellcheck disable=SC2016 # the bash -c bodies take $1/$2 as their own arguments
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

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

ORIGIN="$TMP/origin.git"
INST="$TMP/install"
DEV="$TMP/dev"
LOG="$TMP/installer.log"
MANIFEST="$TMP/.local/state/dots/manifest"
g() { git -C "$1" -c user.name=t -c user.email=t@t -c commit.gpgsign=false "${@:2}" >/dev/null 2>&1; }

# A fresh origin with one commit, cloned as the "install". The stub installer
# stamps the manifest the way a FINISHED full run does: `commit` (each stage,
# as it starts) and `complete` (install-void.sh, once every stage is done).
mkrepos() {
    rm -rf "$ORIGIN" "$INST" "$DEV" "$LOG" "$MANIFEST"
    git init -q --bare -b main "$ORIGIN"
    git clone -q "$ORIGIN" "$DEV" 2>/dev/null
    mkdir -p "$DEV/scripts"
    cp "$DOTS_DIR/scripts/update.sh" "$DOTS_DIR/scripts/global_fn.sh" "$DEV/scripts/"
    cat >"$DEV/scripts/install-void.sh" <<EOF
#!/bin/sh
echo "installer \$*" >>"$LOG"
d="\$HOME/.local/state/dots"
mkdir -p "\$d"
c="\$(git -C "\$(dirname "\$0")/.." rev-parse --short HEAD)"
printf 'META\tcommit\t%s\nMETA\tcomplete\t%s\n' "\$c" "\$c" >"\$d/manifest"
EOF
    chmod 755 "$DEV/scripts/install-void.sh"
    echo 0.1.0 >"$DEV/VERSION"
    g "$DEV" add -A
    g "$DEV" commit -qm one
    g "$DEV" push -q origin HEAD:main
    git clone -q "$ORIGIN" "$INST" 2>/dev/null
}
# upstream <version> — a new commit pushed from the dev clone.
upstream() {
    echo "$1" >"$DEV/VERSION"
    g "$DEV" commit -qam "to $1"
    g "$DEV" push -q origin HEAD:main
}
update() {
    RC=0
    OUT="$(env -i PATH="/usr/bin:/bin" HOME="$TMP" bash "$INST/scripts/update.sh" "$@" 2>&1)" || RC=$?
}
head_is() { [[ "$(git -C "$INST" rev-parse HEAD)" == "$1" ]]; }

blue "==> an update"
mkrepos
upstream 0.2.0
update --skip-suckless
check "exit 0" test "$RC" -eq 0
check "fast-forwarded to 0.2.0" grep -qx 0.2.0 "$INST/VERSION"
check "reports the version change" grep -q 'updated 0.1.0 -> 0.2.0' <<<"$OUT"
check "the installer ran, with the argument passed through" grep -qx 'installer --skip-suckless' "$LOG"

blue "==> nothing new"
rm -f "$LOG"
update
check "exit 0" test "$RC" -eq 0
check "the installer did NOT run" test ! -e "$LOG"
check "says so" grep -q 'already up to date' <<<"$OUT"

blue "==> pulled by hand: nothing to pull, but the install is older"
upstream 0.2.1
g "$INST" pull -q --ff-only
update --dry-run
check "--dry-run: names both commits and says it would install" \
    bash -c '[[ $1 == 0 && $2 == *"nothing to pull"*"would re-run the installer"* ]]' _ "$RC" "$OUT"
check "--dry-run: installer not run" test ! -e "$LOG"
update --skip-suckless
check "exit 0" test "$RC" -eq 0
check "says why" grep -q "nothing to pull, but the last finished install ran from .*, the checkout is at $(git -C "$INST" rev-parse --short HEAD)" <<<"$OUT"
check "the installer ran, with the argument passed through" grep -qx 'installer --skip-suckless' "$LOG"
rm -f "$LOG"
update
check "and afterwards it is up to date: installer NOT run" test ! -e "$LOG"
rm -f "$MANIFEST"
update
check "no manifest at all: the installer runs" bash -c '[[ $1 == 0 && $2 == *"no finished install is recorded yet"* ]] && test -e "$3"' _ "$RC" "$OUT" "$LOG"
rm -f "$LOG"

blue "==> an install that never finished"
head_short="$(git -C "$INST" rev-parse --short HEAD)"
# What a Ctrl-C during the package stage leaves: the stages that started
# stamped `commit`; install-void.sh never reached its `complete` stamp.
printf 'META\tcommit\t%s\n' "$head_short" >"$MANIFEST"
update
check "interrupted (commit stamped, no complete): the installer runs" \
    bash -c '[[ $1 == 0 && $2 == *"no finished install is recorded yet"* ]] && test -e "$3"' _ "$RC" "$OUT" "$LOG"
rm -f "$LOG"
# What `install-void.sh --only-restore` after an older full run leaves.
printf 'META\tcommit\t%s\nMETA\tcomplete\t%s\n' "$head_short" "$(git -C "$INST" rev-parse --short HEAD~1)" >"$MANIFEST"
update
check "a lone --only run on top of an older full one: the installer runs" test -e "$LOG"
rm -f "$LOG"

blue "==> --dry-run"
upstream 0.3.0
before="$(git -C "$INST" rev-parse HEAD)"
update --dry-run
check "lists the incoming commit" grep -q 'to 0.3.0' <<<"$OUT"
check "HEAD untouched" head_is "$before"
check "installer not run" test ! -e "$LOG"

blue "==> refusals leave HEAD where it was"
# A dirty file upstream does NOT touch: git itself would happily merge over
# it, so only update.sh's own check can stop this (a first draft dirtied
# VERSION, which upstream changes too, and git's refusal hid a missing check).
echo '# local edit' >>"$INST/scripts/install-void.sh"
update
check "dirty tracked file: exit 1, naming the reason" bash -c '[[ $1 == 1 && $2 == *"uncommitted changes"* ]]' _ "$RC" "$OUT"
check "...HEAD untouched" head_is "$before"
check "...installer not run" test ! -e "$LOG"
git -C "$INST" checkout -q -- scripts/install-void.sh
g "$INST" checkout -q --detach
update
check "detached HEAD: exit 1" bash -c '[[ $1 == 1 && $2 == *detached* ]]' _ "$RC" "$OUT"
g "$INST" checkout -q main
g "$INST" branch -q --unset-upstream
update
check "no upstream: exit 1" bash -c '[[ $1 == 1 && $2 == *"no upstream"* ]]' _ "$RC" "$OUT"
g "$INST" branch -q --set-upstream-to=origin/main
g "$INST" merge -q --ff-only origin/main
echo ahead >"$INST/ahead.txt"
g "$INST" add ahead.txt
g "$INST" commit -qm ahead
update
check "only ahead of upstream: exit 0, nothing pulled, not called diverged" \
    bash -c '[[ $1 == 0 && $2 == *ahead* && $2 != *diverged* ]]' _ "$RC" "$OUT"
check "...but the local commit was never installed, so the installer ran" test -e "$LOG"
rm -f "$LOG"
update
check "...and a second run installs nothing" bash -c '[[ $1 == 0 && $2 == *ahead* ]] && test ! -e "$3"' _ "$RC" "$OUT" "$LOG"
upstream 0.4.0
echo local >"$INST/local.txt"
g "$INST" add local.txt
g "$INST" commit -qm local
diverged="$(git -C "$INST" rev-parse HEAD)"
update
check "diverged: exit 1" bash -c '[[ $1 == 1 && $2 == *diverged* ]]' _ "$RC" "$OUT"
check "...HEAD untouched" head_is "$diverged"
check "...installer never ran" test ! -e "$LOG"

if ((rc != 0)); then
    red "✗ dots update"
    exit 1
fi
green "✓ dots update: fast-forward + installer, a stale install re-installed, refusals change nothing"
