# Helper functions

# git commit with a message argument: gc "message"
gc() {
  if (( $# == 0 )); then
    print -u2 "usage: gc <message>"
    return 1
  fi
  git commit -m "$*"
}

# mkdir + cd
mkcd() {
  if (( $# != 1 )); then
    print -u2 "usage: mkcd <dir>"
    return 1
  fi
  mkdir -p -- "$1" && cd -- "$1"
}

# Extract (almost) any archive: ex <file>
ex() {
  if [[ ! -f "$1" ]]; then
    print -u2 "ex: '$1' is not a regular file"
    return 1
  fi
  case "$1" in
    *.tar.bz2|*.tbz2) tar xjf  "$1" ;;
    *.tar.gz|*.tgz)   tar xzf  "$1" ;;
    *.tar.xz|*.txz)   tar xJf  "$1" ;;
    *.tar.zst)        tar --zstd -xf "$1" ;;
    *.tar)            tar xf   "$1" ;;
    *.bz2)            bunzip2  "$1" ;;
    *.gz)             gunzip   "$1" ;;
    *.xz)             unxz     "$1" ;;
    *.zip)            unzip    "$1" ;;
    *.rar)            unrar x  "$1" ;;
    *.7z)             7z x     "$1" ;;
    *.Z)              uncompress "$1" ;;
    *) print -u2 "ex: don't know how to extract '$1'"; return 1 ;;
  esac
}

# Find-and-cd via fzf: fcd [path]
fcd() {
  (( $+commands[fzf] )) || { print -u2 "fcd: fzf not installed"; return 1; }
  local dir
  if (( $+commands[fd] )); then
    dir=$(fd --type d --hidden --exclude .git . "${1:-.}" | fzf +m) || return
  else
    dir=$(find "${1:-.}" -type d -not -path '*/\.git/*' 2>/dev/null | fzf +m) || return
  fi
  cd -- "$dir"
}

# Search history with fzf and run the chosen line
fh() {
  (( $+commands[fzf] )) || { print -u2 "fh: fzf not installed"; return 1; }
  local cmd
  cmd=$(fc -ln 1 | fzf --tac --no-sort) || return
  print -z -- "$cmd"
}

# Fuzzy-pick a file by NAME and open it in $EDITOR: fe [query]
fe() {
  (( $+commands[fzf] )) || { print -u2 "fe: fzf not installed"; return 1; }
  local file preview='[[ -f {} ]] && (bat --color=always --style=numbers --line-range=:200 {} 2>/dev/null || cat {})'
  # Explicit branches rather than splitting $FZF_DEFAULT_COMMAND — same shape as
  # fcd above, and word-splitting a command string breaks on paths with spaces.
  if (( $+commands[fd] )); then
    file=$(fd --type f --hidden --exclude .git | fzf +m --query="${1:-}" --preview="$preview") || return
  else
    file=$(find . -type f -not -path '*/\.git/*' 2>/dev/null | fzf +m --query="${1:-}" --preview="$preview") || return
  fi
  [[ -n "$file" ]] || return 1
  "${EDITOR:-vi}" -- "$file"
}

# Fuzzy-pick a file by CONTENT and open it in $EDITOR: fec <pattern>
fec() {
  (( $+commands[fzf] )) || { print -u2 "fec: fzf not installed"; return 1; }
  if (( $# == 0 )); then
    print -u2 "usage: fec <pattern>"
    return 1
  fi
  local file
  # rg respects .gitignore and skips binaries; grep -rIl is the fallback.
  if (( $+commands[rg] )); then
    file=$(rg --files-with-matches --hidden --glob '!.git' -- "$1" 2>/dev/null | fzf +m) || return
  else
    file=$(grep -rIl --exclude-dir=.git -- "$1" . 2>/dev/null | fzf +m) || return
  fi
  [[ -n "$file" ]] || { print -u2 "fec: no file matched '$1'"; return 1; }
  "${EDITOR:-vi}" -- "$file"
}
