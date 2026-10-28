# Architecture

This page is the map a contributor needs before changing anything: where things live, how an install runs,
how dots remembers what it did, and why some configs are symlinked while others are copied.

The dense internal reference is [CLAUDE.md](https://github.com/YoussefFjel/dots/blob/main/CLAUDE.md). Where it
and a script disagree, the script is right.

## The repo at a glance

| Directory | What it holds |
| --------- | ------------- |
| [`config/`](https://github.com/YoussefFjel/dots/tree/main/config) | Per-program configs (zsh, tmux, dwm runtime scripts, sxhkd, alacritty, dunst, picom, ...) and the theming templates under `config/theme/templates/` |
| [`scripts/`](https://github.com/YoussefFjel/dots/tree/main/scripts) | Both installers, their stages, `dots` and everything it dispatches to, uninstall, doctor, drivers, migrations, and the theming engine in `scripts/theme/` |
| [`packages/`](https://github.com/YoussefFjel/dots/tree/main/packages) | Package lists, one name per line, split into tiers by failure mode. See [Packages](Packages) |
| [`suckless/`](https://github.com/YoussefFjel/dots/tree/main/suckless) | Vendored, pre-patched dwm, st, dmenu, dwmblocks and slock. See [Suckless and Patches](Suckless-and-Patches) |
| [`themes/`](https://github.com/YoussefFjel/dots/tree/main/themes) | The static themes: a generated `colors.dcol` and a `theme.conf` each |
| [`assets/`](https://github.com/YoussefFjel/dots/tree/main/assets) | Vendored artifacts with checksums and licences: the cursor theme, the Nerd Font, the GTK3 `Adwaita-dark` shim |
| [`tests/`](https://github.com/YoussefFjel/dots/tree/main/tests) | The test suite. `ls tests/*.sh` is the list. See [Testing and CI](Testing-and-CI) |
| [`docs/`](https://github.com/YoussefFjel/dots/tree/main/docs) | User-facing reference docs (theming, fonts, hardware, the live installer, uninstall) |

Change logs with the reasoning behind each task live in `.claude/changes/`.

## Two entry points

There are two installers, one per starting point:

- [`scripts/install-live.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/install-live.sh) runs as
  root on the Void live ISO. It erases a disk you name, installs Void itself (optionally on LUKS), then runs the
  desktop installer inside the new system as the new user. It refuses to run unless the kernel command line
  says it booted from the live ISO. See
  [docs/LIVE-INSTALL.md](https://github.com/YoussefFjel/dots/blob/main/docs/LIVE-INSTALL.md).
- [`scripts/install-void.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/install-void.sh) is the
  desktop installer. Run it as a normal user in `wheel` on a fresh Void base install. It installs Xorg itself,
  so it assumes no GUI is present.

## The four stages

`install-void.sh` is a thin orchestrator. Each stage is its own script, runnable alone and idempotent, so a
re-run after a failure converges instead of erroring.

```text
install-void.sh [--only-<stage>] [--skip-suckless] [--dry-run]
   |
   +-- pre       install-pre.sh       xbps present? sudo? user in wheel?
   |
   +-- migrations  migrate.sh         bring an older manifest up to VERSION (always runs)
   |
   +-- install   install-pkg.sh       sync + full upgrade, then core / desktop / extra tiers,
   |             |                    then nonfree repo + sublime-text4 + drivers
   |             +-- install-suckless.sh   build.lst, make + make install, autostart.sh, ~/.xinitrc
   |
   +-- restore   install-restore.sh   ZDOTDIR, symlinks.sh, the dots symlink, wallpapers,
   |                                  theme base configs + identity, app configs, Flatpak, PipeWire
   |
   +-- services  install-services.sh  login shell -> zsh, runit services, groups, ly on tty2
   |
   +-- stamp "complete" in the manifest (full, non-dry runs only)
```

What each stage owns:

- **pre** only checks. It stops early, with the fix, on a non-Void system, without `sudo`, or when the user is
  not in `wheel` (every privileged step goes through `sudo`).
- **install** owns packages. Void has no partial upgrades, so it always syncs and does a full `-u` upgrade
  first. Then one xbps transaction per tier (see [Packages](Packages)), then the nonfree repository, the default
  editor, and `dots drivers`. The suckless build is the second half of this stage and installs its own build
  dependencies, which is why `--skip-suckless` needs no special handling anywhere.
- **restore** owns everything in `$HOME`: config links and copies, the theme, the `dots` command.
- **services** owns system state that is not a package: the login shell, runit service links, group
  membership, and ly, built from source with pinned versions and placed on tty2. tty1's getty is left alone as
  a rescue login.

`--only-<stage>` flags combine; with none, all four run. `--dry-run` is threaded through every stage and must
never mutate anything. When you add a step, honour `DRY_RUN` in it.

## The install manifest

Every file, link, package, service or repository the installer creates gets a row in
`${XDG_STATE_HOME:-~/.local/state}/dots/manifest`. It is one tab-separated file; the first field is the row
kind. The helpers are in [`scripts/global_fn.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/global_fn.sh):

- `manifest_append_row KIND field...` appends unless the identical row exists, so re-runs never duplicate.
- `manifest_upsert_row` replaces a row whose last field changes between runs (a config's backup path).
- `manifest_set_meta` / `manifest_get_meta` hold `version`, `commit`, `date` and the `complete` stamp.
- `manifest_has_path KIND path` answers "did we create this?".

Do not keep a list of row kinds anywhere: `grep -rn manifest_append_row scripts/` is the list. As a sense of
their shape, there are kinds for symlinked configs, built binaries, packages, services enabled and disabled,
repositories, theme files, copied app files, root-owned system files, the login shell, and ly's build.

The rule that matters: **a row is written only for something this run actually created.** A package that was
already installed, or a config the user already had, gets no row. That is what makes uninstall safe.

[`scripts/uninstall.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/uninstall.sh) reads the manifest
category by category, one sourced `uninstall-*.sh` helper per area, confirming each step unless `--yes` is
given. It removes only what has a row, restores backups where one was taken, and refuses files that changed
since install where that matters (root-owned system files are removed only while unedited). It refuses to run
as root.

If you add anything the installer creates, add its row and its uninstall step in the same change.
[`tests/install-uninstall-symmetry.sh`](https://github.com/YoussefFjel/dots/blob/main/tests/install-uninstall-symmetry.sh)
runs restore twice and uninstall once in a sandboxed `HOME` and requires the result to match the start, apart
from documented leftovers.

## Symlinked or copied

[`scripts/symlinks.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/symlinks.sh) links whole
directories from `config/` into `~/.config`. Its `LINKS` array is the only list; `symlinks.sh --list-links`
prints it for tests and `dots doctor`. A conflicting path is moved to `~/.dotfiles-backup/<timestamp>/` first,
and `symlinks.sh --restore [timestamp]` undoes that.

Linking means an edit in the repo reaches the running desktop with no re-run. But a program that **writes** its
own config would then be writing into the git repo. So these are copied instead, never linked:

- **dunst and picom**: the theming engine rewrites the whole file on every wallpaper change.
- **Thunar, the Xfce helpers and `mimeapps.list`**: the apps and GIO rewrite them in place.
- **autorandr's directory**: `autorandr --save` writes profiles there.
- **the Xorg touchpad snippet**: copied to `/etc/X11/xorg.conf.d` with `sudo`, laptops only.

A copied file is claimed in the manifest only when this run created it; a file the user already had is left
alone and never claimed. The app files (Thunar, Xfce, mime) are replaced on a re-run only while the claimed
copy still matches a version the repo once committed, so local edits survive. Some files have no static copy
at all and are written only by their template (GTK's `gtk.css`, fastfetch's config). See [Theming Engine](Theming-Engine).

Never add a copied category to `symlinks.sh`.

## The `dots` command

[`scripts/dots`](https://github.com/YoussefFjel/dots/blob/main/scripts/dots) is symlinked to `~/.local/bin/dots`
by the restore stage. It is a thin dispatcher: each subcommand forwards its arguments untouched to an existing
script, and every one of those scripts still runs on its own.

Its `SUBCOMMANDS` array is the **only** declaration of the subcommand list. `dots --help`, the zsh completion and
[`tests/dots-dispatch.sh`](https://github.com/YoussefFjel/dots/blob/main/tests/dots-dispatch.sh) all read it back.
Adding a subcommand is a one-line change there; do not restate the list in docs or help text.

It is the one script that does not use the usual `SCRIPT_DIR` idiom. It is reached through a symlink, so
`cd "$(dirname ...)"` would land in `~/.local/bin`; it resolves itself with `readlink -f` instead.

`~/.local/bin` comes before `~/.config/dwm/bin` on `PATH`, so the deploy claims exactly one name there.

## Runtime scripts

`config/dwm/bin/` holds the `dwm-*` scripts behind keybinds and the bar (launcher, menus, screenshot, lock,
brightness, and so on). The directory is symlinked and put on `PATH` by `config/zsh/.zshenv`, so a change to a
script reaches every install without a re-run. Files named `dwm-lib-*.sh` are sourced helpers, mode 644 so
dmenu never lists them.

## Versions and migrations

`VERSION` is recorded in the manifest. On every run `migrate.sh` walks
`scripts/migrations/<old>-to-<new>.sh` from the installed version to the repo's, and stops at a missing step.
That is why every release ships a migration script, even a no-op one. See [Contributing](Contributing).
