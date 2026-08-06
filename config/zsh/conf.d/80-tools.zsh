# External-tool integrations. All guarded by `command -v` checks.

# zoxide — replaces `cd` outright, so plain `cd foo` learns and jumps.
# `cdi` is the interactive picker. Real paths still work: zoxide falls through
# to the builtin for anything that resolves, so `cd ..`, `cd -` and `cd /abs`
# behave normally.
#
# The guard is load-bearing, not cosmetic: without zoxide installed nothing is
# defined and builtin `cd` is left untouched.
(( $+commands[zoxide] )) && eval "$(zoxide init zsh --cmd cd)"

# fzf shell integration (zsh keybindings + completion)
if (( $+commands[fzf] )); then
  # fzf >= 0.48 ships built-in zsh integration via `fzf --zsh`
  if fzf --zsh >/dev/null 2>&1; then
    source <(fzf --zsh)
  else
    # Fallback for older fzf installs (Arch / system-installed paths)
    for _f in /usr/share/fzf/key-bindings.zsh \
              /usr/share/fzf/completion.zsh \
              /usr/share/doc/fzf/examples/key-bindings.zsh \
              /usr/share/doc/fzf/examples/completion.zsh; do
      [[ -r "$_f" ]] && source "$_f"
    done
    unset _f
  fi
fi

# nvm — Node version manager
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
[[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"

# pnpm — global bin dir for `pnpm add -g`
export PNPM_HOME="$HOME/.local/share/pnpm"
path=("$PNPM_HOME" $path)
