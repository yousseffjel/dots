#!/usr/bin/env bash
# Runs install-services.sh against a sandbox where zsh is reachable through a
# symlinked sbin dir, and asserts which path it records as the login shell.
#
# WHY. Since Fedora 42 /usr/sbin is a symlink to /usr/bin, and a PATH with
# sbin first finds /usr/sbin/zsh. The first real install (Fedora 44 VM,
# 2026-10-05) recorded that spelling in passwd and /etc/shells. Worse, shells
# were compared as strings, so a later run under a bin-first PATH ran usermod
# again and appended a SHELL row whose "previous shell" was zsh — and
# uninstall restores the LAST row. The stage now resolves zsh's directory
# physically and compares shells by identity.
#
# HOW. PATH is sealed: fakes first (sudo, usermod, getent, tee), then the
# sandbox's sbin -> bin pair, then links to the few real tools the stage
# needs. usermod, tee and sudo are all fakes, so nothing reaches passwd or
# /etc/shells even when this runs as root. ly, rpm and systemctl are absent,
# so the display-manager half of the stage skips itself.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

# shellcheck source=lib/sealed-path.sh
source "$SCRIPT_DIR/lib/sealed-path.sh"

SB="$(mktemp -d)"
trap 'rm -rf "$SB"' EXIT

mkdir -p "$SB/root/usr/bin"
ln -s bin "$SB/root/usr/sbin"
printf '#!/bin/sh\nexit 0\n' >"$SB/root/usr/bin/zsh"
chmod 755 "$SB/root/usr/bin/zsh"
CANON="$(cd "$SB/root/usr/bin" && pwd -P)/zsh"
SBIN_ZSH="$SB/root/usr/sbin/zsh"
seal_path "$SB/real" dirname tr cut grep date mkdir touch mktemp awk mv cat

FAILS=0
check() { # check <description> <command...>
    local what="$1"
    shift
    if "$@"; then green "  ok    $what"; else
        red "  FAIL  $what"
        FAILS=$((FAILS + 1))
    fi
}

# run_case <name> <current shell> [extra args] — prints nothing; leaves
# $SB/<name>/{out,usermod.log,tee.log,state/dots/manifest} to assert on.
run_case() {
    local dir="$SB/$1" shell="$2"
    shift 2
    mkdir -p "$dir/fake" "$dir/home" "$dir/state/dots"
    : >"$dir/usermod.log"
    : >"$dir/tee.log"
    [[ -f "$dir/manifest.seed" ]] && cp "$dir/manifest.seed" "$dir/state/dots/manifest"
    fake "$dir/fake" sudo 'exec "$@"'
    fake "$dir/fake" usermod "echo \"usermod \$*\" >>'$dir/usermod.log'"
    fake "$dir/fake" tee "cat >>'$dir/tee.log'"
    fake "$dir/fake" getent "echo \"\$2:x:1000:1000::/home/\$2:$shell\""
    env -i HOME="$dir/home" USER=tuser \
        XDG_STATE_HOME="$dir/state" XDG_CONFIG_HOME="$dir/home/.config" \
        XDG_CACHE_HOME="$dir/home/.cache" XDG_DATA_HOME="$dir/home/.local/share" \
        PATH="$dir/fake:$SB/root/usr/sbin:$SB/root/usr/bin:$SB/real" \
        "$(type -P bash)" "$DOTS_DIR/scripts/install-services.sh" "$@" >"$dir/out" 2>&1 \
        || { red "install-services.sh exited non-zero in case $1:" && cat "$dir/out" && FAILS=$((FAILS + 1)); }
}

shell_rows() { grep "^SHELL" "$SB/$1/state/dots/manifest" 2>/dev/null || true; }

blue "case fresh: bash -> zsh, with sbin first on PATH"
run_case fresh /bin/bash
check "usermod gets the resolved path, not the sbin spelling" \
    grep -qxF "usermod -s $CANON tuser" "$SB/fresh/usermod.log"
check "/etc/shells is given the resolved path" grep -qxF "$CANON" "$SB/fresh/tee.log"
check "the SHELL row records bash as the previous shell" \
    test "$(shell_rows fresh)" = "$(printf 'SHELL\t/bin/bash\t%s' "$CANON")"

blue "case respell: an install that recorded /usr/sbin/zsh"
mkdir -p "$SB/respell"
printf 'SHELL\t/bin/bash\t%s\n' "$SBIN_ZSH" >"$SB/respell/manifest.seed"
run_case respell "$SBIN_ZSH"
check "usermod respells it to the resolved path" \
    grep -qxF "usermod -s $CANON tuser" "$SB/respell/usermod.log"
check "no new SHELL row: uninstall still restores bash" \
    test "$(shell_rows respell)" = "$(printf 'SHELL\t/bin/bash\t%s' "$SBIN_ZSH")"

blue "case canonical: already the resolved path"
run_case canonical "$CANON"
check "no usermod call" test ! -s "$SB/canonical/usermod.log"
check "reports it as already zsh" grep -q "already zsh" "$SB/canonical/out"
check "no SHELL row" test -z "$(shell_rows canonical)"

blue "case dry: --dry-run on the respell case"
run_case dry "$SBIN_ZSH" --dry-run
check "no usermod call" test ! -s "$SB/dry/usermod.log"
check "says what it would do" grep -q "would usermod -s $CANON" "$SB/dry/out"

if [[ $FAILS -gt 0 ]]; then
    red "$FAILS check(s) failed"
    exit 1
fi
green "✓ login shell is recorded by its resolved path"
