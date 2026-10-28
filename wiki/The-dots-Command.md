# The dots Command

`dots` is the one command the installer puts on your `PATH`, as a symlink at `~/.local/bin/dots` pointing into the
repo. It is a thin front door: each subcommand forwards its arguments untouched to the script that implements it,
so `dots theme --list` is exactly `scripts/theme/theme-apply.sh --list`. Every script still runs on its own, from
any checkout.

## Getting help

```sh
dots --help            # every subcommand, with a one-line description
dots theme --help      # one subcommand's own options
```

**`dots --help` is the authoritative list.** The subcommands are declared in a single table in
[scripts/dots](https://github.com/YoussefFjel/dots/blob/main/scripts/dots), and the help, the zsh completion and the
tests all read that table. The list below covers the common ones and may not be complete.

## Common subcommands

### `dots doctor`

A read-only health report: the install, packages, the running session, theme and hardware. Each problem comes with
the command that fixes it, where there is one.

```sh
dots doctor
dots doctor --tsv      # status, section, id, detail: one line per check
```

It exits non-zero when anything failed. See [Troubleshooting](Troubleshooting).

### `dots theme`

Apply a static colour theme, or go back to the wallpaper's colours.

```sh
dots theme --list
dots theme gruvbox
dots theme --wallbash
```

### `dots wallpaper`

Set the wallpaper and re-colour the desktop from it.

```sh
dots wallpaper --random
dots wallpaper --select              # pick from a list
dots wallpaper ~/Pictures/foo.png
dots wallpaper --login-random on     # a new random wallpaper at every login
```

See [Theming](Theming) for both.

### `dots login-theme`

Give the ly login screen a static theme's colours. It needs sudo.

```sh
dots login-theme --dry-run
dots login-theme nord
dots login-theme --restore           # ly's original values
```

### `dots drivers`

Install what this machine's hardware needs: video decoding, missing firmware, microcode, and laptop packages on a
laptop. NVIDIA is reported, not installed.

```sh
dots drivers --dry-run
```

See [Laptops and Hardware](Laptops-and-Hardware).

### `dots update`

Pull the repo (fast-forward only) and re-run the installer.

```sh
dots update --dry-run                # what would come in
dots update
```

### `dots version`

The repo's version and commit, the installed version and when it was installed, the OS and dwm versions.

```sh
dots version
dots version --json
```

### `dots uninstall`

Reverse the install, using the install manifest.

```sh
dots uninstall --dry-run
```

See [Updating and Uninstalling](Updating-and-Uninstalling) for `update` and `uninstall`.

## Good to know

- **Tab completion.** zsh completes subcommand names and their flags, read from the same `--help` output.
- **If the repo moves**, `dots` reports that its target script is missing. Re-run
  `scripts/install-void.sh --only-restore` from the new location to repoint the symlink.
- **The `dwm-*` helpers** (`dwm-screenshot`, `dwm-sound`, `dwm-nightlight` and the rest) are separate commands on
  your `PATH`, not `dots` subcommands. Each takes `--help`.
