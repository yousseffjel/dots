#!/usr/bin/env bash
# The wallpaper collection: install-restore-wallpapers.sh clones it,
# fast-forwards it on a re-run, leaves a directory it did not make alone;
# uninstall-wallpapers.sh removes it only while git can prove it unchanged;
# wallpaper.sh's --initial and --login-random behave as ~/.xinitrc expects.
#
# HOW. The shipped functions run in an `env -i` bash with all four XDG
# variables pointed into a sandbox HOME (a HOME-only sandbox leaks into the
# real manifest), cloning from a local bare fixture repo over file:// (so
# --depth=1 is honoured as it is for the real https URL) — never the network.
# wallpaper.sh is run only on paths that exit before feh/colorgen/reload: the
# theming engine's post-commands act on the live desktop.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

rc=0
ok() { green "  ok: $1"; }
bad() {
    red "  FAIL: $1"
    rc=1
}
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
GIT=(git -c user.name=t -c user.email=t@t -c commit.gpgsign=false)
WORK="$TMP/work"
FIXTURE="$TMP/fixture.git"
mkdir -p "$WORK"
printf 'one\n' >"$WORK/nature-one.png"
"${GIT[@]}" -C "$WORK" init -q -b main
"${GIT[@]}" -C "$WORK" add . && "${GIT[@]}" -C "$WORK" commit -qm one
git clone -q --bare "$WORK" "$FIXTURE"

# <home> <bash code>, with the restore/uninstall functions and their helpers
# loaded the way install-restore.sh and uninstall.sh load them.
sandbox() {
    local home="$1"
    shift
    mkdir -p "$home"
    # The $1/$2 belong to the inner bash, not to this function.
    # shellcheck disable=SC2016
    env -i PATH="$PATH" HOME="$home" LANG=C.UTF-8 \
        XDG_CONFIG_HOME="$home/.config" XDG_CACHE_HOME="$home/.cache" \
        XDG_STATE_HOME="$home/.local/state" XDG_DATA_HOME="$home/.local/share" \
        DOTS_WALLPAPER_REPO="${REPO-file://$FIXTURE}" DRY_RUN="${DRY:-0}" ASSUME_YES=1 \
        bash -c 'set -euo pipefail
            source "$1/scripts/global_fn.sh"
            source "$1/config/dwm/bin/dwm-lib-xdg.sh"
            source "$1/scripts/install-restore-wallpapers.sh"
            source "$1/scripts/uninstall-wallpapers.sh"
            eval "$2"' _ "$DOTS_DIR" "$*"
}
clone_of() { printf '%s/Pictures/wallpapers/dots' "$1"; }
rows() {
    local m="$1/.local/state/dots/manifest"
    if [[ -f "$m" ]]; then grep -c '^WALLPAPERS	' "$m" || true; else echo 0; fi
}

blue "==> restore"
H="$TMP/fresh"
sandbox "$H" restore_wallpapers >/dev/null
C="$(clone_of "$H")"
check "clones the collection into <pictures>/wallpapers/dots" "[[ -f '$C/nature-one.png' ]]"
check "claims it with exactly one WALLPAPERS row" "[[ \$(rows '$H') == 1 ]]"
check "the row records the top-most directory it created (~/Pictures)" \
    "grep -qF \"WALLPAPERS	file://$FIXTURE	$C	$H/Pictures\" '$H/.local/state/dots/manifest'"

printf 'two\n' >"$WORK/city-two.png"
"${GIT[@]}" -C "$WORK" add . && "${GIT[@]}" -C "$WORK" commit -qm two
"${GIT[@]}" -C "$WORK" push -q "$FIXTURE" main
sandbox "$H" restore_wallpapers >/dev/null
check "a re-run (dots update) fast-forwards the clone" "[[ -f '$C/city-two.png' ]]"
check "a re-run claims nothing new" "[[ \$(rows '$H') == 1 ]]"

F="$TMP/foreign"
mkdir -p "$(clone_of "$F")" && printf 'mine\n' >"$(clone_of "$F")/mine.png"
out="$(sandbox "$F" restore_wallpapers)"
check "a directory it did not make is left alone, unclaimed" \
    "[[ \$(ls '$(clone_of "$F")') == mine.png && \$(rows '$F') == 0 && '$out' == *'not ours'* ]]"

out="$(REPO='' sandbox "$TMP/off" restore_wallpapers)"
check "DOTS_WALLPAPER_REPO= skips the download" \
    "[[ ! -e '$TMP/off/Pictures' && \$(rows '$TMP/off') == 0 && '$out' == *'is empty'* ]]"
DRY=1 sandbox "$TMP/dry" restore_wallpapers >/dev/null
check "--dry-run creates nothing" "[[ ! -e '$TMP/dry/Pictures' && ! -e '$TMP/dry/.local' ]]"
REPO="file://$TMP/no-such.git" sandbox "$TMP/nonet" restore_wallpapers >/dev/null 2>&1
check "a failed clone leaves no directory and no row behind" \
    "[[ ! -e '$TMP/nonet/Pictures' && \$(rows '$TMP/nonet') == 0 ]]"

