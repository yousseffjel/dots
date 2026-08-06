# Plan — zsh-dehyde-x11

## Goal
Purge HyDE leftovers from `config/zsh/` and retarget the shell at this repo's
dwm/X11 desktop — `conf.d/00-hyde.zsh` loads first on every interactive shell
today and exports `HYPRLAND_CONFIG`. Also lands the first `starship.toml` (the
prompt runs on stock defaults now) and makes zoxide replace `cd`.

## Scope
- `config/zsh/**`
- `config/starship/**`
- `config/.zshrc`
- `scripts/symlinks.sh`

## Allowed
- config/zsh
- config/starship
- config/.zshrc
- scripts/symlinks.sh
- .claude/tasks/zsh-dehyde-x11

## Forbidden
- config/theme

## Steps
1. Audit `conf.d/hyde/{env,terminal,prompt}.zsh`; record keep/dead/Wayland-only in `context.md`.
2. **[D1]** Rewrite `.zshenv` env-only (XDG + PATH, absorbing `20-path.zsh`); `.zshrc`
   keeps the sole conf.d loop. Port audit keepers into `conf.d/`.
3. **[D2]** Delete all 13: `00-hyde.zsh`, `conf.d/hyde/`, `functions/*`,
   `completions/*`, `plugin.zsh`, `prompt.zsh`, `user.zsh`, `config/.zshrc`.
4. zoxide `--cmd cd` in `80-tools.zsh`, degrading to builtin `cd` when absent.
5. Add `config/starship/starship.toml` + its `symlinks.sh` link entry.
6. Verify: `zsh -n`; sandboxed login shell reaches a prompt; `grep -ri hyde config/` empty.

## Out of scope
- starship `.dcol` template — sub-task 9 (needs `$STARSHIP_CONFIG` indirection).
- `starship`/`zoxide` package entries — sub-task 2 owns `packages/*.lst`.

## Risks
- Blind deletion drops a feature — Step 1 audits before Step 3 deletes.
- `config/zsh` is symlinked live into `$HOME`; a broken file breaks the shell.
- Sandbox runs need all four XDG vars (memory: installer-test-sandbox-xdg).
