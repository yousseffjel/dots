#!/usr/bin/env bash
# 0.1.0 -> 0.2.0: refresh the suckless headers a build generated long ago.
#
# Run once by scripts/migrate.sh (install-void.sh calls it before the install
# stage, so the rebuild right after picks the result up). migrate.sh records
# the new version itself on success — this script never touches the manifest.
#
# WHY. `make` copies each suckless/<prog>/*.def.h to its generated header
# (config.h, or dwmblocks' blocks.h) ONCE and then leaves it alone, so an
# install keeps its first copy forever. 0.2.0 changed dwm's config.def.h (the
# drop-down terminal key, float rules) and dwmblocks' blocks.def.h (the DND
# block): an existing install would rebuild and silently miss all of it.
#
# WHAT, per generated header (scope G decision 1):
#   * absent, or already equal to its *.def.h  -> nothing to do;
#   * byte-identical to SOME past version of its *.def.h in git history
#     -> it was never edited: moved to <name>.pre-0.2.0, so the next build
#        regenerates it from the current *.def.h;
#   * anything else -> you edited it: KEPT, and the upstream changes since
#     0.1.0 are named for you to merge by hand;
#   * no git history to compare with (a tarball copy) -> reported, kept.
# Never deletes: the one write is a rename, and an existing backup is never
# overwritten. Idempotent — a re-run finds the header absent and moves on.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# The commit VERSION 0.1.0 was dated at (CHANGELOG [0.1.0]); 0.1.0 was never
# tagged, so this is the base the "changes to merge" are measured from.
BASE_COMMIT=d997704

git_ok() { git -C "$DOTS_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; }

# matches_history <generated> <def, repo-relative> — true when the generated
# header equals the *.def.h of any commit that touched it. Compared by git
# blob id (hash-object vs rev-parse <commit>:<path>): no file is streamed, and
# no tool beyond git (core.lst) — cmp would have pulled in diffutils.
matches_history() {
    local gen="$1" def="$2" want commit
    want="$(git -C "$DOTS_DIR" hash-object -- "$gen")"
    while read -r commit; do
        [[ "$(git -C "$DOTS_DIR" rev-parse -q --verify "$commit:$def" 2>/dev/null)" == "$want" ]] && return 0
    done < <(git -C "$DOTS_DIR" log --format=%H -- "$def" 2>/dev/null)
    return 1
}

# same_file <a> <b> — byte equality without cmp: git when there is a repo,
# else bash (which only loses trailing newlines, and only affects a message).
same_file() {
    if git_ok; then
        [[ "$(git -C "$DOTS_DIR" hash-object -- "$1")" == "$(git -C "$DOTS_DIR" hash-object -- "$2")" ]]
    else
        [[ "$(<"$1")" == "$(<"$2")" ]]
    fi
}

# report_edited <generated> <def, repo-relative>
report_edited() {
    yellow "kept    $1 — you edited it, so it was not regenerated."
    if git -C "$DOTS_DIR" cat-file -e "$BASE_COMMIT^{commit}" 2>/dev/null; then
        yellow "        Upstream changes since 0.1.0 to merge into it:"
        yellow "          git -C $DOTS_DIR diff $BASE_COMMIT HEAD -- $2"
    else
        yellow "        Compare it with the current default and merge by hand:"
        yellow "          diff -u $1 $DOTS_DIR/$2"
    fi
}

refreshed=0
for def_path in "$DOTS_DIR"/suckless/*/*.def.h; do
    gen="${def_path%.def.h}.h"
    def="${def_path#"$DOTS_DIR"/}"
    [[ -f "$gen" ]] || continue
    if same_file "$gen" "$def_path"; then
        green "ok      ${gen#"$DOTS_DIR"/} is already current"
    elif ! git_ok; then
        yellow "kept    ${gen#"$DOTS_DIR"/} differs from $def, and there is no git history to tell"
        yellow "        whether you edited it. To take the 0.2.0 defaults: rm it and rebuild."
    elif matches_history "$gen" "$def"; then
        if [[ -e "$gen.pre-0.2.0" ]]; then
            red "cannot refresh ${gen#"$DOTS_DIR"/}: $gen.pre-0.2.0 already exists — move one of them aside"
            exit 1
        fi
        mv "$gen" "$gen.pre-0.2.0"
        green "refresh ${gen#"$DOTS_DIR"/} (unedited) — the next build regenerates it; old copy: ${gen#"$DOTS_DIR"/}.pre-0.2.0"
        refreshed=1
    else
        report_edited "$gen" "$def"
    fi
done

if ((refreshed)); then
    blue "rebuild to pick up 0.2.0: install-void.sh / dots update does it next;"
    blue "  on its own: scripts/install-suckless.sh --skip-deps"
fi
