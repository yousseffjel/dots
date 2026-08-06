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
)
export PATH
