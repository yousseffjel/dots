#!/usr/bin/env bash
# Guards the `dots` dispatcher (scripts/dots) and the symlink deploy that puts
# it on $PATH (restore_dots_bin in scripts/install-restore-bin.sh).
#
# WHY THIS TEST EXISTS. Two failure modes, neither of which any existing check
# would catch:
#
#   1. The dispatcher is reached through a SYMLINK at ~/.local/bin/dots. This
#      repo's usual SCRIPT_DIR idiom (`cd "$(dirname "${BASH_SOURCE[0]}")"`,
#      rule 3) resolves the symlink's DIRECTORY, not the link — so under that
#      idiom every subcommand would look for the repo inside ~/.local/bin and
#      nothing would run. It is correct only because scripts/dots deliberately
#      departs from rule 3 with readlink -f, and only an invocation through a
#      real symlink proves it.
#
#   2. ~/.local/bin precedes ~/.config/dwm/bin on PATH (config/zsh/.zshenv), so
#      a file dropped there shadows the dwm-* controls. The deploy must claim
#      exactly one name, and must never claim — or delete — a `dots` that
#      belongs to someone else. A SCRIPT manifest row is what authorises
#      uninstall.sh to remove a path, so claiming a foreign file is the one
#      unrecoverable mistake available here.
#
# Subcommands are never enumerated below. They are read back out of
# `dots --help`, which renders them from the SUBCOMMANDS table in scripts/dots
# — the single declaration. A hardcoded list here would be the fourth copy of
# something this repo already declares once, and every hand-written list in
# this repo has gone stale at least once.

set -euo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$TEST_DIR/.." && pwd)"
# install-restore-bin.sh resolves the dispatcher as "$SCRIPT_DIR/dots", so this
# must be the scripts dir, not this test's own directory.
SCRIPT_DIR="$DOTS_DIR/scripts"
DOTS="$SCRIPT_DIR/dots"

if [[ ! -x "$DOTS" ]]; then
    printf '\033[31mmissing or not executable: %s\033[0m\n' "$DOTS"
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Every XDG variable, not just HOME: MANIFEST_DIR derives from XDG_STATE_HOME,
# so a HOME-only sandbox would write into the real install manifest that
# uninstall.sh acts on.
export HOME="$TMP/home"
export XDG_CONFIG_HOME="$TMP/home/.config"
export XDG_DATA_HOME="$TMP/home/.local/share"
export XDG_CACHE_HOME="$TMP/home/.cache"
export XDG_STATE_HOME="$TMP/home/.local/state"
mkdir -p "$HOME"

# global_fn.sh supplies red/green/yellow/blue, so this file deliberately does
# NOT define its own — local copies would be overwritten here and become dead
# code (SC2329). Same exemption from rule 2 as tests/manifest-has-path.sh.
# shellcheck source=../scripts/global_fn.sh
source "$SCRIPT_DIR/global_fn.sh"

rc=0

# Assertion helpers rather than `cmd && pass || fail`: in that idiom a failing
# `pass` runs `fail` too (SC2015), so a green suite could hide a broken
# reporter.
assert_exit() {
    local desc="$1" want="$2"
    shift 2
    local got=0
    "$@" >/dev/null 2>&1 || got=$?
    if [[ "$got" -eq "$want" ]]; then
        green "  ok: $desc"
    else
        red "  FAIL: $desc (wanted exit $want, got $got)"
        rc=1
    fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        green "  ok: $desc"
    else
        red "  FAIL: $desc (no '$needle' in: $haystack)"
        rc=1
    fi
}

assert_missing() {
    local desc="$1" path="$2"
    if [[ -e "$path" || -L "$path" ]]; then
        red "  FAIL: $desc ($path exists)"
        rc=1
    else
        green "  ok: $desc"
    fi
}

blue "==> dispatcher entry points"

assert_exit "no subcommand exits 1" 1 "$DOTS"
assert_exit "--help exits 0" 0 "$DOTS" --help
assert_exit "unknown subcommand exits 1" 1 "$DOTS" frobnicate

help_out="$("$DOTS" --help 2>&1)"
assert_contains "help names the command" "usage: dots <subcommand>" "$help_out"

# --- every declared subcommand actually resolves ------------------------------
#
# Read from the shipped table via --help, then RUN each one. This proves the
# table's paths exist and are executable, which parsing the array would not.
mapfile -t SUBS < <(printf '%s\n' "$help_out" \
    | sed -n 's/^  \([a-z][a-z-]*\)  *.*/\1/p')

