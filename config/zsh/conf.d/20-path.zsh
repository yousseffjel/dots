# PATH — typeset -U keeps entries unique
typeset -U path PATH

path=(
  "$HOME/.local/bin"
  "$HOME/bin"
  "$HOME/.cargo/bin"
  "$HOME/go/bin"
  $path
)

export PATH
