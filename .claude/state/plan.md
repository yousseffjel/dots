# Plan

Reconstructed retroactively from the working diff (the slot was coded
without a plan file). Sub-task 7/7 of `.claude/tasks/scope-a-theming-engine.md`.

## Goal

Ship the theming engine as an installable, uninstallable, documented
feature: a static dark theme, the packages it needs, installer deployment
of the base configs, uninstall teardown, and user docs.

## Scope

- `themes/dark/{colors.dcol,theme.conf,wallpapers/README.md}`, `themes/CREDITS.md`
- `packages/extra.lst`
- `scripts/install-restore.sh` (theme deployment + manifest rows)
- `scripts/uninstall.sh`, `scripts/uninstall_steps.sh` (`uninstall_theme`)
- `scripts/theme/apply-templates.sh` (cacheDir bootstrap fix)
- `docs/THEMING.md`, `CLAUDE.md`

## Allowed

Everything under `## Scope`.

## Forbidden

- Adding `config/dunst` / `config/picom` to `symlinks.sh` — the engine
  rewrites those whole files, a symlink writes back into the repo.
- Copying GPL-3.0 sources verbatim out of `HyDE/` (CLAUDE.md rule 9).

## Steps

1. Static `themes/dark/` theme + CREDITS.
2. Package additions (ImageMagick, gtk-murrine-engine), verified upstream.
3. Installer deployment: copy base configs, write GTK settings.ini,
   register manifest rows, initial apply when `$DISPLAY` is set.
4. Uninstall teardown via THEME manifest rows + cache removal.
5. `docs/THEMING.md` + CLAUDE.md project-map/roadmap refresh.

## Out of scope

Extra app templates (vim, cava, …) — separate follow-up task.

## Risks

Clobbering a pre-existing user dunstrc/picom.conf/gtk.css, or deleting
one on uninstall that we never created.