if [[ ${#SUBS[@]} -eq 0 ]]; then
    red "  FAIL: no subcommands parsed out of --help"
    rc=1
else
    green "  ok: --help declares ${#SUBS[@]} subcommand(s): ${SUBS[*]}"
fi

blue "==> each declared subcommand resolves and forwards --help"
for sub in "${SUBS[@]}"; do
    assert_exit "dots $sub --help exits 0" 0 "$DOTS" "$sub" --help
    # DOTS_CMD swap: help must name how it was invoked, not the script's own
    # filename. Without this the dispatcher tells users to run "version.sh".
    sub_help="$("$DOTS" "$sub" --help 2>&1)"
    assert_contains "dots $sub --help says 'dots $sub'" "dots $sub" "$sub_help"
done

blue "==> direct invocation is unchanged"
# The swap must be conditional: running a script directly still names itself.
direct="$("$SCRIPT_DIR/version.sh" --help 2>&1)"
assert_contains "version.sh --help still says version.sh" "version.sh" "$direct"

blue "==> arguments are forwarded verbatim"
json="$("$DOTS" version --json 2>&1)"
assert_contains "dots version --json emits JSON" '"repo_version"' "$json"

blue "==> invocation through a symlink resolves the repo"
# The reason scripts/dots departs from rule 3. Under the plain SCRIPT_DIR idiom
# this case finds no repo and every subcommand dies.
mkdir -p "$TMP/fakebin"
ln -s "$DOTS" "$TMP/fakebin/dots"
assert_exit "symlinked dots --help exits 0" 0 "$TMP/fakebin/dots" --help
linked_json="$("$TMP/fakebin/dots" version --json 2>&1)"
assert_contains "symlinked dots reaches the repo" '"repo_version"' "$linked_json"

# --- the deploy ---------------------------------------------------------------

# shellcheck source=../scripts/install-restore-bin.sh
source "$SCRIPT_DIR/install-restore-bin.sh"

BIN="$HOME/.local/bin/dots"

blue "==> restore_dots_bin: dry-run touches nothing"
DRY_RUN=1 restore_dots_bin >/dev/null 2>&1
assert_missing "dry-run created no symlink" "$BIN"

blue "==> restore_dots_bin: fresh deploy"
DRY_RUN=0 restore_dots_bin >/dev/null 2>&1
if [[ -L "$BIN" && "$(readlink "$BIN")" == "$DOTS" ]]; then
    green "  ok: symlink points at scripts/dots"
else
    red "  FAIL: symlink missing or wrong target"
    rc=1
fi
if manifest_has_path SCRIPT "$BIN"; then
    green "  ok: deploy recorded a SCRIPT row"
else
    red "  FAIL: no SCRIPT row — uninstall.sh could not remove it"
    rc=1
fi

blue "==> restore_dots_bin: re-run is idempotent"
DRY_RUN=0 restore_dots_bin >/dev/null 2>&1
DRY_RUN=0 restore_dots_bin >/dev/null 2>&1
rows="$(manifest_rows SCRIPT | grep -c "$BIN" || true)"
if [[ "$rows" -eq 1 ]]; then
    green "  ok: exactly one SCRIPT row after three runs"
else
    red "  FAIL: $rows SCRIPT rows for $BIN (rule 1: re-running must not duplicate)"
    rc=1
fi

blue "==> restore_dots_bin: a foreign file is neither clobbered nor claimed"
rm -rf "$HOME/.local" "$XDG_STATE_HOME"
mkdir -p "$(dirname "$BIN")"
printf 'not ours\n' >"$BIN"
DRY_RUN=0 restore_dots_bin >/dev/null 2>&1
if [[ "$(cat "$BIN")" == "not ours" ]]; then
    green "  ok: foreign file left untouched"
else
    red "  FAIL: foreign file was overwritten"
    rc=1
fi
if manifest_has_path SCRIPT "$BIN"; then
    red "  FAIL: foreign file was claimed — uninstall.sh would delete it"
    rc=1
else
    green "  ok: foreign file not claimed in the manifest"
fi

if [[ $rc -eq 0 ]]; then
    green "dots-dispatch: PASS"
else
    red "dots-dispatch: FAIL"
fi
exit $rc
