# PATH — typeset -U keeps entries unique
typeset -U path PATH

path=(
  "$HOME/.local/bin"
  "$HOME/bin"
  "$HOME/.config/dwm/bin"
  "$HOME/.cargo/bin"
  "$HOME/go/bin"
  $path
)

# macOS: MacPorts prefix first, then Homebrew (for any CLI shipped via --cask)
if [[ "$OSTYPE" == darwin* ]]; then
  path=(
    /opt/local/bin
    /opt/local/sbin
    /opt/homebrew/bin     # Apple Silicon Homebrew
    /opt/homebrew/sbin
    /usr/local/bin        # Intel Homebrew
    /usr/local/sbin
    $path
  )
fi

export PATH
