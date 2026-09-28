#!/usr/bin/env bash
# Exercises the four thin dmenu front ends in config/dwm/bin/: dwm-powermenu,
# dwm-clipmenu, dwm-theme and dwm-wallpaper. One file because each is small;
# the three with real logic (brightness, lock, screenshot) have their own.
#
# What is asserted:
#   * powermenu maps every entry to the right action, routes Lock through
#     dwm-lock (not slock), asks before reboot/shutdown and does nothing on
#     "no" or on Escape;
#   * powermenu and clipmenu pass NO colour flags (-nb/-nf/-sb/-sf) to dmenu,
#     which would override the X-resource theme;
#   * dwm-theme and dwm-wallpaper resolve the repo THROUGH a symlink (how
#     symlinks.sh deploys them: ~/.config/dwm/bin -> config/dwm/bin) and
#     forward their arguments verbatim; dwm-theme's menu lists wallbash first,
#     maps it to --wallbash, and exits quietly on Escape.
#
# SAFETY: dmenu, systemctl, pkill, clipmenu and dwm-lock are fakes on a
# sealed PATH (a real `systemctl poweroff` needs no explanation). dwm-theme
# and dwm-wallpaper run from a COPY of config/dwm/bin inside a throwaway tree
# whose scripts/theme/*.sh are fakes that record their arguments: the real
# ones drive the theming engine, whose post-commands pkill the tester's
# dunst and dwmblocks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

BIN_SRC="$DOTS_DIR/config/dwm/bin"
for s in dwm-powermenu dwm-clipmenu dwm-theme dwm-wallpaper; do
    [[ -f "$BIN_SRC/$s" ]] || {
        red "missing: $BIN_SRC/$s"
        exit 1
    }
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
LOG="$TMP/calls.log"
BIN="$TMP/bin"

rc=0
pass() { green "  ok: $1"; }
fail() {
    red "  FAIL: $1"
    rc=1
}
check() { # <description> <actual> <expected>
    if [[ "$2" == "$3" ]]; then pass "$1"; else fail "$1 — got [$2], want [$3]"; fi
}

seal_path "$BIN" bash cat readlink dirname
# dmenu logs its flags and the entries it was offered, then answers
# successive prompts from FAKE_MENU ("a|b"); "ESC" = Escape (exit 1).
fake "$BIN" dmenu "echo \"dmenu \$* <\$(tr '\n' ',' </dev/stdin)>\" >>'$LOG'
n=\$(cat '$TMP/menu.n' 2>/dev/null || echo 0); echo \$((n + 1)) >'$TMP/menu.n'
IFS='|' read -ra a <<<\"\${FAKE_MENU:-}\"; ans=\"\${a[\$n]:-ESC}\"; [[ \"\$ans\" == ESC ]] && exit 1; echo \"\$ans\""
seal_path "$BIN" tr
for t in systemctl pkill clipmenu dwm-lock; do
    fake "$BIN" "$t" "echo \"$t \$*\" >>'$LOG'"
done

# The throwaway repo: a copy of config/dwm/bin, fake engine scripts, and the
# symlink symlinks.sh would create.
REPO="$TMP/repo"
mkdir -p "$REPO/config/dwm" "$REPO/scripts/theme" "$TMP/home/.config/dwm"
cp -r "$BIN_SRC" "$REPO/config/dwm/bin"
fake "$REPO/scripts/theme" theme-apply.sh "[[ \"\${1:-}\" == --list ]] && { printf 'dark\nnord\n'; exit 0; }; echo \"theme-apply \$*\" >>'$LOG'"
fake "$REPO/scripts/theme" wallpaper.sh "echo \"wallpaper \$*\" >>'$LOG'"
ln -s "$REPO/config/dwm/bin" "$TMP/home/.config/dwm/bin"
DEPLOYED="$TMP/home/.config/dwm/bin"

