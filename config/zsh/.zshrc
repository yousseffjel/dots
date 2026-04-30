# Main interactive zsh config.
# This file is sourced once $ZDOTDIR is set (see ~/.zshenv).
# All real config lives in conf.d/*.zsh, sourced in lexical order.

[[ -o interactive ]] || return

ZDOTDIR="${ZDOTDIR:-${XDG_CONFIG_HOME:-$HOME/.config}/zsh}"

setopt EXTENDED_GLOB NULL_GLOB
for _f in "$ZDOTDIR"/conf.d/*.zsh(N); do
  source "$_f"
done
unset _f
