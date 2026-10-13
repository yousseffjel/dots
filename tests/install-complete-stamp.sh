#!/usr/bin/env bash
# install-fedora.sh writes the manifest's `complete` stamp — the one
# `dots update` compares against HEAD — only when a FULL run reaches its end.
#
# WHY. Every stage stamps `commit` as it starts, so a run stopped partway
# (Ctrl-C in the package stage, on the Fedora VM, 2026-10-13) used to read as
# current, and `dots update` then refused to finish it. tests/dots-update.sh
# covers update.sh's side with a stub installer; this covers the real
# orchestrator's side.
#
# HOW. The real install-fedora.sh and global_fn.sh run in a copied tree whose
# stage scripts are stubs (each records its name; one can be told to fail),
# against a sandbox HOME with all four XDG variables set.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

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

TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
TREE="$TMP/dots"
mkdir -p "$TREE/scripts"
cp "$DOTS_DIR/scripts/install-fedora.sh" "$DOTS_DIR/scripts/global_fn.sh" "$TREE/scripts/"
for stage in install-pre install-pkg install-suckless install-restore install-services migrate; do
    # Each stub records its own name; the one named in $FAIL_STAGE fails.
    # shellcheck disable=SC2016 # expands when the stub runs
    printf '#!/usr/bin/env bash\necho "%s" >>"$HOME/stages"\n[[ "${FAIL_STAGE:-}" != "%s" ]]\n' \
        "$stage" "$stage" >"$TREE/scripts/$stage.sh"
    chmod 755 "$TREE/scripts/$stage.sh"
done
git -C "$TREE" init -q -b main
git -C "$TREE" -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q --allow-empty -m tree
HEAD_SHORT="$(git -C "$TREE" rev-parse --short HEAD)"

# <case> [args...] — runs the installer in a fresh sandbox HOME; prints the
# `complete` stamp afterwards (empty when there is none).
run() {
    local home="$TMP/$1"
    shift
    mkdir -p "$home"
    env -i PATH="$PATH" HOME="$home" LANG=C.UTF-8 FAIL_STAGE="${FAIL_STAGE:-}" \
        XDG_CONFIG_HOME="$home/.config" XDG_CACHE_HOME="$home/.cache" \
        XDG_STATE_HOME="$home/.local/state" XDG_DATA_HOME="$home/.local/share" \
        bash "$TREE/scripts/install-fedora.sh" "$@" >"$home/out" 2>&1 || true
    awk -F'\t' '$1=="META" && $2=="complete" {print $3}' "$home/.local/state/dots/manifest" 2>/dev/null || true
}

blue "==> the complete stamp"
check "a full run that finishes stamps complete = HEAD" test "$(run full)" == "$HEAD_SHORT"
check "...after running every stage" \
    test "$(tr '\n' ' ' <"$TMP/full/stages")" == "install-pre migrate install-pkg install-suckless install-restore install-services "
check "--skip-suckless is still a finished full run" test "$(run skip --skip-suckless)" == "$HEAD_SHORT"
check "--only-restore does not stamp it" test -z "$(run only --only-restore)"
check "--dry-run does not stamp it" test -z "$(run dry --dry-run)"
check "a stage that fails stops the run before the stamp" test -z "$(FAIL_STAGE=install-pkg run failed)"
# shellcheck disable=SC2016 # $1 belongs to the inner bash
check "...and the stages after it never ran" bash -c '! grep -q install-restore "$1"' _ "$TMP/failed/stages"

if ((rc != 0)); then
    red "✗ install complete stamp"
    exit 1
fi
green "✓ install complete stamp: only a finished full run writes it"
