#!/usr/bin/env bash
# Bootstrap a full dwm desktop on Arch Linux: zsh + tmux, X11 + suckless build
# deps, fonts/theming, desktop utilities, the ly display manager, and
# dwm/st/dmenu/dwmblocks/slock built from suckless/.
# Re-runnable: every step is idempotent.
#
# usage: install-arch.sh [--skip-suckless]
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
# bibata-cursor-theme is AUR-only (no official pacman package) — install it
# yourself with an AUR helper (yay/paru) if you want it; none is bootstrapped
# here since building one from source is a separate trust decision.

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
            sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) red "unknown argument: $arg"; exit 1 ;;
    esac
done

if ! command -v pacman >/dev/null 2>&1; then
    red "pacman not found — this script targets Arch Linux."
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
# utilities, and the dev stack — the pacman equivalent of the Fedora desktop
# manifest, deduplicated (git, make, gcc appear in more than one source
# section; base-devel below already covers them but they're kept here too
# as a fallback in case the group install fails).
PACKAGES=(
    # core system & display server
    xorg-server xorg-xinit xorg-xrandr xorg-xsetroot xorg-xset xorg-xrdb xorg-xinput
    libx11 libxft libxinerama freetype2 fontconfig
    networkmanager network-manager-applet
    pipewire pipewire-pulse pipewire-alsa pipewire-jack
    wireplumber polkit-gnome opendoas fuse2
    # shell & interface foundation (git, zsh: see REQUIRED above)
    make gcc patch pkgconf sxhkd kitty
    # fonts & theming
    ttf-jetbrains-mono ttf-jetbrains-mono-nerd noto-fonts-emoji noto-fonts
    papirus-icon-theme adwaita-icon-theme
    # desktop utilities, clipboard & file management
    picom dunst libnotify feh xclip xsel copyq
    brightnessctl playerctl pamixer pavucontrol alsa-utils
    thunar thunar-archive-plugin tumbler file-roller gvfs
    lxappearance xdg-user-dirs
    unzip 7zip zip tar
    # development stack (Node.js is handled by nvm, not pacman — see header)
    neovim vim tmux lazygit
    rust python-pip
    fzf bat eza htop tree pv jq figlet trash-cli ripgrep fd zoxide
    curl wget binutils coreutils
    # display manager
    ly
)

# git and zsh are hard requirements — symlinks.sh needs git for the plugin
# manager clones below, and the shell bootstrap below is pointless without
# zsh. Install them up front and hard-fail like install.sh/
# install-fedora-server.sh do, instead of letting them ride in the
# best-effort PACKAGES loop where a silent skip would only surface later as
# a confusing `git clone` failure.
REQUIRED=(git zsh)

# ArchWiki warns against installing on top of a stale local db (a "partial
# upgrade") — sync + upgrade first, then install everything else.
blue "==> syncing pacman databases and upgrading the system"
$SUDO pacman -Syu --needed --noconfirm

blue "==> installing required: ${REQUIRED[*]}"
$SUDO pacman -S --needed --noconfirm "${REQUIRED[@]}"

blue "==> installing base-devel (group)"
if ! $SUDO pacman -S --needed --noconfirm base-devel 2>/dev/null; then
    yellow "  skipped (group unavailable) — individual gcc/make/patch/pkgconf packages below still cover the toolchain"
fi

blue "==> installing packages (best-effort, one at a time so a single renamed/missing package doesn't abort the rest)"
for pkg in "${PACKAGES[@]}"; do
    if $SUDO pacman -S --needed --noconfirm "$pkg" >/dev/null 2>&1; then
        green "  installed: $pkg"
    else
        yellow "  skipped (not found in configured repos): $pkg"
    fi
done

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
if command -v ly >/dev/null 2>&1 || pacman -Qq ly >/dev/null 2>&1; then
    $SUDO systemctl enable ly.service
    green "enabled ly.service"
fi

# dwm/st/dmenu/dwmblocks/slock: on by default here, unlike a headless
# server script's opt-in — this script already installs Xorg and the
# suckless build deps, so the common case is "build them."
if [[ $SKIP_SUCKLESS -eq 0 ]]; then
    blue "==> building suckless programs"
    "$SCRIPT_DIR/install-suckless.sh"
else
    yellow "  --skip-suckless passed — run scripts/install-suckless.sh later to build dwm/st/dmenu/dwmblocks/slock"
fi

green "✓ install complete"
yellow "  - open a new shell or run: exec zsh"
yellow "  - on first tmux start, TPM auto-installs plugins"
yellow "  - log in via ly on next boot; disable getty@tty1 first if it's still enabled on the same tty"
yellow "  - Node.js: install nvm yourself (https://github.com/nvm-sh/nvm), then nvm install --lts"
yellow "  - bibata-cursor-theme is AUR-only — install with yay/paru if you want it"
