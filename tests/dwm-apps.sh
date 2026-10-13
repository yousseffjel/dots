#!/usr/bin/env bash
# Exercises config/dwm/bin/dwm-apps with a fake dmenu, a fake terminal and
# fixture .desktop files in a sandbox XDG tree, on a sealed PATH.
#
# What is asserted:
#   * the menu lists Type=Application entries by Name and nothing else:
#     NoDisplay, Hidden, Type=Link, OnlyShowIn for another desktop, NotShowIn
#     ours, a missing TryExec and a missing Exec are all left out;
#   * precedence: $XDG_DATA_HOME beats $XDG_DATA_DIRS for the same desktop-id
#     (renaming it, or hiding it with NoDisplay=true), a subdirectory's id is
#     path-with-dashes, and a [Desktop Action] group cannot overwrite the
#     main entry's Name/Exec;
#   * two entries with one Name are disambiguated by id;
#   * the picked entry runs its Exec with field codes stripped, quoting kept
#     and %% turned into %; Terminal=true goes through $TERMINAL -e; Path= is
#     the working directory;
#   * dmenu receives the caller's arguments (dwm passes -m and -fn);
#   * with DWM_APPS_EXTRA_DIRS unset, as dwm runs it, Flatpak exports under
#     $XDG_DATA_HOME are listed;
#   * Escape runs nothing and exits 0; an empty tree is exit 1.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SUT="$DOTS_DIR/config/dwm/bin/dwm-apps"
SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT
export SB

USER_APPS="$SB/home/.local/share/applications"
SYS_APPS="$SB/usr/share/applications"
mkdir -p "$USER_APPS" "$SYS_APPS/kde4" "$SB/workdir"

# entry <file> <body lines...> — writes a .desktop file.
entry() {
    local file="$1"
    shift
    printf '%s\n' "$@" >"$file"
}
entry "$SYS_APPS/editor.desktop" "[Desktop Entry]" "Type=Application" "Name=Editor" \
    "Exec=recorder editor --flag \"two words\" 100%% %U" \
    "[Desktop Action new]" "Name=New Window" "Exec=recorder wrong"
entry "$SYS_APPS/top.desktop" "[Desktop Entry]" "Type=Application" "Name=Top" \
    "Terminal=true" "Exec=recorder top"
entry "$SYS_APPS/inwork.desktop" "[Desktop Entry]" "Type=Application" "Name=In Work" \
    "Path=$SB/workdir" "Exec=sh -c 'pwd >\"\$SB/pwd.txt\"'"
entry "$SYS_APPS/renamed.desktop" "[Desktop Entry]" "Type=Application" "Name=System Name" "Exec=recorder sys"
entry "$USER_APPS/renamed.desktop" "[Desktop Entry]" "Type=Application" "Name=User Name" "Exec=recorder user"
entry "$SYS_APPS/masked.desktop" "[Desktop Entry]" "Type=Application" "Name=Masked" "Exec=recorder masked"
entry "$USER_APPS/masked.desktop" "[Desktop Entry]" "Type=Application" "Name=Masked" "NoDisplay=true" "Exec=x"
entry "$SYS_APPS/kde4/dup.desktop" "[Desktop Entry]" "Type=Application" "Name=Twin" "Exec=recorder kde"
entry "$SYS_APPS/dup.desktop" "[Desktop Entry]" "Type=Application" "Name=Twin" "Exec=recorder plain"
entry "$SYS_APPS/nodisplay.desktop" "[Desktop Entry]" "Type=Application" "Name=NoDisplayApp" "NoDisplay=true" "Exec=x"
entry "$SYS_APPS/hidden.desktop" "[Desktop Entry]" "Type=Application" "Name=HiddenApp" "Hidden=true" "Exec=x"
entry "$SYS_APPS/link.desktop" "[Desktop Entry]" "Type=Link" "Name=LinkEntry" "URL=https://example.org" "Exec=x"
entry "$SYS_APPS/gnome.desktop" "[Desktop Entry]" "Type=Application" "Name=GnomeOnly" "OnlyShowIn=GNOME;" "Exec=x"
entry "$SYS_APPS/notdots.desktop" "[Desktop Entry]" "Type=Application" "Name=NotHere" "NotShowIn=dots;" "Exec=x"
entry "$SYS_APPS/tryexec.desktop" "[Desktop Entry]" "Type=Application" "Name=TryMissing" "TryExec=no-such-binary" "Exec=x"
entry "$SYS_APPS/noexec.desktop" "[Desktop Entry]" "Type=Application" "Name=NoExec"

