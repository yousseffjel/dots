#!/usr/bin/env bash
# Bootstrap a full dwm desktop on Fedora: zsh + tmux, X11 + suckless build
# deps, fonts/theming, desktop utilities, the ly display manager, and
# dwm/st/dmenu/dwmblocks/slock built from suckless/.
# Re-runnable: every step is idempotent.
#
# usage: install-fedora.sh [--skip-suckless]
#
#   --skip-suckless   skip building dwm/st/dmenu/dwmblocks/slock. On by
#                      default, since this script targets a desktop machine
#                      (it installs Xorg + the suckless build deps either
#                      way). Run scripts/install-suckless.sh directly later
#                      to build them on their own.
#
# Node.js is intentionally not installed here — install nvm yourself
# afterwards (https://github.com/nvm-sh/nvm) and let it manage Node, since
# its installer needs to touch your zsh rc files and those are symlinked
# from this repo.
#
# lazygit and bibata-cursor-themes are not in official Fedora repos (COPR
# only) — install them yourself via `dnf copr enable dejan/lazygit` and
# `dnf copr enable peterwu/rendezvous` respectively if you want them.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

red()    { printf '\033[31m%s\033[0m\n' "$*"; }
green()  { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
blue()   { printf '\033[34m%s\033[0m\n' "$*"; }

SKIP_SUCKLESS=0
for arg in "$@"; do
    case "$arg" in
        --skip-suckless) SKIP_SUCKLESS=1 ;;
        -h|--help)
            sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) red "unknown argument: $arg"; exit 1 ;;
    esac
done

if ! command -v dnf >/dev/null 2>&1; then
    red "dnf not found — this script targets Fedora."
    exit 1
fi

SUDO=""
if [[ $EUID -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
        red "sudo not found and not running as root."
        exit 1
    fi
    SUDO="sudo"
fi

# Core system, display server, shell/interface, fonts/theming, desktop
# utilities, and the dev stack — the user's curated Fedora manifest,
# deduplicated (git, make, gcc appear in more than one source section).
PACKAGES=(
    # core system & display server
    xorg-x11-server-Xorg xorg-x11-xinit xrandr xsetroot xset xrdb xinput
    libX11-devel libXft-devel libXinerama-devel freetype-devel fontconfig-devel
    NetworkManager network-manager-applet
    pipewire pipewire-pulseaudio pipewire-alsa pipewire-jack-audio-connection-kit
    wireplumber polkit-gnome opendoas fuse
    # shell & interface foundation
    make gcc git patch pkgconf-pkg-config sxhkd zsh kitty
    # fonts & theming
    jetbrains-mono-fonts-all google-noto-emoji-fonts google-noto-sans-fonts
    papirus-icon-theme adwaita-icon-theme
    # desktop utilities, clipboard & file management
    picom dunst libnotify feh xclip xsel copyq
    brightnessctl playerctl pamixer pavucontrol alsa-utils
    thunar thunar-archive-plugin tumbler file-roller gvfs
    lxappearance xdg-user-dirs
    unzip p7zip p7zip-plugins zip tar
    # development stack (Node.js is handled by nvm, not dnf — see header)
    neovim vim tmux
    rust cargo python3-pip
    fzf bat eza htop tree pv jq figlet trash-cli ripgrep fd-find
    curl wget binutils coreutils
    # display manager
    ly
)

blue "==> installing C Development Tools and Libraries (group)"
if ! $SUDO dnf group install -y "C Development Tools and Libraries" 2>/dev/null; then
    if ! $SUDO dnf groupinstall -y "C Development Tools and Libraries" 2>/dev/null; then
        yellow "  skipped (group unavailable under this dnf) — individual packages below still cover the build toolchain"
    fi
fi

blue "==> installing packages (best-effort, one at a time so a single renamed/missing package doesn't abort the rest)"
for pkg in "${PACKAGES[@]}"; do
    if $SUDO dnf install -y "$pkg" >/dev/null 2>&1; then
        green "  installed: $pkg"
    else
        yellow "  skipped (not found in enabled repos): $pkg"
    fi
done

# Fedora's fd-find package ships its binary as `fdfind` (name clash with
# another package, same as Debian/Ubuntu) — shim it under ~/.local/bin so
# the configs' `command -v fd` checks succeed.
mkdir -p "$HOME/.local/bin"
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    green "shim    fdfind -> ~/.local/bin/fd"
fi

# ~/.zshenv must set ZDOTDIR before .zshrc loads — the configs key off it.
ZSHENV="$HOME/.zshenv"
if [[ -f "$ZSHENV" ]] && grep -q 'ZDOTDIR' "$ZSHENV"; then
    green "ok      ~/.zshenv already sets ZDOTDIR"
else
    printf '%s\n' 'export ZDOTDIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"' >> "$ZSHENV"
    green "wrote   ZDOTDIR export -> ~/.zshenv"
fi

blue "==> linking dotfiles"
"$SCRIPT_DIR/symlinks.sh"

# Pre-clone plugin managers so first launch isn't blocked on a network round-trip.
ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME/.git" ]]; then
    blue "==> bootstrapping zinit"
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

TPM_DIR="$HOME/.local/share/tmux/plugins/tpm"
if [[ ! -d "$TPM_DIR/.git" ]]; then
    blue "==> bootstrapping TPM"
    mkdir -p "$(dirname "$TPM_DIR")"
    git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

# Default login shell -> zsh
ZSH_BIN="$(command -v zsh)"
if [[ -n "$ZSH_BIN" ]]; then
    if ! grep -qx "$ZSH_BIN" /etc/shells; then
        echo "$ZSH_BIN" | $SUDO tee -a /etc/shells >/dev/null
        green "added   $ZSH_BIN -> /etc/shells"
    fi
    CURRENT_SHELL="$(getent passwd "$USER" | cut -d: -f7)"
    if [[ "$CURRENT_SHELL" != "$ZSH_BIN" ]]; then
        if chsh -s "$ZSH_BIN" 2>/dev/null; then
            green "default shell -> $ZSH_BIN"
        else
            yellow "could not chsh non-interactively — run manually:  chsh -s $ZSH_BIN"
        fi
    else
        green "ok      login shell is already zsh"
    fi
fi

# ly: enable the service, but don't touch getty units — whether tty1's getty
# needs disabling depends on the user's existing layout.
if command -v ly >/dev/null 2>&1 || rpm -q ly >/dev/null 2>&1; then
    $SUDO systemctl enable ly.service
    green "enabled ly.service"
fi

# dwm/st/dmenu/dwmblocks/slock: on by default here, unlike install.sh's
# server-oriented --with-suckless opt-in — this script already installs
# Xorg and the suckless build deps, so the common case is "build them."
if [[ $SKIP_SUCKLESS -eq 0 ]]; then
    blue "==> building suckless programs"
    # No --skip-deps: install-suckless.sh's dnf branch covers libXext/libXrandr/
    # libxcrypt/ncurses, which slock and st need but PACKAGES above doesn't list.
    "$SCRIPT_DIR/install-suckless.sh"
else
    yellow "  --skip-suckless passed — run scripts/install-suckless.sh later to build dwm/st/dmenu/dwmblocks/slock"
fi

green "✓ install complete"
yellow "  - open a new shell or run: exec zsh"
yellow "  - on first tmux start, TPM auto-installs plugins"
yellow "  - log in via ly on next boot; disable getty@tty1 first if it's still enabled on the same tty"
yellow "  - Node.js: install nvm yourself (https://github.com/nvm-sh/nvm), then nvm install --lts"
yellow "  - lazygit / bibata-cursor-themes are COPR-only — see the script header for the copr enable commands"
