# install-uninstall-symmetry
Date: 2026-09-28
Files: 13 + task folder | Lines: ~+400/-60

## What changed
- **New `tests/install-uninstall-symmetry.sh`** (plus `tests/lib/install-symmetry.sh`),
  scope-d slot D. In a sandboxed `$HOME` (`env -i`, all four XDG variables),
  it runs restore twice, then `uninstall.sh --yes`, and requires every file
  and symlink to be back as it was. There are two scenarios: an empty HOME,
  and a lived-in one with its own tmux config, `.zshenv` and `dunstrc`, where
  the `dunstrc` is then overwritten the way the first wallpaper apply does.
  Sentinel fakes for `sudo`/`dnf`/`systemctl`/`chsh`/`pkill`/`xrdb` must stay
  silent, and the real manifest must gain no sandbox rows.
- **Bug fixed: an unclaimed `mimeinfo.cache`.** The restore stage's
  desktop-database refresh wrote it and never claimed it, and uninstall's own
  refresh re-created it. It is now an `APP` row when (and only when) this run
  created it, and uninstall skips the refresh once no `.desktop` file is left
  and the cache is gone.
- **Bug fixed: theme configs you had before installing were never restored.**
  The installer backed up a pre-existing `dunstrc`/`picom.conf`/`gtk.css`/
  fastfetch config before the engine rewrote it, but the `THEMEBACKUP` row
  did not record where the copy went, and uninstall ignored those rows. The
  user was left with the engine's version and the original stranded in
  `~/.dotfiles-backup/`. Rows now carry the backup path (4th field), and the
  new `uninstall_theme_backups` moves each original back. Old 3-field rows
  are reported, not guessed at.
- `uninstall_theme` moved from `uninstall_steps.sh` (235/250) to a new
  `scripts/uninstall-theme.sh`, next to the new function. `uninstall_steps.sh`
  is now 196.
- Docs: `docs/UNINSTALL.md` (new step 4a, the cache, the test), TESTING.md,
  CHANGELOG, the CLAUDE.md project map, and stale "230 of the cap" comments
  in `uninstall.sh`/`uninstall-apps.sh` (the latter appended, not
  interleaved).

## Why
This is the last slot of Epic scope-d. The Epic's thesis, that verification
must RUN the thing rather than inspect its inputs, held again: both bugs had
survived every earlier review because nothing had ever run a restore followed
by an uninstall and compared the result.

## Assumptions
- **CONFLICT surfaced and resolved by the user:** `docs/UNINSTALL.md` "What's
  kept, always" leaves the `.zshenv` ZDOTDIR line and the zinit/TPM clones.
  The user chose to **honor** it (2026-09-28). The test asserts those
  leftovers exactly, and requires that the doc still names them.
- Type B deviation from scope-d decision 5 ("third snapshot equals the
  first"): directories are compared out, because the installer `mkdir -p`s
  shared XDG directories that uninstall must not rmdir.
- Type B: `uninstall_theme_backups` replaces the current file without a diff.
  Every such file is an engine template target, rewritten on each wallpaper
  change, and the prompt now says so.

## Test coverage
- Both scenarios pass. 6/6 mutations on a **sandboxed repo copy** were caught
  for the right reason: an unclaimed cache, no refresh guard, no backup path,
  an unclaimed APP file, the CONFIG backup not restored, and the backup step
  dropped. One mutant was first caught for the WRONG reason (deleting the
  line left an empty `then`, a syntax error). It was re-run with a no-op and
  is now caught by the leftover it was meant to create.
- Full `run-tests.sh` (19 run) and lint pass.
- Reviewer: WARN (a hand edit is discarded on restore). Addressed by
  verification plus disclosure; see Assumptions.

## Follow-ups
- Package, service, shell and suckless rows need root. They are covered by
  `install-container.yml`, not this test.
- Existing installs keep their old 3-field `THEMEBACKUP` rows. Their
  originals are still in `~/.dotfiles-backup/`, and uninstall now says so.
