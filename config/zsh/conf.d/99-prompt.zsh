# Prompt — starship if available, fallback to a small built-in.

if (( $+commands[starship] )); then
  export STARSHIP_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/starship"
  [[ -d "$STARSHIP_CACHE" ]] || mkdir -p "$STARSHIP_CACHE"
  eval "$(starship init zsh)"
else
  # Minimal fallback so the shell is usable even without starship installed.
  autoload -Uz promptinit && promptinit
  prompt adam1 2>/dev/null || PROMPT='%F{cyan}%n@%m%f %F{yellow}%~%f %# '
fi
