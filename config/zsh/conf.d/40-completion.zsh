# Completion behavior + styling.
# compinit itself runs in 30-zinit.zsh (must come after fpath is populated).

# Case/hyphen-insensitive, partial-word, and substring matching
zstyle ':completion:*' matcher-list \
  '' \
  'm:{a-z}={A-Za-z}' \
  'r:|[._-]=* r:|=*' \
  'l:|=* r:|=*'

# Menu-style selection
zstyle ':completion:*' menu select=2

# Group + label results
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'
zstyle ':completion:*:warnings'     format '%F{red}-- no matches --%f'
zstyle ':completion:*:messages'     format '%F{cyan}-- %d --%f'

# Color list using LS_COLORS
[[ -z "$LS_COLORS" && -x /usr/bin/dircolors ]] && eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors "${(s.:.)LS_COLORS}"

# Process completion (kill, etc.)
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

# Cache for slow completions
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"

# Misc
zstyle ':completion:*' verbose true
zstyle ':completion:*' completer _expand _complete _ignored _approximate

# fzf-tab: previews and styling
if (( $+commands[fzf] )); then
  zstyle ':fzf-tab:*' fzf-flags --height=60% --layout=reverse --border --info=inline
  zstyle ':fzf-tab:*' switch-group ',' '.'
  zstyle ':fzf-tab:*' use-fzf-default-opts no

  if (( $+commands[eza] )); then
    zstyle ':fzf-tab:complete:cd:*'    fzf-preview 'eza -1 --color=always --icons --group-directories-first $realpath'
    zstyle ':fzf-tab:complete:z:*'     fzf-preview 'eza -1 --color=always --icons --group-directories-first $realpath'
    zstyle ':fzf-tab:complete:ls:*'    fzf-preview 'eza -1 --color=always --icons --group-directories-first $realpath'
  fi
  if (( $+commands[bat] )); then
    zstyle ':fzf-tab:complete:(nvim|vim|cat|bat|less):*' fzf-preview \
      '[[ -d $realpath ]] && eza -1 --color=always --icons $realpath || bat --color=always --style=numbers --line-range=:200 $realpath 2>/dev/null'
  fi
fi
