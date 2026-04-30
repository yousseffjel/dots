# OSC 133 "semantic prompt" marks — enables Warp-style command blocks and
# tmux's previous-prompt / next-prompt navigation (tmux ≥ 3.4).
#
#   ESC ] 133 ; A ST           start of a new prompt          (precmd)
#   ESC ] 133 ; C ST           start of command output        (preexec)
#   ESC ] 133 ; D ; <rc> ST    end of output, with exit code  (next precmd)
#
# Spec: https://gitlab.freedesktop.org/Per_Bothner/specifications/-/blob/master/proposals/semantic-prompts.md
#
# Kitty also reads these natively, so block features work both inside and
# outside tmux.

[[ -o interactive ]] || return
[[ -n "${_OSC133_LOADED-}" ]] && return
typeset -g _OSC133_LOADED=1

_osc133_emit() { printf '\033]133;%s\033\\' "$1" }

_osc133_precmd() {
  local rc=$?
  if [[ -n "${_OSC133_CMD_STARTED-}" ]]; then
    _osc133_emit "D;$rc"
    unset _OSC133_CMD_STARTED
  fi
  _osc133_emit "A"
}

_osc133_preexec() {
  _osc133_emit "C"
  typeset -g _OSC133_CMD_STARTED=1
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd  _osc133_precmd
add-zsh-hook preexec _osc133_preexec
