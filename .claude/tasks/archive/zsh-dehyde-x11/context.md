# Context — zsh-dehyde-x11

## Background
Sub-task 1 of the Epic "app / tool / package roster finalization"
(`.claude/tasks/scope-b-app-roster-finalization.md`, main-side). The Epic
came out of a HyDE-vs-this-repo comparison the user asked for on
2026-08-06.

`config/zsh/` was seeded from HyDE and never de-branded. Seven files are
still HyDE's, and one of them is **live**: `config/zsh/.zshrc` sources
`conf.d/*.zsh` in lexical order, so `00-hyde.zsh` sorts first and runs on
every interactive shell — sourcing `conf.d/hyde/env.zsh` (exports
`HYPRLAND_CONFIG` on an X11/dwm box, re-does XDG exports `10-env.zsh`
already owns) and `conf.d/hyde/terminal.zsh` (248 lines).

## Prior Decisions
- **Prompt is starship** (Epic locked decision 4). Confirmed by
  inspection: `conf.d/99-prompt.zsh` is the live path and the binary is
  installed on this machine. HyDE's p10k fallback in
  `conf.d/hyde/prompt.zsh` is dead — gated on `HYDE_ZSH_PROMPT=1`, which
  nothing sets. `config/zsh/prompt.zsh` is a HyDE stub that `return 1`s
  on line 3.
- **zoxide replaces `cd`** via `--cmd cd` (Epic locked decision 11). The
  existing `(( $+commands[zoxide] ))` guard in `80-tools.zsh` becomes
  load-bearing: without the binary, builtin `cd` must survive intact.
- **`30-zinit.zsh` already owns plugin management.** HyDE's `plugin.zsh`
  (66 lines) is a competing zinit setup that our `.zshrc` never sources —
  dead, but it is what `prompt.zsh` is snippet-loaded from, so both go
  together.
- Change logs `2026-08-05-theming-*` establish that `config/zsh` is
  symlinked (not copied) by `scripts/symlinks.sh`, unlike dunst/picom.

## References
- Epic scope + all 12 locked decisions:
  `.claude/tasks/scope-b-app-roster-finalization.md` (main worktree only)
- `scripts/symlinks.sh:31-33` — the `LINKS` array a starship entry joins
- `config/zsh/conf.d/80-tools.zsh` — zoxide/fzf/nvm/pnpm integrations
- `config/zsh/conf.d/99-prompt.zsh` — starship init + fallback prompt
- Memory `installer-test-sandbox-xdg` — sandboxed runs need all four XDG
  vars plus `DISPLAY=`, not just `HOME`

## Notes
Files to remove (7), with why each is safe or needs auditing first:

| File | Lines | Status |
|---|---:|---|
| `conf.d/00-hyde.zsh` | 21 | **Active.** Loader for the two below. |
| `conf.d/hyde/env.zsh` | 54 | Exports `HYPRLAND_CONFIG`; XDG block duplicates `10-env.zsh`. Check `LESSHISTFILE`/`WGETRC`/`PYTHON_HISTORY` — those are worth keeping. |
| `conf.d/hyde/terminal.zsh` | 248 | **Audit required (Step 1).** Grep found no OSC-133 overlap with `55-osc133.zsh`, but the file has not been read end to end. |
| `conf.d/hyde/prompt.zsh` | 36 | Dead — `HYDE_ZSH_PROMPT` gate. |
| `completions/hydectl.zsh` | 5 | Completes a binary this repo never installs. |
| `plugin.zsh` / `prompt.zsh` / `user.zsh` | 106 | Not sourced by our `.zshrc`. |
| `config/.zshrc` | 20 | Byte-identical to `config/zsh/.zshrc` (verified with `diff`), and outside the symlinked dir — dead. |

Untracked cruft already gitignored, leave alone: `config/.zcompdump`,
`config/zsh/{.zcompdump,zcompdump,zcompdump.zwc,zhistory}`.

`config/starship/` is a new directory, so `symlinks.sh` needs a new
`LINKS` entry — and per CLAUDE.md rule 7 it links directories, backing up
conflicts to `~/.dotfiles-backup/<timestamp>/` rather than overwriting.
