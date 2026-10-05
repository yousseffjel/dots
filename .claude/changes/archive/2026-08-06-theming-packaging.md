# 2026-08-06 — theming engine epic, sub-task 7/7: static theme + packaging + docs

Final sub-task of `.claude/tasks/scope-a-theming-engine.md`. Ships the
engine as an installable, uninstallable, documented feature.

## What changed

- `themes/dark/{colors.dcol,theme.conf,wallpapers/README.md}` — the one
  shipped static theme. `colors.dcol` is the output of this repo's own
  `colorgen.sh` over Catppuccin Mocha seed colours; `theme.conf` carries
  what a palette cannot express (GTK theme, icon theme, cursor, font).
- `themes/CREDITS.md` — attribution for HyDE (architecture), Catppuccin
  (palette seed), suckless (vendored programs).
- `packages/extra.lst` — added `ImageMagick`.
- `scripts/install-restore-theme.sh` **(new)** — sourced by
  `install-restore.sh`; copies the dunst/picom base configs, writes
  `~/.config/gtk-3.0/settings.ini` from `theme.conf`, registers THEME
  manifest rows, backs up pre-existing targets, runs the initial apply.
- `scripts/install-restore.sh` — sources the above; header updated.
- `scripts/uninstall_steps.sh` — new `uninstall_theme` step; wired into
  `scripts/uninstall.sh`.
- `scripts/theme/apply-templates.sh` — `mkdir -p "$cacheDir"` up front.
  Without it, a `${cacheDir}` template on a machine with no generated
  palette hit the missing-parent-directory guard and was skipped as
  though the app were not installed — silently dropping xresources and
  statusbar-colors.sh (i.e. every suckless tool's colours) while still
  reporting success.
- `docs/THEMING.md` **(new)**, `CLAUDE.md` project map + roadmap refresh.

## Why

Sub-tasks 1-6 built a working engine that nothing installed, nothing
removed, and nothing documented. This closes those three gaps.

## Key Technical Decisions

**Base configs are copied, never symlinked.** Carried forward from
sub-task 4. The engine rewrites `dunstrc` and `picom.conf` wholesale on
every wallpaper change (neither program has an include directive), so a
symlink per CLAUDE.md rule 7 would make every theme change write back
into this git repo. `config/dunst` and `config/picom` must stay out of
`symlinks.sh` permanently.

**Untouched means untracked.** `uninstall_theme` deletes every THEME row
outright, so only files the installer actually creates get a row. A
pre-existing user config is left alone *and* left unregistered —
registering it would turn "we did not clobber your config" into "we
deleted your config on uninstall". A stray file left behind is
recoverable; someone else's config removed is not. A separate
`THEMEBACKUP` row marks files preserved once, so a re-install does not
back up the same path again and capture our own generated content.

**`install-restore.sh` split at the 250-line cap.** It reached 263 lines,
a hard stop under `file-architecture.md`. The theming block moved to a
sourced `install-restore-theme.sh`, mirroring the existing
`uninstall.sh` -> `uninstall_steps.sh` precedent rather than inventing a
new pattern. 129 + 179 lines, every function under the 60-line cap.

**`gtk-murrine-engine` deliberately not packaged.** It was in the draft
with the comment "required by most dark GTK2/3 themes". Murrine is a
GTK2-only engine, and `theme.conf` selects `Adwaita-dark`, a GTK3
built-in that never loads it. Dropped, with a note in `extra.lst` saying
when it *would* be needed.

## Assumptions

- **Type B** — `themes/dark/` ships one theme, not a set. Alternative
  considered: seeding several Catppuccin flavours. If wrong: add
  sibling directories; `theme-apply.sh --list` already enumerates them.
- **Type C** — backups use the `~/.dotfiles-backup/<timestamp>/`
  convention `symlinks.sh` established (CLAUDE.md rule 7).

## Bugs found and fixed during audit + review

1. **`exit 0` aborted the whole restore stage.** A failed `cp` while
   backing up a pre-existing config exited the stage with a *success*
   code, skipping the zinit and TPM bootstrap clones below it —
   `install-fedora.sh` would then run the services stage believing
   restore had succeeded. Now skips only the theme apply and continues.
2. **Backup was gated on `$DISPLAY` (reviewer BLOCK).** The only backup
   step ran inside `theme_initial_apply`, which returns early when there
   is no display. On a headless Fedora Server install — the documented
   common case — nothing was backed up; when the user later followed the
   printed instruction to run `theme-apply.sh dark` by hand,
   `apply-templates.sh` overwrote their pre-existing `dunstrc` /
   `picom.conf` with no backup anywhere, since neither `theme-apply.sh`
   nor `apply-templates.sh` backs anything up. `theme_backup_preexisting`
   now runs from `restore_theme` on every real install, outside the
   `$DISPLAY` gate, and early-returns on `--dry-run`.
3. **`settings.ini` re-run message contradicted the manifest.** It
   reported "left untouched, not tracked for removal" on every re-run for
   a file the installer itself created and *had* registered. Now asks
   `theme_is_ours` like `deploy_theme_file` does.
4. **`themes/CREDITS.md` stated HyDE is MIT licensed.** `HyDE/LICENSE` is
   GPL-3.0. Corrected, with a note on why the reimplement-don't-copy rule
   is what keeps that license off this repo.
5. **shfmt drift** — the repo's own `tests/lint.sh` uses `-i 4 -ci -bn`;
   the draft was formatted without `-bn`.

## Test coverage

Verified in a fully isolated `$HOME` (`env -i` with all four XDG vars
redirected — an earlier attempt leaked to the real manifest because
`XDG_STATE_HOME` was set in the ambient environment):

- Clean install: 4 THEME rows written, files deployed.
- Re-install: idempotent, still 4 rows, no duplicates.
- Pre-existing user `dunstrc`/`gtk.css`: preserved byte-for-byte, and
  *not* registered as THEME rows.
- Pre-existing configs + `$DISPLAY` set: backed up to
  `~/.dotfiles-backup/<ts>/` before the apply, original content intact.
- Pre-existing config, **no** `$DISPLAY` (regression test for bug 2):
  backup now created anyway.
- Unwritable backup root (regression test for bug 1): stage warns, skips
  the apply, still bootstraps zinit and TPM, exits 0.
- `--dry-run`: creates neither a backup directory nor a manifest.
- `tests/lint.sh` (shellcheck + shfmt + markdownlint), `tests/pkglist.sh`,
  `tests/build.sh` all pass.

Package names verified against packages.fedoraproject.org (`dnf` is not
available on this machine): `ImageMagick` present in F43/F44/rawhide;
`gtk-murrine-engine` present but GTK2-only, hence dropped.

Reviewer subagent: BLOCK (bug 2) -> fixed -> READY.

## Follow-ups

- `themes/dark/wallpapers/` ships only a README. HyDE cannot supply
  these — its themes live in a separate `hyde-themes` repo fetched by URL
  from `Scripts/themepatcher.lst`, and no wallpapers exist in the local
  reference clone.
- Port `vim` and `cava` `.dcol` templates (reimplemented, not copied) —
  agreed this session as the next task.
- `install-fedora.sh` still has not been run end-to-end on real hardware.
- `TPM_DIR` in `install-restore.sh` hardcodes `$HOME/.local/share`
  instead of honouring `$XDG_DATA_HOME` the way `ZINIT_HOME` does.
  Pre-existing, outside this diff.
