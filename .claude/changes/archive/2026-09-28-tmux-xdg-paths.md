# tmux-xdg-paths
Date: 2026-09-28
Files: 6 + task folder | Lines: ~+175/-6

## What changed
- `config/tmux/conf.d/30-plugins.conf`: `@resurrect-dir` is set through a
  single-quoted `run-shell` using `${XDG_STATE_HOME:-$HOME/.local/state}`.
  tmux's own parser has no `:-` form, the same constraint the TPM paths in
  that file already work around.
- `config/tmux/bin/tmux-palette`: the "resurrect: save/restore" entries
  hardcoded `~/.local/share/tmux/plugins/...`, which is the `XDG_DATA_HOME`
  bug the 2026-08-10 sweep fixed elsewhere and missed here, because
  `tests/tmux-tpm-lockstep.sh` checks only two named files. They now use the
  same run-shell form.
- New `tests/tmux-xdg-paths.sh`:
  - A static sweep of **all** of `config/tmux/`, with comments excluded.
  - A live layer that loads the real lines into an isolated tmux server
    (`-L xdgtest`, private `TMUX_TMPDIR`) and runs the palette entries against
    fake resurrect scripts that record they ran.
  - Both layers are checked with the XDG variables set and unset.
- `ci.yml` `tests` job: an explicit `apt-get install tmux`, so the live layer
  cannot skip in CI and go green having checked half.
- TESTING.md entry.

## Why
The `@resurrect-dir` item was in the MASTER_PLAN queue. The palette paths
were found by the 2026-09-28 scan while scoping it.

## Assumptions
- Type B: `~/.config/tmux` paths are left alone. `symlinks.sh` itself links
  config/tmux to `$HOME/.config/tmux`, so they are consistent by construction.
- Type B: a separate test rather than widening `tmux-tpm-lockstep.sh`, which
  is specifically about installer/config agreement on the TPM directory.

## Test coverage
- Live on tmux 3.7c: all six assertions pass.
- 4/4 mutations on sandboxed copies were CAUGHT:
  - `@resurrect-dir` reverted;
  - the palette reverted;
  - the run-shell double-quoted, which the **live layer alone** catches;
  - the palette pointed at the wrong XDG variable.
- `tests/tmux-tpm-lockstep.sh` and lint still pass.
- Reviewer: READY. It independently repeated the mutations. It also disclosed
  that it ran `git checkout --` on the real worktree file mid-review and
  reconstructed it. I re-verified that file's diff was byte-identical to the
  authored change before committing.

## Follow-ups
- Existing installs keep any sessions already saved under
  `~/.local/state/tmux/resurrect`. When `XDG_STATE_HOME` is non-default, those
  saves are not migrated. No migration was added: the default case resolves
  to the same directory as before, so only custom-XDG users are affected.
