# Environment for EVERY zsh — login, interactive and non-interactive script
# shells alike. `~/.zshenv` sets $ZDOTDIR and then sources this file.
#
# Keep it cheap. This runs before .zshrc on every single zsh invocation,
# including `zsh -c` from a script. Interactive-only setup — plugins,
# completion, prompt, aliases — belongs in conf.d/*.zsh, which .zshrc
# sources behind an interactive guard.
#
# This file previously sourced all of conf.d/ itself. Because .zshrc does
# the same, every conf.d file was sourced twice interactively and once in
# every non-interactive shell: `zsh -c true` cost ~570ms against ~2ms for a
# bare shell. Do not reintroduce a conf.d loop here.

# XDG base directories. Non-interactive shells need these too — scripts in
# this repo resolve cache/state paths from them.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# alacritty (winit) scales each monitor by the physical size its EDID claims,
# and docks and HDMI adapters often claim nonsense: two 1080p screens behind a
# USB-C dock reported 160x90mm, so alacritty drew text ~3.2x there against
# ~1.7x on the laptop panel. One fixed factor everywhere instead, 1.3 by
# user choice (1.7 was too big). dwm, st and dmenu are unaffected
# (Xft, no per-monitor scale). A value already in the environment wins.
export WINIT_X11_SCALE_FACTOR="${WINIT_X11_SCALE_FACTOR:-1.3}"

# PATH must be set here rather than in conf.d, because dwm's autostart and
# the theming engine invoke config/dwm/bin/* from non-interactive contexts.
# typeset -U keeps entries unique if this file is sourced more than once.
typeset -U path PATH
path=(
  "$HOME/.local/bin"
  "$HOME/bin"
  "$XDG_CONFIG_HOME/dwm/bin"
  "$HOME/.cargo/bin"
  "$HOME/go/bin"
  $path
  # Flatpak's per-app launchers (one per installed app, named by app ID, e.g.
  # org.xfce.mousepad), so they run by app ID from a shell. (The Super+space
  # launcher, dwm-apps, finds Flatpak apps by their .desktop files.) Last, so
  # they never shadow a native command. User installation first — that is
  # where install-restore-flatpak.sh puts Flathub. Missing dirs are harmless.
  "$XDG_DATA_HOME/flatpak/exports/bin"
  /var/lib/flatpak/exports/bin
)
export PATH
