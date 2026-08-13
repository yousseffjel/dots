# Context — hyde-parity

## Background
`MASTER_PLAN.md` → "Framework parity with HyDE" (opened 2026-08-12 from a fresh
diff against the local HyDE clone at `8fa0073e`). Two of that block's four items,
taken together in one slot by user decision on 2026-08-13.

## Prior Decisions
- **Real `dots` dispatcher**, not symlinked entry points, not status quo. Chosen
  because `~/.local/bin` wins PATH over `$XDG_CONFIG_HOME/dwm/bin`, so claiming
  one name instead of four minimises the contested namespace.
- **Vendor the cursor tarball in-repo**, HyDE's actual mechanism
  (`HyDE/Scripts/restore_fnt.sh:47` extracts from `${cloneDir}/Source/arcs/`, it
  does *not* download). No network at install time. Accepted: first binary blob
  in a repo that has only ever vendored `.diff` files and C sources.
- **Bibata-Modern-Classic** (black fill, white outline, rounded), 1,767,748
  bytes, release `v2.0.7`. Survives a future light-mode decision, unlike Ice.
- **One slot, both items**, full 4-sweep audit tier.
- Rule 4 (COPR is opt-in) is untouched — vendoring sidesteps it entirely.

## References
- `config/zsh/.zshenv:25-32` — PATH order; `~/.local/bin` first, `dwm/bin` third.
- `suckless/dwmblocks/blocks.def.h:36-48` — the four `dwm-*` block scripts are
  called by **absolute path**, never via PATH. That is why they are safe today.
- `scripts/global_fn.sh:84` `manifest_append_row`, `:142` `manifest_has_path`.
- `scripts/uninstall_steps.sh:79` `uninstall_scripts` (SCRIPT, `rm -f`),
  `:108` `uninstall_theme` (THEME, `rm -rf`).
- `scripts/version.sh:19` — the `usage:` hardcoding pattern, repeated in
  `theme-apply.sh:44`, `wallpaper.sh:26`, `uninstall.sh:29`.
- `scripts/symlinks.sh:67` `--list-links`, the "derive, don't restate" precedent.

## Notes
- **Fonts are already solved** — the parity item's title says "font and cursor",
  but `cascadia-code-nf-fonts` (desktop.lst, with consequence text) and the noto
  set (extra.lst) cover fonts. This task is cursors only.
- Linux release assets are **`.tar.xz`**, so HyDE's `tar -xzf` becomes `tar -xJf`.
  Copying its idiom verbatim fails.
- `THEME` uninstall uses `rm -rf`, so a cursor *directory* tree unregisters
  cleanly. `SCRIPT` uses `rm -f`, correct for a symlink.
- `config/zsh/completions/` and `functions/` **do not exist**; `CLAUDE.md:34`
  claims both. Fix the map entry in step 7.
- Entry-point flags are non-overlapping, so the dispatcher can forward `"$@"`
  verbatim: `--json` / `--list`,`--wallbash` / `--random`,`--select`,`<path>` /
  `--yes`,`--dry-run`.
- `.claude/worktrees/` is not gitignored — slot dirs show as untracked on main.
  Pre-existing, not addressed here.
