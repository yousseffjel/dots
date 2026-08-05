# Uninstalling

`scripts/uninstall.sh` reverses what `scripts/install-fedora.sh` did, using
the install manifest at `~/.local/state/dots/manifest` as its source of
truth — it never guesses or hardcodes what to remove.

## Quick start

```sh
scripts/uninstall.sh --dry-run   # preview every action, nothing is touched
scripts/uninstall.sh             # interactive — confirms each category below
scripts/uninstall.sh --yes       # non-interactive, auto-confirms everything
```

It refuses to run as root (it manages a per-user install) and logs every
step to `~/.local/state/dots/uninstall.log`.

If `~/.local/state/dots/manifest` doesn't exist, the script exits
immediately — either nothing was installed via `install-fedora.sh` on this
machine, or it's already been uninstalled.

## What gets removed, one category at a time

Each category below is its own confirmation prompt (or auto-confirmed
under `--yes`); declining one skips it and moves on to the next — a
partial uninstall is a normal, supported outcome, not an error.

1. **Configs.** For every config the installer symlinked
   (`~/.config/{tmux,zsh,dwm}`), removes the symlink — but only if it's
   still pointed at this repo (a target you've since replaced with
   something else, or unlinked yourself, is left alone with a warning).
   See **How backups are restored** below.
2. **Suckless binaries.** Runs `make uninstall` in each `suckless/<prog>/`
   directory the installer actually built (dwm, st, dmenu, dwmblocks,
   slock — whichever are recorded in the manifest), removing their
   binaries and man pages from `/usr/local/bin` / `/usr/local/share/man`.
3. **Packages.** Runs `dnf remove` on the packages list shown before you
   confirm — and **only** packages the installer itself installed. A
   package that was already present on your system before you ran
   `install-fedora.sh` is never recorded in the manifest in the first
   place, so it's never a candidate for removal here.
4. **Services.** Disables `ly.service` if (and only if) the installer was
   the one that enabled it — same "only what we recorded" rule as
   packages.
5. **State.** Finally offers to remove `~/.local/state/dots/` itself (the
   manifest plus `uninstall.log`). Before that happens you're offered the
   chance to save a copy of the log elsewhere first — useful if you want a
   record of exactly what was removed after the state dir is gone.

## What's kept, always

- Anything in the manifest's config target that isn't currently *this
  repo's own symlink* — e.g. if you deleted `~/.config/dwm` and replaced
  it with your own directory after installing, uninstall.sh leaves it
  alone rather than guessing you want it gone.
- Any dnf package that was already installed before `install-fedora.sh`
  ran.
- `~/.zshenv`'s `ZDOTDIR` export line (install-restore.sh appends it, but
  it's a one-line addition to a file that may contain your own content
  too — removing just that line automatically was judged too risky;
  delete it by hand if you want it gone).
- The zinit and TPM plugin-manager clones under `~/.local/share/` (not
  installer-specific state — removing them would also affect any other
  zsh/tmux config you might switch to).
- The `suckless/` build trees and object files in this repo checkout —
  `make uninstall` only touches the installed copies under `/usr/local`.

## How backups are restored

`scripts/symlinks.sh` backs up any pre-existing file at a symlink target
to `~/.dotfiles-backup/<timestamp>/` before linking over it (see its
`--restore` mode). `install-restore.sh` records the exact backup path (or
`-` if nothing was backed up) alongside each config row in the manifest at
install time.

When uninstall.sh removes a config symlink:

- If the manifest recorded a real backup path for it, that backup is
  moved back into place — you end up with exactly what was there before
  you ever ran the installer.
- If it recorded `-` (nothing was backed up because the target didn't
  exist yet, or was already this repo's own symlink from a previous run),
  the symlink is just removed — there's nothing to restore.

You can also drive `symlinks.sh --restore` directly (list available
backups with no timestamp, or restore a specific one) — this is what
uninstall.sh calls internally in spirit, though it acts on the manifest's
per-file record rather than "the most recent backup timestamp" so it stays
correct even if you've re-run the installer multiple times.

## Testing an uninstall safely

Same advice as `TESTING.md` gives for installing: don't iterate against a
machine you care about. `--dry-run` is the fast local check; for a full
real run, use the same disposable Fedora container/VM flow described
there, `install-fedora.sh` first, then `uninstall.sh`.
