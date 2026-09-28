# Context — tmux-xdg-paths

## Background
MASTER_PLAN queue item (@resurrect-dir) + scan finding (tmux-palette), user request 2026-09-28.

## Prior Decisions
- 2026-08-10 queue sweep: tmux.conf has no ${VAR:-default}; paths go through single-quoted run-shell bodies (30-plugins.conf header).

## References
- tests/tmux-tpm-lockstep.sh

## Notes
- Verified 2026-09-28 on tmux 3.7c, isolated -L socket: run-shell set-option resolves XDG_STATE_HOME=/custom/state and unset correctly.