# run <script path> [VAR=val...] -- <args...>; sets RC; fresh log + menu counter.
run() {
    local sut="$1" envs=()
    shift
    while [[ $# -gt 0 && "$1" != -- ]]; do
        envs+=("$1")
        shift
    done
    shift
    : >"$LOG"
    rm -f "$TMP/menu.n"
    RC=0
    env -i PATH="$BIN" "${envs[@]}" bash "$sut" "$@" >/dev/null 2>"$TMP/err" || RC=$?
}
actions() { grep -v '^dmenu ' "$LOG" | tr '\n' ';'; }

blue "==> dwm-powermenu"
P="$BIN_SRC/dwm-powermenu"
run "$P" FAKE_MENU=lock --
check "lock goes through dwm-lock" "$(actions)" "dwm-lock ;"
run "$P" FAKE_MENU=logout --
check "logout terminates dwm" "$(actions)" "pkill -TERM -x dwm;"
run "$P" FAKE_MENU=suspend --
check "suspend needs no confirmation" "$(actions)" "systemctl suspend;"
run "$P" 'FAKE_MENU=reboot|yes' --
check "reboot confirmed -> systemctl reboot" "$(actions)" "systemctl reboot;"
run "$P" 'FAKE_MENU=shutdown|yes' --
check "shutdown confirmed -> systemctl poweroff" "$(actions)" "systemctl poweroff;"
run "$P" 'FAKE_MENU=reboot|no' --
check "reboot answered no -> nothing" "$(actions)" ""
run "$P" 'FAKE_MENU=shutdown|ESC' --
check "Escape at the confirmation -> nothing" "$(actions)" ""
run "$P" FAKE_MENU=ESC --
if [[ $RC -eq 0 && -z "$(actions)" ]]; then pass "Escape at the menu: exit 0, nothing"; else fail "menu escape: rc=$RC"; fi
if grep -qE -- '-(nb|nf|sb|sf) ' "$LOG" 2>/dev/null; then fail "powermenu passes colour flags"; else pass "no -nb/-nf/-sb/-sf (the X-resource theme wins)"; fi
run "$P" FAKE_MENU=lock --
if grep -q '<lock,logout,suspend,reboot,shutdown,>' "$LOG"; then pass "offers exactly lock/logout/suspend/reboot/shutdown"; else fail "entries: $(cat "$LOG")"; fi

blue "==> dwm-clipmenu"
run "$BIN_SRC/dwm-clipmenu" --
check "execs clipmenu with -i and the font, no colour flags" "$(actions)" "clipmenu -i -fn monospace:size=10;"

blue "==> dwm-theme (through the deployed symlink)"
run "$DEPLOYED/dwm-theme" -- nord
check "arguments forwarded verbatim" "$(actions)" "theme-apply nord;"
run "$DEPLOYED/dwm-theme" FAKE_MENU=wallbash --
check "wallbash entry -> --wallbash" "$(actions)" "theme-apply --wallbash;"
if grep -q '<wallbash,dark,nord,>' "$LOG"; then pass "menu lists wallbash first, then theme-apply.sh --list"; else fail "theme menu: $(cat "$LOG")"; fi
run "$DEPLOYED/dwm-theme" FAKE_MENU=dark --
check "a listed theme is applied by name" "$(actions)" "theme-apply dark;"
run "$DEPLOYED/dwm-theme" FAKE_MENU=ESC --
if [[ $RC -eq 0 && -z "$(actions)" ]]; then pass "Escape: exit 0, nothing applied"; else fail "theme escape: rc=$RC"; fi

blue "==> dwm-wallpaper (through the deployed symlink)"
run "$DEPLOYED/dwm-wallpaper" -- --random
check "arguments forwarded to scripts/theme/wallpaper.sh" "$(actions)" "wallpaper --random;"

if ((rc != 0)); then
    red "✗ a dwm-* menu front end is broken"
    exit 1
fi
green "✓ dwm menus: powermenu, clipmenu, theme and wallpaper all dispatch correctly"
