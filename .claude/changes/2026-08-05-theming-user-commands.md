# theming-user-commands
Date: 2026-08-05
Files: 9 | Lines: +494/-7

## What changed
- **`scripts/theme/wallpaper.sh [path | --random | --select]`** — sets the
  wallpaper with `feh --bg-fill`, then runs colorgen -> apply-templates
  (always group) -> reload, and sends a dunst notification. `--select`
  opens a **dmenu** list of `~/Pictures/wallpapers` (overridable via
  `DOTS_WALLPAPER_DIR`), showing basenames but resolving back to full
  paths. Records the chosen wallpaper in `$cacheDir/wall.set`.
- **`scripts/theme/theme-apply.sh <name | --wallbash | --list>`** — applies
  a static palette from `themes/<name>/colors.dcol`, or re-derives from the
  recorded wallpaper. Processes **both** template groups, since a theme
  switch can change things a wallpaper change cannot. Records the active
  theme in `$cacheDir/theme.set`.
- **`config/dwm/bin/dwm-wallpaper` and `dwm-theme`** — thin wrappers so a
  dwm keybind can spawn a bare name. `dwm-theme` with no arguments opens a
  dmenu theme list (with `wallbash` first) so it binds to a single key.
- **`suckless/dwm/config.def.h`** — a commented-out keybind block for
  `Mod+w` / `Mod+Shift+w` / `Mod+Ctrl+w`.
- **`KEYBINDINGS.md`** — new; documents every existing binding plus the
  opt-in theming ones.
- Removed the hardcoded `-nb/-nf/-sb/-sf` flags from `dmenucmd`,
  `dwm-powermenu` and `dwm-clipmenu` (see below).

## Why
Sub-task 6 of `.claude/tasks/scope-a-theming-engine.md` — the user-facing
front door over the pipeline built in sub-tasks 2-5.

## Key Technical Decisions
**Removing the dmenu colour flags was required for the feature to work at
all.** dmenu CLI colour flags override the X resources — that precedence
was a deliberate choice back in sub-task 1 (flags beat resources, matching
xterm convention). But `dmenucmd`, `dwm-powermenu` and `dwm-clipmenu` all
passed them explicitly, so the launcher, power menu and clipboard menu
would have kept their compiled-in colours forever no matter what theme was
applied — the engine would look broken precisely where the user looks
first. With the flags dropped, all three follow the theme when one is
applied and fall back to the compiled defaults when none is.

**Keybinds ship commented out.** Enabling them changes behaviour and needs
a dwm rebuild; that should be the user's explicit choice, not a side
effect of installing a theming engine. `KEYBINDINGS.md` documents how to
turn them on, including the `config.h`-is-generated-once caveat.

**Wrappers rather than absolute paths in `config.def.h`.** dwm spawns with
`execvp` and no shell, so `$HOME` cannot expand in a `Key` entry. The repo
already solves this for `dwm-powermenu`/`dwm-clipmenu` by putting
`config/dwm/bin` on `PATH` (symlinked to `~/.config/dwm/bin` by
symlinks.sh, added to PATH by `20-path.zsh`), so the new commands follow
that same pattern instead of inventing a second mechanism. The wrappers
resolve back into the repo with `readlink -f`, so they work wherever the
repo lives.

**`~/.fehbg` is written by us, not by feh.** `wallpaper.sh` passes
`--no-fehbg` and then writes the file itself using `printf %q` for the
path. reload.sh executes this file on every reload, so its quoting needs
to be robust for pathological filenames.

## Assumptions
- **Type B** — `theme-apply.sh` only *reports* `theme.conf`'s
  gtk/icon/cursor/font values rather than applying them. Applying them
  means writing `~/.config/gtk-3.0/settings.ini` and an Xcursor default,
  which is sub-task 7's packaging work; doing it here would duplicate it.
  If incorrect: consume `theme.conf` from a `theme/`-group template.

## Test coverage
Exercised live with an isolated `HOME`/`XDG_*` and a stub dmenu:
- All three wallpaper modes (explicit path, `--random`, `--select`),
  confirming `--select` offers basenames and resolves back to full paths.
- `theme-apply.sh` static theme, `--wallbash`, `--list`, `--help`.
- `wall.set` / `theme.set` recorded; `~/.fehbg` written executable with
  correct content.
- Six error paths, each verified to exit 1 with a clear message: unknown
  theme, missing file, no argument, bad option (both scripts), empty
  wallpaper dir. `--help`/`--list` exit 0.
- dwm and dmenu both rebuild cleanly with the edited `config.def.h`.
- Repo CI (`tests/lint.sh`) passes.

### Bugs found and fixed
1. **The dmenu colour-flag override** described above — found while
   reading how the new keybinds would actually behave end to end.
2. **`theme-apply.sh --help` bled prose past the usage block** — the `sed`
   range extended two lines too far.
3. **markdownlint MD060** on `KEYBINDINGS.md` table delimiter rows.
4. **Stale comment in `suckless/dmenu/config.def.h`** (reviewer) — it
   claimed "dwm's dmenucmd overrides -nb/-nf/-sb/-sf anyway", which this
   change made false. Rewritten to describe the actual precedence and to
   say explicitly that nothing passes those flags any more, so the next
   person does not helpfully "restore" them.

## Follow-ups
- Sub-task 7 creates `themes/dark/` (so `--list` currently has nothing to
  list on a fresh checkout), deploys the gtk settings.ini that
  `theme.conf` describes, adds `feh`/`dunst`/`picom`/ImageMagick to the
  package lists, registers everything in the uninstall manifest, and
  writes `docs/THEMING.md`.
- `KEYBINDINGS.md` is maintained by hand; nothing keeps it in sync with
  `config.def.h`. Noted at the top of the file.
