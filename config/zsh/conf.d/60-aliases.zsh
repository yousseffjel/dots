# Aliases — all guarded so missing tools don't error.

# Editors
alias n='nvim'
alias sn='sudo -E nvim'
alias src='exec zsh'                    # reload shell
alias sys='nvim "$ZDOTDIR/.zshrc"'

# eza replaces ls
if (( $+commands[eza] )); then
  alias ls='eza --icons --group-directories-first'
  alias l='eza -lh --icons --group-directories-first'
  alias ll='eza -lh --icons --group-directories-first --git'
  alias la='eza -lah --icons --group-directories-first --git'
  alias ld='eza -lhD --icons --group-directories-first'   # directories only
  alias lt='eza --tree --icons --group-directories-first --level=2'
  alias lst='eza -lh --no-time --no-user --git --octal-permissions --tree --level=2'
fi

# bat replaces cat (paging off so it doesn't hijack one-shot use)
if (( $+commands[bat] )); then
  alias cat='bat --paging=never --style=plain'
  # Global alias: any `cmd --help` gets syntax-highlighted. Global rather than
  # ordinary so it expands mid-command. Deliberately not applied to `-h`,
  # which collides with the POSIX test operator.
  alias -g -- --help='--help 2>&1 | bat --language=help --style=plain --paging=never --color always'
fi

# Parent-directory hops. Plain `cd` on purpose — 80-tools.zsh points zoxide at
# `cd` (--cmd cd), so `z` no longer exists, and zoxide passes real paths like
# `..` straight through to the builtin. Unguarded because builtin `cd` handles
# these with or without zoxide installed.
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

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


# Updated aliases pointing to the folder /usr/bin/
alias yts="yt-dlp --ffmpeg-location /usr/bin/ -x --audio-format best --audio-quality 0 --embed-metadata --embed-thumbnail"

alias yta="yt-dlp --ffmpeg-location /usr/bin/ -x --audio-format best --audio-quality 0 --embed-metadata --embed-thumbnail -o '%(artist)s - %(album)s/%(track_number)s - %(title)s.%(ext)s'"


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
