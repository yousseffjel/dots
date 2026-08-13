# Plan — hyde-parity

## Goal
Close two HyDE framework-parity items in one slot: put a single user-facing
`dots` command on `$PATH` (real dispatcher, one name, delegating to the four
existing entry points), and ship the Bibata-Modern-Classic cursor theme as a
tarball vendored in-repo and extracted at install time. Both are decision-locked;
this plan is the mechanics only.

## Scope
- `scripts/**`
- `config/zsh/**`
- `themes/*/theme.conf`
- `assets/**`
- `tests/**`
- `*.md`, `docs/*.md`

## Allowed
- scripts/, config/zsh/, themes/, assets/, tests/, docs/
- README.md, KEYBINDINGS.md, CLAUDE.md, ROADMAP.md, TESTING.md

## Forbidden
- suckless/
- packages/core.lst
- .github/workflows/install-container.yml
- HyDE/

## Steps
1. `scripts/dots` dispatcher — subcommand routing, `--help`, unknown-subcommand exit.
2. Zsh completion: create `config/zsh/completions/`, add `_dots`, wire `fpath` in `.zshrc`.
3. Install + uninstall wiring for the symlink: `SCRIPT` manifest row; generalize `uninstall_scripts` dwmblocks-only prose.
4. Vendor `Bibata-Modern-Classic.tar.xz` (v2.0.7) under `assets/cursors/` with pinned tag + recorded checksum.
5. Cursor extraction in the theme restore path, `THEME` manifest row, `cursor_theme=` in all four `theme.conf`.
6. Tests: dispatcher subcommand coverage + cursor deploy/manifest lockstep, each mutation-checked.
7. Docs reconciliation: README, THEMING, UNINSTALL, KEYBINDINGS, CLAUDE.md (incl. the stale `completions/`/`functions/` map entry), MASTER_PLAN.

## Out of scope
- The other two parity items (`CHANGELOG.md`/`CONTRIBUTING.md`, dependency automation).
- `polkit-gnome` retirement — still red in CI, tracked separately.
- Any change to the dwmblocks `dwm-*` scripts in `~/.local/bin`.

## Risks
- `~/.local/bin` wins PATH over `dwm/bin` — mitigated by claiming exactly one name (`dots`), colliding with nothing in either dir.
- Vendored blob is ~18x the largest tracked file and nothing watches it — mitigated by pinning the tag and recording the checksum in the same commit.
- `usage()` strings hardcode script filenames, so `dots version --help` prints `version.sh` — resolved in step 1, not deferred.
- Adding `dots` to `SCRIPT` makes uninstall's dwmblocks-only prompt lie — fixed in step 3, same diff.
