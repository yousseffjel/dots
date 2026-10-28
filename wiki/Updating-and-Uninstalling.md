# Updating and Uninstalling

## Updating

```sh
dots update --dry-run   # fetch and list what would come in; change nothing
dots update
```

`dots update` pulls the repo, fast-forward only, then re-runs the installer. The installer runs any migrations
first, installs newly declared packages, rebuilds the suckless programs, and prints any lines your own
`autostart.sh` or `~/.xinitrc` still need. Arguments after `update` go on to `install-void.sh`, so
`dots update --skip-suckless` works.

It refuses, before touching anything, when it would have to make a decision for you:

- a flag `install-void.sh` does not take;
- uncommitted changes to tracked files in the repo;
- a detached HEAD, or a branch with no upstream;
- an upstream branch deleted on the remote (it names the branch and suggests `git switch main`);
- an upstream that is not a fast-forward.

**"Up to date" means the install, not just the checkout.** Even with nothing to pull, `dots update` re-runs the
installer when the last *finished* install came from an older commit. So a `git pull` you did by hand, an install
you stopped with Ctrl-C, or one run a stage at a time with `--only-<stage>`, is finished by the next `dots update`.

### After an update

- **dwm or the bar may still run the old build.** Rebuilding replaces the programs on disk, but the running copies
  keep the old code. The installer ends with the command to restart each one in place, and `dots doctor` warns
  until you do. dwm's restart keeps your windows and tags:

  ```sh
  pkill -HUP -x dwm
  pkill -x dwmblocks; setsid -f dwmblocks
  ```

- **Lines to paste.** `~/.local/share/dwm/autostart.sh` and `~/.xinitrc` are yours once they exist, and an update
  never edits them. When a new version adds something to either, the installer prints the lines to add.
- **A new ly** is built when dots pins one, but the login screen you are using is not restarted. It starts at the
  next boot. Your `/etc/ly/config.ini` is kept.

## Versions and migrations

The repo follows semantic versioning, in the `VERSION` file.
[CHANGELOG.md](https://github.com/YoussefFjel/dots/blob/main/CHANGELOG.md) says what changed in each version, in
user terms.

```sh
dots version
```

prints the repo's version and the installed one, read from the install manifest at `~/.local/state/dots/manifest`.

- A **patch** release needs nothing from an existing install.
- A **minor** release is additive, but may need a migration step: seeding a new directory, removing a file an
  older version left behind.
- A **major** release changes how configs are deployed, and always comes with a migration.

Each version step ships a migration script in
[scripts/migrations/](https://github.com/YoussefFjel/dots/tree/main/scripts/migrations), even when it does nothing.
You never run them yourself: the installer runs every step between your installed version and the repo's, in
order, before anything else.

## Uninstalling

```sh
dots uninstall --dry-run   # preview every step; nothing is touched
dots uninstall             # asks before each category
dots uninstall --yes       # confirms everything
```

**Run it from a text console (tty1), not from the desktop**, and reboot afterwards. Disabling the services the
installer enabled takes effect at once, and stopping dbus ends a graphical session.

It refuses to run as root, and logs every step to `~/.local/state/dots/uninstall.log`. Everything it removes comes
from the install manifest, so it only ever removes what the installer added. Each category is its own question.
Declining one skips it, and a partial uninstall is a normal outcome.

In order, it offers to remove:

1. The config symlinks, putting back whatever they replaced.
1. The suckless programs in `/usr/local`, and the `dots` command and bar scripts in `~/.local/bin`.
1. The theme files, font, cursor and generated cache, putting back theme configs you had before installing.
1. The app configs (Thunar, mimeapps), the dark colour-scheme preference, the Flatpak settings and Flathub remote,
   the PipeWire config links, ly's original login-screen colours, the wallpaper collection, and the laptop touchpad
   file.
1. The packages the installer installed, then Void's nonfree repository.
1. The runit services the installer enabled, giving back tty2's getty and `dhcpcd`, and the ly it built.
1. Your login shell, back to what it was.
1. Finally, `~/.local/state/dots/` itself. You can save a copy of the log first.

Anything you changed after installing is kept: an edited touchpad file, a wallpaper collection with your own
images in it, a Flathub remote that still has apps from it, a `mimeapps.list` you set defaults in.

### What is always kept

- Your group memberships. Removing `network` could lock you out of your own network settings.
- Packages that were installed before you ran the installer.
- Thunar's preferences.
- The `ZDOTDIR` line in `~/.zshenv`. Delete it by hand if you want it gone.
- The zinit and TPM plugin managers under `~/.local/share/`.
- The repo checkout and its build trees.

[docs/UNINSTALL.md](https://github.com/YoussefFjel/dots/blob/main/docs/UNINSTALL.md) covers each step in detail.

## Undoing just the config links

`scripts/symlinks.sh` backs up anything it would replace into `~/.dotfiles-backup/<timestamp>/` before linking. To
undo one run of it without uninstalling anything else:

```sh
~/dots/scripts/symlinks.sh --restore              # list the backups
~/dots/scripts/symlinks.sh --restore <timestamp>  # put that one back
```

It removes only links it made itself, and moves the originals back. A target that is no longer one of its links is
skipped with a warning.
