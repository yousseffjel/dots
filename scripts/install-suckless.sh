#!/usr/bin/env bash
# Build and install the vendored suckless programs (dwm, st, dmenu, dwmblocks,
# slock), the dwmblocks block scripts, and the dwm autostart hook that
# actually launches the status bar.
#
# Runs standalone, or as part of `install-fedora.sh` (which calls this
# unless run with --skip-suckless).
# Re-runnable: every step is idempotent, and nothing that the user may have
# customised (autostart.sh, .xinitrc) is ever overwritten.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUCKLESS_DIR="$DOTS_DIR/suckless"
PROGRAMS=(dwm st dmenu dwmblocks slock)
source "$SCRIPT_DIR/global_fn.sh"

# Every binary each program's `make install` copies to PREFIX/bin (all
# suckless Makefiles here default PREFIX=/usr/local) — dmenu ships four.
declare -A PROGRAM_BINS=(
    [dwm]="dwm"
    [st]="st"
    [dmenu]="dmenu dmenu_path dmenu_run stest"
    [dwmblocks]="dwmblocks"
    [slock]="slock"
)

SKIP_DEPS=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --skip-deps) SKIP_DEPS=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h | --help)
            sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            echo
            echo "usage: install-suckless.sh [--skip-deps] [--dry-run]"
            exit 0
            ;;
        *)
            echo "unknown argument: $arg" >&2
            exit 1
            ;;
    esac
done

red() { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue() { printf '\033[34m%s\033[0m\n' "$*"; }

if [[ ! -d "$SUCKLESS_DIR" ]]; then
    red "no suckless/ directory at $SUCKLESS_DIR"
    exit 1
fi

if [[ $DRY_RUN -eq 0 ]]; then
    manifest_init \
        "$(tr -d '[:space:]' <"$DOTS_DIR/VERSION" 2>/dev/null || echo unknown)" \
        "$(git -C "$DOTS_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
fi

SUDO=()
if [[ $EUID -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        red "sudo not found and not running as root — cannot 'make install'."
        exit 1
    fi
    SUDO=(sudo)
fi

# --- build dependencies ------------------------------------------------------
# X11 + Xft + Xinerama for dwm/st, Xext + Xrandr + libcrypt for slock, and
# tic(1) from ncurses for st's terminfo.
#
# The dnf names live in packages/build.lst (CLAUDE.md rule 10) — this is the
# Fedora path and the only one the repo supports. The pacman and apt-get
# branches below keep inline arrays as a documented exception to that rule:
# a .lst holds one distro's package names, and these two are different names
# for the same libraries. They are vestigial fallbacks from when this repo
# still shipped install-arch.sh and install.sh, kept because
# install-suckless.sh is documented as standalone-runnable.

# Strips '#' comments (whole-line or trailing) and blank lines from a .lst
# file — same rule as read_pkg_list() in scripts/install-pkg-tiers.sh. Kept
# as its own copy rather than sourced: this script runs standalone, and the
# repo's convention (CLAUDE.md rule 2) is per-script helpers over a shared
# sourced file. The copies are one identical line; anything more complex
# should move into global_fn.sh instead of being duplicated again.
read_pkg_list() {
    sed 's/#.*//' "$1" | tr -s '[:space:]' '\n' | grep -v '^$'
}

install_deps() {
    if command -v pacman >/dev/null 2>&1; then
        blue "==> installing build deps (pacman)"
        "${SUDO[@]}" pacman -S --needed --noconfirm \
            base-devel libx11 libxft libxinerama libxext libxrandr libxcrypt \
            freetype2 fontconfig ncurses
    elif command -v dnf >/dev/null 2>&1; then
        local build_lst="$DOTS_DIR/packages/build.lst"
        if [[ ! -f "$build_lst" ]]; then
            red "missing $build_lst — cannot resolve the build dependencies"
            exit 1
        fi
        blue "==> installing build deps (dnf, from packages/build.lst)"
        local pkgs=()
        mapfile -t pkgs < <(read_pkg_list "$build_lst")
        if [[ ${#pkgs[@]} -eq 0 ]]; then
            red "$build_lst declares no packages — refusing to build without a toolchain"
            exit 1
        fi
        "${SUDO[@]}" dnf install -y "${pkgs[@]}"
    elif command -v apt-get >/dev/null 2>&1; then
        blue "==> installing build deps (apt)"
        export DEBIAN_FRONTEND=noninteractive
        "${SUDO[@]}" apt-get update -y
        "${SUDO[@]}" apt-get install -y build-essential libx11-dev libxft-dev \
            libxinerama-dev libxext-dev libxrandr-dev libcrypt-dev \
            libfontconfig1-dev libfreetype6-dev ncurses-bin
    else
        yellow "no pacman, dnf or apt-get — skipping dependency install."
        yellow "  needed: a C toolchain, Xlib, Xft, Xinerama, Xext, Xrandr,"
        yellow "  libcrypt, fontconfig, tic(1)"
    fi
}

if [[ $SKIP_DEPS -eq 1 ]]; then
    yellow "skipping dependency install (--skip-deps)"
elif [[ $DRY_RUN -eq 1 ]]; then
    blue "  (dry-run) would install build deps"
else
    install_deps
fi

# --- build + install ---------------------------------------------------------
for prog in "${PROGRAMS[@]}"; do
    dir="$SUCKLESS_DIR/$prog"
    if [[ ! -f "$dir/Makefile" ]]; then
        yellow "skip    $prog (no Makefile at $dir)"
        continue
    fi
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would build and install $prog"
        continue
    fi
    blue "==> building $prog"
    # Clean first: the object files on disk may come from a different
    # toolchain, and suckless Makefiles do not track header deps.
    make -C "$dir" clean >/dev/null
    make -C "$dir"
    "${SUDO[@]}" make -C "$dir" install
    # `make install` re-checks the build rules as root. If anything looked out
    # of date it would leave root-owned objects behind and every later
    # non-sudo build in this tree would fail on permissions.
    if [[ ${#SUDO[@]} -gt 0 ]]; then
        "${SUDO[@]}" chown -R "$(id -u):$(id -g)" "$dir"
    fi
    read -ra bins <<<"${PROGRAM_BINS[$prog]}"
    for bin in "${bins[@]}"; do
        manifest_append_row SUCKLESS "$prog" "/usr/local/bin/$bin"
    done
    green "installed $prog"
done

# Block scripts belong to the user, not to PREFIX — blocks.def.h points at
# ~/.local/bin by absolute path, so this must not run under sudo.
if [[ -f "$SUCKLESS_DIR/dwmblocks/Makefile" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
        blue "  (dry-run) would install dwmblocks block scripts -> $HOME/.local/bin"
    else
        blue "==> installing dwmblocks block scripts"
        make -C "$SUCKLESS_DIR/dwmblocks" install-scripts
        # Globbed from the same scripts/dwm-* the Makefile installs from, so
        # a future scripts/dwm-foo needs no edit here either — mirrors the
        # Makefile's own "Globbed rather than listed" comment.
        for script in "$SUCKLESS_DIR"/dwmblocks/scripts/dwm-*; do
            manifest_append_row SCRIPT dwmblocks "$HOME/.local/bin/$(basename "$script")"
        done
        green "installed block scripts -> $HOME/.local/bin"
    fi
fi

# --- session wiring ----------------------------------------------------------
# The autostart hook and ~/.xinitrc live in their own file: separate concern
# from building, and keeping both here put this script over the 250-line cap.
# Both targets are user-owned once they exist (CLAUDE.md rule 6).
# shellcheck source=install-session.sh
source "$SCRIPT_DIR/install-session.sh"
install_session

green "✓ suckless install complete"
yellow "  - start the session with:  startx"
yellow "  - lock the screen with:    slock"
yellow "  - rebuild after a config edit:  scripts/install-suckless.sh --skip-deps"
yellow "  - dwm/st/dmenu/slock read config.h / blocks.h, which are generated from"
yellow "    their *.def.h once and then left alone — delete the generated file"
yellow "    to pick up upstream default changes"
