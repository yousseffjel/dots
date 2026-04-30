# Zinit plugin manager + plugin loading.
#
# Order matters here:
#   1. zsh-completions    — adds completions to fpath, must precede compinit
#   2. compinit           — initializes the completion system
#   3. zinit cdreplay     — replays compdefs queued by zinit before compinit ran
#   4. fzf-tab            — must come AFTER compinit, BEFORE widget-wrapping plugins
#   5. zsh-autopair, autosuggestions
#   6. fast-syntax-highlighting — should be near the end
#   7. history-substring-search — must come AFTER syntax highlighting

ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME/.git" ]]; then
  print -P "%F{33}▓▒░ Installing zinit…%f"
  command mkdir -p "${ZINIT_HOME:h}"
  command git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" \
    && print -P "%F{34}▓▒░ zinit installed.%f" \
    || print -P "%F{160}▓▒░ zinit clone failed.%f"
fi
source "${ZINIT_HOME}/zinit.zsh"

# 1. Completions (adds to fpath; compinit will pick them up)
zinit ice blockf
zinit light zsh-users/zsh-completions

# 2 + 3. compinit (cache zcompdump under XDG_CACHE_HOME)
_zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
[[ -d "${_zcompdump:h}" ]] || mkdir -p "${_zcompdump:h}"
autoload -Uz compinit
compinit -d "$_zcompdump"
unset _zcompdump
zinit cdreplay -q

# 4. fzf-tab — only if fzf is available
(( $+commands[fzf] )) && zinit light Aloxaf/fzf-tab

# 5. autopair + autosuggestions
zinit light hlissner/zsh-autopair
zinit light zsh-users/zsh-autosuggestions

# 6. syntax highlighting (fast-syntax-highlighting is the actively maintained one)
zinit light zdharma-continuum/fast-syntax-highlighting

# 7. history-substring-search (must come after syntax highlighting)
zinit light zsh-users/zsh-history-substring-search

# Plugin tweaks
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
