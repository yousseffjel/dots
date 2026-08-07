# Context — alacritty-main-terminal

## Background

Epic sub-task 3 of `.claude/tasks/scope-b-app-roster-finalization.md`.
Locked decision 1: alacritty becomes the primary terminal, st is retained
vendored/patched/themed as the no-GPU fallback. Sub-task 2 already
packaged `alacritty` and `cascadia-code-nf-fonts` in `packages/extra.lst`.

Carries the font follow-up recorded in `2026-08-06-packages-roster-fonts.md`:
nothing in the repo points at the Nerd Font today. dwm and dmenu use
`monospace` (fontconfig resolves that to DejaVu Sans Mono) and st uses
`Liberation Mono`, so the glyphs the adopted starship config and
`eza --icons` depend on render as tofu on a fresh box.

## Prior Decisions

- Locked decision 15 (added this session): the family string is
  **`Cascadia Code NF`**, not `CaskaydiaCove Nerd Font`.
- Locked decision 9: desktop, tuned for performance — prefer the
  GPU-accelerated path, which is why alacritty won.
- CLAUDE.md theming rule: `config/dunst` and `config/picom` must never
  enter `symlinks.sh` because the engine rewrites those whole files.
  `config/alacritty` is safe to symlink precisely because the engine
  writes only the imported cache file, never `alacritty.toml`.
- CLAUDE.md rule 6: `install-suckless.sh` treats `autostart.sh` and
  `.xinitrc` as user-owned. `config.h` is likewise generated from
  `config.def.h` once and then left alone.

## References

- `config/theme/templates/always/README.md` — the two existing target
  styles. This task adds a third: static import of a cache-rendered file.
- `scripts/theme/apply-templates.sh:164` — the install-check is
  `[[ -d "$(dirname "$target")" ]]`; `$cacheDir` is created up front at
  line 35, so a `${cacheDir}` target is never skipped.
- `scripts/theme/reload.sh` — no alacritty step needed if
  `live_config_reload` picks up the imported file.
- `suckless/dwm/config.def.h:13,14,108` — fonts and `termcmd`.
- `scripts/install-restore.sh:96` — builds manifest CONFIG rows from
  `symlinks.sh --list-links`, so uninstall coverage is automatic once the
  pair is added to `LINKS`.

## Notes

Verified this session against alacritty 0.17.0 on the dev host:

- **A missing import does not block startup.** `alacritty --config-file
  <cfg> -e true` with `general.import = ["/nonexistent.toml"]` exits 0
  with an empty stderr. This is what makes the cache-import design safe
  on a fresh install before the engine has ever run.
- **Imports are tracked as loaded config files.** The `-vv` log prints
  `Configuration files loaded from:` listing *both* `main.toml` and the
  imported file — that list is what the config watcher watches.
- **Not verified end-to-end:** an actual live reload after rewriting the
  imported file. Alacritty windows would not stay alive long enough in
  this sandbox to observe it (they exited at ~1.4-2.3 s). Treat "no
  `reload.sh` step needed" as designed-and-plausible, not proven, and
  confirm on real hardware.

`--class` takes `<general>` or `<general>,<instance>` — relevant to
sub-task 11, not here.
