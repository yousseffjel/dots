# First Steps

You have run the installer and rebooted. This page covers the first login and the handful of things worth knowing
before anything else.

## Logging in

The **ly** login screen runs on tty2, which is where the machine boots to. The cursor starts on the password
field, and ly remembers the last user who logged in, so after the first login you just type your password and
press Enter. tty1 keeps a plain text login on
purpose: switch to it with `Ctrl` + `Alt` + `F1` if the graphical session ever fails to start.

Logging in through ly also unlocks your keyring, so browsers and git credential helpers can store secrets without
asking for another password.

The first login after a fresh install may take a moment longer. If the installer could not theme the desktop
(it was run from a text console, with no X session), your `~/.xinitrc` applies the dark theme once now.

## What is on screen

The bar runs along the top of each monitor:

- **Left:** the tags `1` to `9`, dwm's equivalent of workspaces. Only tags with windows on them are shown, plus the
  one you are viewing. Next to them is the layout symbol, then the focused window's title.
- **Right:** the status blocks, then the system tray. The blocks show, from left to right, free disk space, CPU temperature and load, memory, brightness, microphone, volume, network, Bluetooth, a
  notification bell, the battery (laptops only) and the clock.
- **The tray** holds the icon of any app that puts one there. There are no network, Bluetooth or drive-mounter
  applets: the bar's network and Bluetooth blocks do that job (left-click them), and a USB drive mounts with a
  click in Thunar's side pane.

Every block does something when clicked. Left-click the clock for a calendar, the volume to mute, the network to
open `nmtui`, the bell for the notification centre. Scroll over volume or brightness to change them. The full table
is in [KEYBINDINGS.md § Status bar](https://github.com/YoussefFjel/dots/blob/main/KEYBINDINGS.md#status-bar).

Windows tile automatically: the first takes the left half (the master area) and the rest stack on the right.

## The keys to learn first

Every binding uses **Super** (the Windows key).

| Keys | What it does |
| --- | --- |
| `Super` + `space` | App launcher: type part of an app's name, Enter to start it |
| `Super` + `Return` | Terminal (alacritty) |
| `Super` + `/` | Every keybinding, searchable |
| `Super` + `Shift` + `q` | Close the focused window |
| `Super` + `1`–`9` | Switch tag |
| `Super` + `j` / `k` | Focus the next / previous window |
| `Super` + `Shift` + `x` | Power menu: lock, log out, suspend, reboot, shut down |
| `Super` + `Shift` + `l` | Lock the screen |
| `Super` + `Shift` + `w` | Pick a wallpaper; the whole desktop re-colours to match |

`Super` + `/` is the one to remember: it lists every binding, read from the same document as
[Keybindings](Keybindings).

## Where your configuration lives

Most configs are **symlinks into the repo**, so editing them edits `~/dots` directly. `scripts/symlinks.sh` links
these directories into `~/.config`: `alacritty`, `dwm`, `fontconfig`, `mpv`, `starship`, `sxhkd`, `tmux`,
`xdg-desktop-portal` and `zsh` (zsh reads it through `ZDOTDIR`, set in `~/.zshenv`).

Some files are **copied** instead, because the program or the theming engine rewrites them: dunst's and picom's
configs, Thunar's settings and `~/.config/mimeapps.list`. Edit those in place.

Two files are **yours once they exist**: the session autostart script, `~/.local/share/dwm/autostart.sh`, and
`~/.xinitrc`. The installer writes them once and never edits them again. When a later version adds a line to
either, the installer prints the line for you to paste.

How a change takes effect depends on who owns it:

- **sxhkd hotkeys** (`~/.config/sxhkd/sxhkdrc`): press `Super` + `Ctrl` + `r` to reload.
- **dwm's own keys, layout and rules** are compiled in. Edit `suckless/dwm/config.def.h`, run
  `scripts/install-suckless.sh`, then restart dwm in place with `Super` + `Ctrl` + `Shift` + `q`.
- **Shell config:** open a new shell.

## Check that everything works

```sh
dots doctor
```

It checks the install, the packages, the running session, the theme and the hardware, and changes nothing. Every
line that is not **ok** names what is wrong and, where there is one, the command that fixes it. See
[Troubleshooting](Troubleshooting).

## Next

- [Keybindings](Keybindings) — the most useful keys, grouped by task.
- [Using the Desktop](Using-the-Desktop) — screenshots, recording, clipboard, notifications, files.
- [Theming](Theming) — wallpapers, colours and themes.
- [The dots Command](The-dots-Command) — `dots` and its subcommands.