seal_path "$SB/real" awk cat grep find sort tr paste sh mkdir
mkdir -p "$SB/fake"
# The fake dmenu records its arguments and the menu, then answers with the
# line equal to $PICK — or exits 1, as dmenu does on Escape, when PICK is empty.
# shellcheck disable=SC2016
fake "$SB/fake" dmenu 'printf "%s\n" "$@" >"$SB/args.txt"; cat >"$SB/menu.txt"
[ -n "$PICK" ] || exit 1; grep -m1 -xF -- "$PICK" "$SB/menu.txt"'
# shellcheck disable=SC2016
fake "$SB/fake" recorder 'printf "%s\n" "$@" >"$SB/ran.txt"'
# shellcheck disable=SC2016
fake "$SB/fake" term 'printf "%s\n" "$@" >"$SB/term.txt"'
fake "$SB/fake" notify-send ':'

FAILS=0
check() {
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}

# pick <label> [data dirs] — runs the SUT; exit code in $RC.
pick() {
    rm -f "$SB"/{args,menu,ran,term,pwd}.txt
    RC=0
    PICK="$1" HOME="$SB/home" XDG_DATA_HOME="$SB/home/.local/share" \
        XDG_DATA_DIRS="${2:-$SB/usr/share}" XDG_CURRENT_DESKTOP=dots DWM_APPS_EXTRA_DIRS="" \
        TERMINAL=term PATH="$SB/fake:$SB/real" \
        "$(type -P bash)" "$SUT" -m 0 -fn "Mono:size=10" >/dev/null 2>&1 || RC=$?
}
listed() { grep -qxF -- "$1" "$SB/menu.txt"; }
absent() { ! grep -qF -- "$1" "$SB/menu.txt"; }
ran_is() { [[ "$(cat "$SB/ran.txt" 2>/dev/null)" == "$1" ]]; }

blue "the list"
pick ""
check "exactly six entries" test "$(wc -l <"$SB/menu.txt")" -eq 6
check "Editor listed by Name" listed "Editor"
check "Terminal=true entry listed" listed "Top"
for hidden in NoDisplayApp HiddenApp LinkEntry GnomeOnly NotHere TryMissing NoExec Masked "New Window"; do
    check "$hidden left out" absent "$hidden"
done
check "user copy renames the system entry" listed "User Name"
check "system copy of an overridden id is gone" absent "System Name"
check "same Name told apart by id (subdir id is kde4-dup)" listed "Twin (kde4-dup)"
check "... and the other" listed "Twin (dup)"
check "dmenu gets the caller's arguments after -i" \
    test "$(paste -sd' ' "$SB/args.txt")" = "-i -m 0 -fn Mono:size=10"

blue "launching"
pick "Editor"
check "exit 0" test "$RC" -eq 0
check "Exec run with quoting kept, %U dropped, %% -> %" \
    ran_is "$(printf '%s\n' editor --flag "two words" 100%)"
pick "User Name"
check "the user copy's Exec runs" ran_is "user"
pick "Twin (kde4-dup)"
check "the disambiguated entry runs its own Exec" ran_is "kde"
pick "Top"
check "Terminal=true goes through \$TERMINAL -e sh -c" \
    test "$(paste -sd'|' "$SB/term.txt" 2>/dev/null)" = "-e|sh|-c|recorder top"
pick "In Work"
check "Path= is the working directory" test "$(cat "$SB/pwd.txt" 2>/dev/null)" = "$SB/workdir"

blue "the Flatpak fallback, as dwm runs it"
# Every run above sets DWM_APPS_EXTRA_DIRS="" so the host's own Flatpak tree
# cannot leak in. dwm sets nothing, so prove the default once: an app exported
# under the sandbox's $XDG_DATA_HOME/flatpak is listed. Only presence is
# asserted — /var/lib/flatpak on this host may add entries of its own.
FP_APPS="$SB/home/.local/share/flatpak/exports/share/applications"
mkdir -p "$FP_APPS"
entry "$FP_APPS/org.example.Flat.desktop" "[Desktop Entry]" "Type=Application" "Name=Flat App" "Exec=recorder flat"
rm -f "$SB/menu.txt"
PICK="" HOME="$SB/home" XDG_DATA_HOME="$SB/home/.local/share" XDG_DATA_DIRS="$SB/usr/share" \
    PATH="$SB/fake:$SB/real" "$(type -P bash)" "$SUT" >/dev/null 2>&1 || true
check "an app exported to \$XDG_DATA_HOME/flatpak is listed by default" listed "Flat App"
rm -r "$SB/home/.local/share/flatpak"

blue "Escape and empty trees"
pick ""
check "Escape: exit 0" test "$RC" -eq 0
check "Escape: nothing ran" test ! -e "$SB/ran.txt"
mkdir -p "$SB/empty"
mv "$USER_APPS" "$SB/user-apps.off"
pick "Editor" "$SB/empty"
check "no .desktop files: exit 1" test "$RC" -eq 1

if [[ $FAILS -gt 0 ]]; then
    red "$FAILS check(s) failed"
    exit 1
fi
green "✓ dwm-apps"
