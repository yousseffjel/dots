# Prompt — starship if available, fallback to a small built-in.

if (( $+commands[starship] )); then
  # starship's default config path is $XDG_CONFIG_HOME/starship.toml — a bare
  # file. symlinks.sh links directories, not files (CLAUDE.md rule 7), so ours
  # is deployed at $XDG_CONFIG_HOME/starship/starship.toml and would never be
  # read without pointing $STARSHIP_CONFIG at it.
  #
  # Two candidates. config/theme/templates/always/starship.dcol writes a
  # wallpaper-themed copy of the repo config into the cache dir on every
  # wallpaper change. Prefer it — but only while it is newer than the repo
  # config, so that editing the prompt does not stay invisible until the next
  # wallpaper change. Falling back that way round loses the theme, never the
  # edit; re-theme with any wallpaper change or scripts/theme/theme-apply.sh.
  #
  # The missing-repo case is spelled out rather than left to -nt: bash's -nt
  # is true when the right-hand file does not exist, but ZSH'S IS NOT — it
  # returns false unless both files exist. Relying on the bash reading here
  # would silently drop the themed config on a box where symlinks.sh never
  # ran, which is exactly the box that needs it.
  #
  # This is evaluated once per shell, so a wallpaper change mid-session only
  # reaches shells started afterwards unless the themed copy was already the
  # chosen path (same path, new contents — those re-theme immediately).
  # An explicit $STARSHIP_CONFIG inherited from the environment always wins.
  if [[ -z "${STARSHIP_CONFIG-}" ]]; then
    _starship_repo="${XDG_CONFIG_HOME:-$HOME/.config}/starship/starship.toml"
    _starship_themed="${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme/starship.toml"
    if [[ -r "$_starship_themed" ]] &&
       [[ ! -r "$_starship_repo" || "$_starship_themed" -nt "$_starship_repo" ]]; then
      export STARSHIP_CONFIG="$_starship_themed"
    elif [[ -r "$_starship_repo" ]]; then
      export STARSHIP_CONFIG="$_starship_repo"
    fi
    unset _starship_repo _starship_themed
  fi

  export STARSHIP_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/starship"
  [[ -d "$STARSHIP_CACHE" ]] || mkdir -p "$STARSHIP_CACHE"
  eval "$(starship init zsh)"
else
  # Minimal fallback so the shell is usable even without starship installed.
  autoload -Uz promptinit && promptinit
  prompt adam1 2>/dev/null || PROMPT='%F{cyan}%n@%m%f %F{yellow}%~%f %# '
fi
