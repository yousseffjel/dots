# Progress — zsh-dehyde-x11

## Status
`in-progress`

## Steps
- [x] 1. Audit `conf.d/hyde/{env,terminal,prompt}.zsh`; record keep/dead/Wayland-only in `context.md`.
- [x] 2. Rewrite `.zshenv` env-only; port keepers into their existing owner files.
- [x] 3. Delete all 14 (13 planned + `20-path.zsh`, absorbed into `.zshenv`).
- [x] 4. zoxide `--cmd cd` in `80-tools.zsh`, degrading to builtin `cd` when absent.
- [x] 5. Add `config/starship/starship.toml` + its `symlinks.sh` link entry.
- [x] 6. Verify: `zsh -n`; sandboxed login shell reaches a prompt; `grep -ri hyde config/` empty.

## Verification results

| Check | Result |
|---|---|
| `zsh -n` | 11 conf.d files + `.zshenv` + `.zshrc` parse clean |
| `grep -ril hyde config/` | empty |
| Sandboxed interactive shell | every keeper loads: `l`, `ld`, `cat`, global `--help`, `..`, `fe`, `fec`, `fcd`, `cd`(zoxide), `cdi`, `$STARSHIP_CONFIG`, dwm/bin on PATH |
| Real PTY startup | silent. Before: 4 lines of "No plugin system found" noise |
| Non-interactive `zsh -c true` | **674 ms -> 4.6 ms** per invocation |
| Interactive `zsh -i -c exit` | **925 ms -> 392 ms** per shell |
| `symlinks.sh --dry-run` / `--list-links` | starship entry present; plans backup-then-link on the pre-existing `~/.config/starship` |

The two `can't change option: zle` warnings seen under `zsh -i -c` come from
fzf's own `--zsh` integration when no ZLE exists; isolated to fzf and absent in
a real PTY. Not a config defect.

## Follow-ups for other sub-tasks
- `KEYBINDINGS.md:13` and `CLAUDE.md:35` still cite the deleted
  `conf.d/20-path.zsh`. Both are outside this plan's `## Allowed` and are owned
  by **sub-task 9** (docs reconciliation).
- **No Nerd Font is packaged** (`jetbrains-mono-fonts-all` is not one), yet
  `60-aliases.zsh`'s pre-existing `eza --icons` requires one. `starship.toml`
  was written glyph-free to avoid depending on it. Belongs to **sub-task 2**.

## Deviations

**D1 — `config/zsh/.zshenv` must be rewritten, not left alone.** The plan
named 7 files to delete and did not mention `.zshenv`. The Step 1 audit found
it is HyDE's file and it loops `conf.d/*.zsh` sourcing every one. Since
`.zshenv` is read by *every* zsh — non-interactive included — and `.zshrc`
runs the same loop again behind an `[[ -o interactive ]]` guard that
`.zshenv` lacks:

- every conf.d file is sourced **twice** in interactive shells;
- every non-interactive `zsh -c` pays the **full interactive config**.

Measured: `zsh -c true` takes **573 ms** against 1.8 ms for a bare shell —
~570 ms wasted per script invocation, on a config whose own `10-env.zsh`
header already states "Truly-everywhere env (login, scripts) belongs in
~/.zshenv instead."

Fix folded into Step 2: `.zshenv` becomes env-only (XDG + PATH, absorbing
`20-path.zsh`), `.zshrc` keeps sole ownership of the conf.d loop.

**D2 — the deletion set is 13 files, not 7.** `config/zsh/functions/*` (4
files) and `config/zsh/completions/*` (2) are dead code. They are only ever
loaded by `_load_functions`/`_load_completions`, which `terminal.zsh` calls
solely in branches this machine never reaches — `plugin.zsh` returns 1 on
line 3 and no oh-my-zsh is installed, so control lands in the `else` at
`terminal.zsh:216`. Verified empirically, not by reading: in a real
interactive shell `eza alias: ABSENT`, `fzf fn: ABSENT`. The `cat` alias that
*does* load comes from `60-aliases.zsh`, not `functions/bat.zsh`.

**D3 — two user-visible bugs fall out of the same else branch.** Every
interactive shell prints "No plugin system found. Please install a plugin
system…" — twice, because of D1. And `HYDE_ZSH_PROMPT="1"` is set at
`terminal.zsh:165`, so `conf.d/hyde/prompt.zsh` initialises starship, then
`99-prompt.zsh` initialises it again; `compinit` likewise runs in both
`terminal.zsh:194` and `30-zinit.zsh`.

## Blockers
_(none — awaiting user re-confirmation of the expanded scope per /code step 3)_
