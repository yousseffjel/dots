# Progress — hyde-parity

## Status
`code complete — audit pending`

## Steps
- [x] 1. `scripts/dots` dispatcher — subcommand routing, `--help`, unknown-subcommand exit.
- [x] 2. Zsh completion: create `config/zsh/completions/`, add `_dots`, wire `fpath` in `.zshrc`.
- [x] 3. Install + uninstall wiring for the symlink: `SCRIPT` manifest row; generalize `uninstall_scripts` prose.
- [x] 4. Vendor `Bibata-Modern-Classic.tar.xz` (v2.0.7) under `assets/cursors/` with pinned tag + checksum.
- [x] 5. Cursor extraction in the theme restore path, `THEME` manifest row, `cursor_theme=` in all four `theme.conf`.
- [x] 6. Tests: dispatcher subcommand coverage + cursor deploy/manifest lockstep, each mutation-checked.
- [x] 7. Docs reconciliation: README, THEMING, UNINSTALL, KEYBINDINGS, CLAUDE.md, MASTER_PLAN.

## Deviations
- **Audit/review process** — `git add -A` was run to compute the audit tier
  *before* the audit fixes existed, so the index became a stale snapshot and the
  reviewer read a changeset missing all three fixes. It BLOCKed on the one that
  was externally visible (`xz` undeclared while `tar -xJf` shipped). The finding
  was right about the committed state and wrong about the working tree — and it
  only surfaced because the reviewer read the *index* rather than the files.
  **Stage after fixing, not before auditing**, or the gate reviews something
  nobody is about to commit.
- **Step 7** — `MASTER_PLAN.md` was in the plan's step 7 but is a **main-side**
  file (`session-protocol.md`): slots must not write to it. Striking the two
  parity items happens post-merge on main, not here.
- **Step 7 (scope grew, deliberately)** — three stale claims were found while
  reconciling and fixed in the same pass, because each contradicted this diff:
  `install-fedora.sh` told users to enable a Bibata COPR (now vendored),
  CLAUDE.md rule 4 cited it as the COPR example, and `install-pkg.sh`'s
  starship comment justified a decision by quoting the uninstall prompt this
  task rewrote. The starship decision itself was left unchanged — flagged, not
  silently altered.
- **Step 2** — plan said wire `fpath` in `.zshrc`; wired in `conf.d/30-zinit.zsh`
  instead. `.zshrc` only sources `conf.d/*.zsh`; `compinit` runs at
  `30-zinit.zsh:29`, and an `fpath` addition is only useful before it. Same
  layer, no scope change.
- **Step 3** — the symlink logic went into its own sourced file
  (`scripts/install-restore-bin.sh`, exposing `restore_dots_bin`) rather than
  staying inline in `install-restore.sh`. Inline blocks in that script are not
  reachable by a test without re-running the whole stage; the repo's existing
  pattern for a testable unit is a sourced file with a function
  (`install-restore-theme.sh` → `restore_theme`). Same behaviour, testable.
- **Step 2** — first version of `_dots` extracted zero flags for `version` and
  `uninstall`. Those two write usage as `usage: cmd [--json]`, so the token is
  `[--json]` and never matched `--*`. Brackets are now stripped before the
  match. Caught by probing the real `--help` output rather than assuming.

## Blockers
_(none)_