# Progress goes to the terminal, never to stdout/stderr — the streams
# install-void.sh tees into install.log. `script` provides the terminal.
if command -v script >/dev/null 2>&1; then
    P="$TMP/progress"
    mkdir -p "$P"
    script -qec "bash -c 'source \"$DOTS_DIR/scripts/install-restore-wallpapers.sh\";
        wallpapers_git_clone \"file://$FIXTURE\" \"$P/clone\"' >'$P/out' 2>'$P/err'" "$P/tty" >/dev/null
    check "with a terminal, git's progress reaches it" "grep -q 'Receiving objects' '$P/tty'"
    check "...and none of it reaches the logged streams" \
        "[[ -d '$P/clone/.git' ]] && ! grep -q 'Receiving objects' '$P/out' '$P/err'"
else
    blue "  skip: no script(1) — the terminal path is untested here"
fi
# shellcheck disable=SC2016 # $1-$3 belong to the inner bash
out="$(setsid bash -c 'source "$1/scripts/install-restore-wallpapers.sh"; wallpapers_git_clone "file://$2" "$3"' \
    _ "$DOTS_DIR" "$FIXTURE" "$TMP/notty" 2>&1 </dev/null)"
check "with no terminal, the clone is quiet" "[[ -d '$TMP/notty/.git' && -z '$out' ]]"

blue "==> uninstall"
sandbox "$H" uninstall_wallpapers >/dev/null
check "an unchanged clone is removed, and the ~/Pictures it created with it" "[[ ! -e '$H/Pictures' ]]"

for case in untracked commit origin; do
    U="$TMP/keep-$case"
    sandbox "$U" restore_wallpapers >/dev/null
    C="$(clone_of "$U")"
    case "$case" in
        untracked) printf 'theirs\n' >"$C/my-own.png" ;;
        commit) "${GIT[@]}" -C "$C" commit -q --allow-empty -m local ;;
        origin) git -C "$C" remote set-url origin "$TMP/elsewhere.git" ;;
    esac
    out="$(sandbox "$U" uninstall_wallpapers)"
    check "a clone with $case changes is kept whole" "[[ -d '$C/.git' && '$out' == *kept* ]]"
done

blue "==> wallpaper.sh --initial / --login-random"
W="$TMP/wall"
mkdir -p "$W"
wall() {
    env -i PATH="$PATH" HOME="$W" XDG_CONFIG_HOME="$W/.config" XDG_CACHE_HOME="$W/.cache" \
        bash "$DOTS_DIR/scripts/theme/wallpaper.sh" "$@"
}
out="$(wall --initial)"
check "--initial with no collection exits 0 and sets nothing" \
    "[[ '$out' == *'no wallpaper collection'* && ! -e '$W/.fehbg' ]]"
check "--login-random defaults to off" "[[ \$(wall --login-random status) == off ]]"
out="$(wall --login-random on)"
check "--login-random on writes the flag ~/.xinitrc tests" "[[ -e '$W/.config/dots/random-wallpaper' ]]"
check "... and, with no ~/.xinitrc that reads it, prints the paste lines" "[[ '$out' == *'Replace its ~/.fehbg line'* ]]"
check "--login-random status reads it back" "[[ \$(wall --login-random status) == on ]]"
wall --login-random off >/dev/null
check "--login-random off removes it" "[[ ! -e '$W/.config/dots/random-wallpaper' ]]"
check "--login-random rejects anything else" "! wall --login-random maybe >/dev/null 2>&1"

# The paste lines and the template must stay the same code: compare them
# trimmed, line by line.
# shellcheck source=../scripts/install-session.sh
source "$DOTS_DIR/scripts/install-session.sh"
# docs/THEMING.md carries the same three lines for existing installs.
template="$(session_xinitrc_template | sed 's/^[[:space:]]*//')"
theming="$(sed 's/^[[:space:]]*//' "$DOTS_DIR/docs/THEMING.md")"
missing=0
while IFS= read -r line; do
    grep -qxF -- "$line" <<<"$template" || missing=1
    grep -qxF -- "$line" <<<"$theming" || missing=1
done < <(sed -n "/^login_random_hint()/,/^}/s/^ *yellow '  *\(.*\)'$/\1/p" "$DOTS_DIR/scripts/theme/wallpaper.sh")
hint_lines="$(sed -n "/^login_random_hint()/,/^}/s/^ *yellow '  *\(.*\)'$/\1/p" "$DOTS_DIR/scripts/theme/wallpaper.sh" | wc -l)"
check "the $hint_lines paste-hint lines are the template's own, and THEMING.md's" "[[ $missing == 0 && $hint_lines == 3 ]]"

if ((rc != 0)); then
    red "✗ wallpaper collection"
    exit 1
fi
green "✓ wallpaper collection: clone, refresh, keep-if-changed uninstall, login flag"
