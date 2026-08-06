# Prompt — starship if available, fallback to a small built-in.

if (( $+commands[starship] )); then
  # starship's default config path is $XDG_CONFIG_HOME/starship.toml — a bare
  # file. symlinks.sh links directories, not files (CLAUDE.md rule 7), so ours
  # is deployed at $XDG_CONFIG_HOME/starship/starship.toml and would never be
  # read without pointing $STARSHIP_CONFIG at it.
  #
  # Respect an existing value: sub-task 9 of the roster Epic renders a
  # wallpaper-themed copy into the cache dir and sets this variable earlier.
  if [[ -z "${STARSHIP_CONFIG-}" ]]; then
    _starship_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/starship/starship.toml"
    [[ -r "$_starship_cfg" ]] && export STARSHIP_CONFIG="$_starship_cfg"
    unset _starship_cfg
  fi

  export STARSHIP_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/starship"
  [[ -d "$STARSHIP_CACHE" ]] || mkdir -p "$STARSHIP_CACHE"
  eval "$(starship init zsh)"
else
  # Minimal fallback so the shell is usable even without starship installed.
  autoload -Uz promptinit && promptinit
  prompt adam1 2>/dev/null || PROMPT='%F{cyan}%n@%m%f %F{yellow}%~%f %# '
fi
