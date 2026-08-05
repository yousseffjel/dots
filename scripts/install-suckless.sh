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

SKIP_DEPS=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        --skip-deps) SKIP_DEPS=1 ;;
        --dry-run) DRY_RUN=1 ;;
        -h|--help)
            sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            echo
            echo "usage: install-suckless.sh [--skip-deps] [--dry-run]"
            exit 0
            ;;
        *) echo "unknown argument: $arg" >&2; exit 1 ;;
    esac
done

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[34m%s\033[0m\n' "$*"; }

if [[ ! -d "$SUCKLESS_DIR" ]]; then
    red "no suckless/ directory at $SUCKLESS_DIR"
    exit 1
fi

SUDO=""
if [[ $EUID -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        red "sudo not found and not running as root — cannot 'make install'."
        exit 1
    fi
    SUDO="sudo"
fi

# --- build dependencies ------------------------------------------------------
# X11 + Xft + Xinerama for dwm/st, Xext + Xrandr + libcrypt for slock, and
# tic(1) from ncurses for st's terminfo.
install_deps() {
    if command -v pacman >/dev/null 2>&1; then
        blue "==> installing build deps (pacman)"
        $SUDO pacman -S --needed --noconfirm \
            base-devel libx11 libxft libxinerama libxext libxrandr libxcrypt \
            freetype2 fontconfig ncurses
    elif command -v dnf >/dev/null 2>&1; then
        blue "==> installing build deps (dnf)"
        $SUDO dnf install -y gcc make pkgconf-pkg-config \
            libX11-devel libXft-devel libXinerama-devel libXext-devel \
            libXrandr-devel libxcrypt-devel freetype-devel fontconfig-devel \
            ncurses
    elif command -v apt-get >/dev/null 2>&1; then
        blue "==> installing build deps (apt)"
        export DEBIAN_FRONTEND=noninteractive
        $SUDO apt-get update -y
        $SUDO apt-get install -y build-essential libx11-dev libxft-dev \
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
    $SUDO make -C "$dir" install
    # `make install` re-checks the build rules as root. If anything looked out
    # of date it would leave root-owned objects behind and every later
    # non-sudo build in this tree would fail on permissions.
    if [[ -n "$SUDO" ]]; then
        $SUDO chown -R "$(id -u):$(id -g)" "$dir"
    fi
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
        green "installed block scripts -> $HOME/.local/bin"
    fi
fi

# --- autostart ---------------------------------------------------------------
# dwm's autostart patch runs $XDG_DATA_HOME/dwm/autostart.sh (falling back to
# ~/.local/share/dwm) at startup. Without this, dwmblocks is built and
# installed but never actually launched, and the bar stays empty.
AUTOSTART_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dwm"
AUTOSTART="$AUTOSTART_DIR/autostart.sh"
[[ $DRY_RUN -eq 1 ]] || mkdir -p "$AUTOSTART_DIR"

if [[ -e "$AUTOSTART" ]]; then
    if grep -q 'dwmblocks' "$AUTOSTART"; then
        green "ok      $AUTOSTART already starts dwmblocks"
    else
        yellow "kept    $AUTOSTART (exists, does not mention dwmblocks)"
        yellow "        add this line yourself:  pgrep -x dwmblocks >/dev/null || dwmblocks &"
    fi
    if grep -q 'clipmenud' "$AUTOSTART"; then
        green "ok      $AUTOSTART already starts clipmenud"
    else
        yellow "kept    $AUTOSTART (exists, does not mention clipmenud)"
        yellow "        add this line yourself:  command -v clipmenud >/dev/null && ! pgrep -x clipmenud >/dev/null && clipmenud &"
    fi
elif [[ $DRY_RUN -eq 1 ]]; then
    blue "  (dry-run) would write $AUTOSTART (dwmblocks + clipmenud autostart)"
else
    cat > "$AUTOSTART" <<'EOF'
#!/bin/sh
# Run by dwm's autostart patch at startup — see runautostart() in dwm.c.
# dwm backgrounds this whole script, so anything long-running below must be
# backgrounded individually and the script must exit.

# Exactly one status feeder: dwm locates it by name (`pidof -s dwmblocks`, see
# STATUSBAR in config.def.h), so a second copy would make click routing
# ambiguous.
if ! pgrep -x dwmblocks >/dev/null 2>&1; then
	dwmblocks &
fi

# Clipboard history for dwm-clipmenu (Super+v) — only present if clipmenu's
# COPR was enabled (Fedora, via install-fedora.sh). Silently skipped
# elsewhere so this line is harmless on distros without it wired up yet.
if command -v clipmenud >/dev/null 2>&1 && ! pgrep -x clipmenud >/dev/null 2>&1; then
	clipmenud &
fi
EOF
    chmod 755 "$AUTOSTART"
    green "wrote   $AUTOSTART"
fi

# --- xinitrc -----------------------------------------------------------------
XINITRC="$HOME/.xinitrc"
if [[ -e "$XINITRC" ]]; then
    green "ok      ~/.xinitrc exists (left untouched)"
elif [[ $DRY_RUN -eq 1 ]]; then
    blue "  (dry-run) would write ~/.xinitrc (exec dwm)"
else
    cat > "$XINITRC" <<'EOF'
#!/bin/sh
# Started by startx. dwm runs in the foreground; when it exits, X exits.

# Merge the distro's xinit fragments (keyboard layout, dbus, ssh-agent, ...).
if [ -d /etc/X11/xinit/xinitrc.d ]; then
	for f in /etc/X11/xinit/xinitrc.d/?*.sh; do
		[ -x "$f" ] && . "$f"
	done
	unset f
fi

exec dwm
EOF
    chmod 755 "$XINITRC"
    green "wrote   ~/.xinitrc (exec dwm)"
fi

green "✓ suckless install complete"
yellow "  - start the session with:  startx"
yellow "  - lock the screen with:    slock"
yellow "  - rebuild after a config edit:  scripts/install-suckless.sh --skip-deps"
yellow "  - dwm/st/dmenu/slock read config.h / blocks.h, which are generated from"
yellow "    their *.def.h once and then left alone — delete the generated file"
yellow "    to pick up upstream default changes"
