# Aliases — all guarded so missing tools don't error.

# Editors
alias n='nvim'
alias sn='sudo -E nvim'
alias src='exec zsh'                    # reload shell
alias sys='nvim "$ZDOTDIR/.zshrc"'

# eza replaces ls
if (( $+commands[eza] )); then
  alias ls='eza --icons --group-directories-first'
  alias ll='eza -lh --icons --group-directories-first --git'
  alias la='eza -lah --icons --group-directories-first --git'
  alias lt='eza --tree --icons --group-directories-first --level=2'
  alias lst='eza -lh --no-time --no-user --git --octal-permissions --tree --level=2'
fi

# bat replaces cat (paging off so it doesn't hijack one-shot use)
(( $+commands[bat] )) && alias cat='bat --paging=never --style=plain'

# zoxide jumping
if (( $+commands[zoxide] )); then
  alias ..='z ..'
  alias ...='z ../..'
  alias ....='z ../../..'
fi

# git
alias g='git'
alias git='git --no-pager'
alias gs='git status'
alias gd='git diff'
alias gdc='git diff --cached'
alias ga='git add'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gsw='git switch'
alias gswc='git switch -c'
alias gb='git branch'
alias gp='git push'
alias gpl='git pull'
alias gl='git log --oneline --graph --decorate --all -n 30'
alias gst='git stash'
alias gstp='git stash pop'

# Misc
alias mk='mkdir -p'
alias tch='touch'
alias py='python3'
alias cls='clear'

# Package-manager shortcuts (Arch / macOS-MacPorts)
if [[ -f /etc/pacman.conf ]]; then
  alias paconf='sudo -E nvim /etc/pacman.conf'
elif [[ -f /opt/local/etc/macports/macports.conf ]]; then
  alias paconf='sudo -E nvim /opt/local/etc/macports/macports.conf'
  alias pi='sudo port install'
  alias prm='sudo port uninstall'
  alias pu='sudo port selfupdate && sudo port upgrade outdated'
  alias psr='port search'           # `ps` is /bin/ps
  alias pinfo='port info'
  alias plist='port installed'
fi
