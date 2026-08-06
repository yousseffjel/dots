# Environment variables for interactive shells.
# Truly-everywhere env (login, scripts) belongs in $ZDOTDIR/.zshenv instead —
# that is where XDG_* and PATH now live, so they are set for non-interactive
# shells too.

export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-$EDITOR}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--R}"

# Use bat as MANPAGER when available
if (( $+commands[bat] )); then
  export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  export MANROFFOPT="-c"
fi

# fzf defaults — prefer fd if installed
if (( $+commands[fd] )); then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --strip-cwd-prefix --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --strip-cwd-prefix --exclude .git'
fi
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:---height 50% --layout=reverse --border --info=inline}"
