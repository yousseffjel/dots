# Plan — tmux-xdg-paths

## Goal
Two tmux paths ignore XDG: `@resurrect-dir` hardcodes `$HOME/.local/state`
(queued item), and `config/tmux/bin/tmux-palette`'s resurrect save/restore
entries hardcode `~/.local/share/tmux/plugins` (found 2026-09-28 — the
2026-08-10 XDG_DATA_HOME sweep missed it because tests/tmux-tpm-lockstep.sh
checks only two files). Fix both, and guard the whole config/tmux tree.

## Scope
- config/tmux/**
- tests/tmux-xdg-paths.sh
- TESTING.md
- .github/workflows/ci.yml
- .claude/**

## Allowed
## Forbidden
- scripts/

## Steps
1. 30-plugins.conf: set @resurrect-dir via single-quoted run-shell with ${XDG_STATE_HOME:-...}
2. tmux-palette: resurrect entries via run-shell '"${XDG_DATA_HOME:-...}/..."'
3. New tests/tmux-xdg-paths.sh: no non-comment line under config/tmux names .local/share or .local/state outside the defaulted form; live-load the @resurrect-dir line in an isolated tmux server when tmux exists (skip loudly otherwise)
4. TESTING.md entry
5. Verify: real tmux resolution both ways; mutations (revert each fix) caught

## Out of scope
- ~/.config/tmux paths — symlinks.sh itself targets $HOME/.config, so those are consistent

## Risks
- run-shell ordering: the option must exist before resurrect reads it — resurrect reads it lazily at save/restore; TMUX_PLUGIN_MANAGER_PATH already relies on the same run-shell ordering
