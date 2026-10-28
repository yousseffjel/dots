# Theming

The desktop takes its colours from your wallpaper. Pick a new wallpaper and dwm, the bar, dmenu, the terminals, the
lock screen, notifications, the compositor's borders, GTK and Qt apps, the prompt and vim all re-colour to match,
with no logout.

There is **no light mode**. Even a white wallpaper produces a dark palette.

This page is about using it. [docs/THEMING.md](https://github.com/YoussefFjel/dots/blob/main/docs/THEMING.md) has
the full detail, and [Theming Engine](Theming-Engine) explains how it works inside.

## Two ways to colour the desktop

- **Wallpaper colours** (called *wallbash*): four dominant colours are pulled out of the image, and a full palette
  is built from them. Every wallpaper change does this.
- **A static theme**: a fixed, hand-picked palette. Four ship: `dark` (Catppuccin Mocha), `gruvbox`, `nord` and
  `tokyo-night`.

A fresh install applies `dark`, then opens on a random image from the wallpaper collection (below) with that
image's colours.

Whichever you chose last is what a later `dots update` keeps.

## Keys

| Keys | Action |
| --- | --- |
| `Super` + `w` | A random wallpaper from your collection, and its colours |
| `Super` + `Shift` + `w` | Pick a wallpaper from a list, and its colours |
| `Super` + `Shift` + `t` | Theme menu: a static theme, or `wallbash` for the current wallpaper's colours |

## From a shell

```sh
dots wallpaper --random            # same as Super+w
dots wallpaper --select            # same as Super+Shift+w
dots wallpaper ~/Pictures/foo.png  # a specific image
dots theme --list                  # the static themes
dots theme nord                    # switch to one
dots theme --wallbash              # back to the current wallpaper's colours
```

`dots wallpaper --help` and `dots theme --help` list every option.

## Wallpapers

Wallpapers are read from `wallpapers/` in your pictures folder (`~/Pictures/wallpapers` unless you have moved or
localised it). Set `DOTS_WALLPAPER_DIR` to use another folder. The picker searches subfolders, so drop your own
images in anywhere under it.

**The collection.** No image is committed to the repo. The installer shallow-clones a separate wallpaper repo into
`wallpapers/dots/`: about 400 MB to download. A new install opens on a random image from it. `dots update` pulls new
images into it. To skip it, install with `DOTS_WALLPAPER_REPO=` (empty); to use another collection, set that
variable to its git URL.

**A generated wallpaper.** Each static theme also renders a plain gradient wallpaper from its own palette, used
until you pick an image. A wallpaper you chose is never replaced by a theme switch.

**A new wallpaper at every login:**

```sh
dots wallpaper --login-random on   # off turns it back off; status prints which
```

An `~/.xinitrc` written before this option existed does not read it. The command says so and prints the lines to
add.

## What a theme switch changes

Switching to a static theme changes the colours, and also the theme's **identity**: the GTK theme, icon theme,
cursor and UI font, written to `~/.config/gtk-3.0/settings.ini` and xsettingsd's config. All four shipped themes
currently use the same identity: `Adwaita-dark`, `Papirus-Dark` icons, the Bibata cursor and Noto Sans 10.

A `settings.ini` or `xsettingsd.conf` you wrote yourself is never overwritten: the switch prints a yellow line saying
the identity was not applied there.

## GTK and Qt apps

- **GTK 3 and 4** apps take the wallpaper's accent colours from a generated `gtk.css`. GTK 4/libadwaita apps,
  Firefox and Electron apps get dark mode from the desktop portal. GTK 2 apps get a generated `~/.gtkrc-2.0`.
- **Qt 5 and 6** apps are themed through qt5ct and qt6ct, from the same palette. Open apps re-colour on their own.
  A new install needs one logout before Qt apps pick it up. A `qt5ct.conf` or `qt6ct.conf` you already had is left
  alone. See [docs/DESKTOP.md § Qt apps](https://github.com/YoussefFjel/dots/blob/main/docs/DESKTOP.md#qt-apps).
- **Flatpak apps** get read-only access to your icons, GTK 3 config, fonts and themes.

## The login screen

The ly login screen can take a static theme's colours too:

```sh
dots login-theme            # the active theme
dots login-theme gruvbox    # a specific one
dots login-theme --restore  # ly's original values
```

It edits five keys of `/etc/ly/config.ini`, which is root's, so it asks for your sudo password. Every
`dots theme <name>` also runs it. From `Super` + `Shift` + `t` nobody can type a password, so if sudo would ask, ly is
left alone and a notification names the command to run. Wallpaper colours are never written to ly.

On the Linux console each colour becomes one of 16, so the border is the nearest bright console colour, not the
theme's exact accent.

## Fonts

Terminals, the bar and dmenu use **Cascadia Code NF**, which ships with dots, so the bar's icons render. GTK apps
use Noto Sans. Arabic text falls back to a matching Noto Arabic face. See
[docs/FONTS.md](https://github.com/YoussefFjel/dots/blob/main/docs/FONTS.md).

## When the colours do not change

Run `dots doctor` first. The common causes and fixes are in
[docs/THEMING.md § Troubleshooting](https://github.com/YoussefFjel/dots/blob/main/docs/THEMING.md#troubleshooting)
and on [Troubleshooting](Troubleshooting).
