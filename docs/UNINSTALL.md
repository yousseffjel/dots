# Uninstalling

`scripts/uninstall.sh` reverses what `scripts/install-fedora.sh` did, using
the install manifest at `~/.local/state/dots/manifest` as its source of
truth — it never guesses or hardcodes what to remove.

## Quick start

```sh
dots uninstall --dry-run   # preview every action, nothing is touched
dots uninstall             # interactive — confirms each category below
dots uninstall --yes       # non-interactive, auto-confirms everything
```

`dots` is the command the installer puts on `$PATH`; it forwards straight to
`scripts/uninstall.sh`, which can equally be run directly from a checkout.

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
3. **Scripts in `~/.local/bin`.** Two kinds, both recorded as `SCRIPT` rows
   and both invisible to the previous step: the dwmblocks block scripts,
   deployed by a separate `make install-scripts` target rather than
   `make install`; and the `dots` command itself, a symlink to
   `scripts/dots`. Removed from their manifest rows, so a `dots` that was
   already there and belongs to something else was never given a row and is
   left alone.
4. **Theme files.** The base configs the installer *copied* rather than
   symlinked (`~/.config/dunst/dunstrc`, `~/.config/picom/picom.conf`, the
   GTK `settings.ini`/`gtk.css`), the vendored cursor theme unpacked into
   `~/.local/share/icons/` and the GTK3 `Adwaita-dark` shim copied into
   `~/.local/share/themes/` — the two entries that are directories rather
   than files, which is why this step uses `rm -rf` (an `Adwaita-dark` that
   was already there is yours and has no row) — plus the wholly generated
   `~/.cache/dots/theme/`, and `~/.fehbg` when it points at the wallpaper
   generated there (one naming an image you picked is left alone). Copies can't be identified by a readlink check
   the way symlinks can, so these are removed by manifest row instead — and
   a file that already existed when the installer ran was never given a row,
   so it is not removed.
4a. **Theme configs you had before installing.** A pre-existing
   `dunstrc`/`picom.conf`/GTK file is left in place by the installer but
   *is* rewritten by the theming engine on the first wallpaper change, so the
   installer copies it to `~/.dotfiles-backup/<timestamp>/` first. This step
   moves each of those originals back, replacing the generated version — so
   you end up with the file you had, not the one the engine last wrote.
   Installs made before 2026-09-28 did not record where each copy went; for
   those the step says so and leaves the copy under `~/.dotfiles-backup/`.
5. **App configs.** What `install-restore-apps.sh` deployed for the file
   manager: `~/.config/Thunar/{thunarrc,uca.xml}`, `~/.config/xfce4/
   helpers.rc`, `~/.config/mimeapps.list`, and
   `~/.local/share/applications/dots-nvim.desktop`,
   `~/.config/systemd/user/dots-session.target`, plus the
   `mimeinfo.cache` next to it when the installer's desktop-database refresh
   is what created it. Same copied-file,
   manifest-row rule as the theme category above. **Thunar's preferences
   are not reverted** — they live in your xfconf `thunar` channel next to
   settings Thunar wrote itself, nothing records what they were before, and
   resetting them could not be told apart from discarding choices you made
   in Thunar's own preferences dialog afterwards.
5a. **The dark colour-scheme preference.** The installer sets dconf's
   `/org/gnome/desktop/interface/color-scheme` to `'prefer-dark'` (what the
   gtk desktop portal hands to libadwaita apps, Firefox, Chromium and
   Electron), and only when the key was unset — so, unlike Thunar's
   preferences, there was nothing earlier to lose, and this step resets it.
   It is reset only while it still says `'prefer-dark'`: if you changed it
   after installing, your choice stays. Runs before the package step, which
   may remove `dconf` itself.
5b. **Flatpak integration.** The installer adds the Flathub remote to your
   user installation and four read-only global overrides
   (`~/.local/share/icons`, `xdg-config/gtk-3.0`, `xdg-config/fontconfig`,
   `xdg-data/themes`),
   each only when it was absent. This step reverts exactly those:
   - an override is removed only while it is still the entry the installer
     wrote — one you have since changed (a different mode, a `!` negation)
     stays, and any override of your own was never touched. `flatpak` has
     no command to remove a single global grant, so the step edits
     `~/.local/share/flatpak/overrides/global` itself; your own groups in
     that file come back byte for byte, and a file only the installer wrote
     is removed;
   - the Flathub remote is removed only if the installer added it (a remote
     that already existed was never recorded) and no installed app or
     runtime still comes from it.

   Runs before the package step, which may remove `flatpak` itself.
6. **Packages.** Runs `dnf remove` on the packages list shown before you
   confirm — and **only** packages the installer itself installed. A
   package that was already present on your system before you ran
   `install-fedora.sh` is never recorded in the manifest in the first
   place, so it's never a candidate for removal here.
7. **Services.** Disables whatever `SERVICE` rows the manifest holds
   (`ly@tty2.service` on a current install) if (and only if) the installer was
   the one that enabled it — same "only what we recorded" rule as
   packages.
8. **Login shell.** Offers to switch back (`sudo usermod -s`) to whatever your login shell was
   before the installer switched it to zsh — only if the installer
   actually changed it (recorded in the manifest at that moment).
9. **State.** Finally offers to remove `~/.local/state/dots/` itself (the
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
- `~/.local/share/flatpak/` itself. flatpak creates its `repo/` and a
  summary cache there on the first `--user` command; it is flatpak's
  directory, shared with every app you install, so only the settings the
  installer made in it are reverted (step 5b).
- The Flathub remote, while any installed Flatpak still comes from it. Run
  `flatpak remote-delete --user flathub` after uninstalling those apps if
  you want it gone.
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

`tests/install-uninstall-symmetry.sh` proves the restore stage and this
script are inverses: in a sandboxed `$HOME`, restore -> uninstall must leave
every file as it was, except the leftovers listed under **What's kept,
always** — which it checks are still listed there. It covers everything the
restore stage writes; package, service, shell and suckless rows need root and
are exercised by the `install-container` CI job instead.

Same advice as `TESTING.md` gives for installing: don't iterate against a
machine you care about. `--dry-run` is the fast local check; for a full
real run, use the same disposable Fedora container/VM flow described
there, `install-fedora.sh` first, then `uninstall.sh`.
