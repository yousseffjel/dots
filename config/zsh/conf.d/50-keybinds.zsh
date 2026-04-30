# Keybindings (emacs base, with a few quality-of-life additions)

bindkey -e

# Up/Down: history-substring-search if loaded, else built-in history search
if (( $+widgets[history-substring-search-up] )); then
  bindkey '^[[A' history-substring-search-up      # arrow up
  bindkey '^[[B' history-substring-search-down    # arrow down
  bindkey '^P'   history-substring-search-up
  bindkey '^N'   history-substring-search-down
fi

# Word navigation
bindkey '^[[1;5C' forward-word         # Ctrl+Right
bindkey '^[[1;5D' backward-word        # Ctrl+Left
bindkey '^[[1;3C' forward-word         # Alt+Right
bindkey '^[[1;3D' backward-word        # Alt+Left

# Word deletion
bindkey '^H'      backward-kill-word   # Ctrl+Backspace
bindkey '^[[3;5~' kill-word            # Ctrl+Delete

# Home / End / Delete (ANSI + xterm)
bindkey '^[[H'  beginning-of-line
bindkey '^[[F'  end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line
bindkey '^[[3~' delete-char

# Edit current command in $EDITOR (Ctrl+X, Ctrl+E)
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line
