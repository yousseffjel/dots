# Shell options + history

# Navigation
setopt AUTO_CD               # type a dir name to cd into it
setopt AUTO_PUSHD            # cd pushes the old dir
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# Globbing / parsing
setopt EXTENDED_GLOB
setopt GLOB_DOTS             # globs match dotfiles too
setopt INTERACTIVE_COMMENTS  # allow `#` comments interactively
setopt NO_BEEP

# History
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
HISTSIZE=50000
SAVEHIST=50000
[[ -d "${HISTFILE:h}" ]] || mkdir -p "${HISTFILE:h}"

setopt EXTENDED_HISTORY      # timestamps in history file
setopt SHARE_HISTORY         # share history between running shells
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE     # `  cmd` (leading space) is not stored
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY           # let !-expansions be edited before running
