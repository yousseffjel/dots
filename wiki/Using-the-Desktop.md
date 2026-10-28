# Using the Desktop

The everyday tools beyond window management: screenshots, recording, the clipboard, notifications, files and the
rest. For the keys alone, see [Keybindings](Keybindings). Every `dwm-*` command named here lives in
[config/dwm/bin/](https://github.com/YoussefFjel/dots/tree/main/config/dwm/bin), is on your `PATH`, and explains
itself in its header comment.

## Screenshots

| Keys | Captures | Goes to |
| --- | --- | --- |
| `Print` | Your choice: full, monitor, window or region | Your choice: clipboard, file or both |
| `Super` + `a` or `Shift` + `Print` | A region you drag | Clipboard |
| `Super` + `Shift` + `a` | A region, after 3 seconds | Clipboard |
| `Super` + `Alt` + `p` | Every screen | Clipboard **and** a file |

- **full** is all your screens in one image; **monitor** is the one under the pointer; **window** is the
  *focused* window, not one you click.
- **Selecting a region:** the screen freezes the moment you press the key, and you drag on that frozen picture. So
  an open dropdown or menu is in the shot even though it closes afterwards. Escape or the right button cancels. A
  click with no drag selects nothing. Without python3-gobject it falls back to the older maim and slop selector.
- `Super` + `a` is read without a key grab, so a browser keeps its dropdown open while you press it. Terminals are
  set up to ignore it rather than type an "a".
- **Files** go to `screenshots/` in your pictures folder, named `dots-screenshot-YYYYmmdd-HHMMSS.png`. Set
  `DOTS_SCREENSHOT_DIR` to change that.

From a shell: `dwm-screenshot --region`, `dwm-screenshot --full --both`, `dwm-screenshot --monitor --clipboard`, and
`--delay N` before any of them.

## Screen recording

`Super` + `r` asks **full**, **monitor** or **region**, and starts recording. The same key stops it and tells you
where the file went: `recordings/` in your videos folder (`~/Videos/recordings` by default, or `DOTS_RECORD_DIR`).
Recordings are video only, VP9 in WebM.

## Clipboard and pickers

- `Super` + `v` opens the **clipboard history** (clipmenu) in dmenu. Pick an entry to put it back on the clipboard.
- `Super` + `c` samples the pixel under the pointer: its hex goes to the clipboard, and a notification shows the
  swatch.
- `Super` + `;` opens an **emoji picker**; the pick is copied to the clipboard.

## Notifications and focus mode

Notifications come from **dunst**. The bell in the bar shows how many are in the history.

- `Super` + `Ctrl` + `n`, or a left-click on the bell, opens the **notification centre**: open or delete a past
  notification, clear them all, or switch focus mode. The history lasts until you log out.
- `Super` + `Shift` + `n`, or a right-click on the bell, toggles **focus mode** (do not disturb). The bell reads
  `FOCUS` and notifications are held back, critical ones included. When it ends, they all show.

## Files and default apps

`Super` + `e` opens **Thunar**. Right-click a folder for *Open Terminal Here*, or an image for *Set as Wallpaper*,
which re-themes the desktop like `Super` + `Shift` + `w`. Removable drives are mounted automatically.

Default applications are set in `~/.config/mimeapps.list`: Thunar for folders, Firefox for web pages, PDFs and SVGs,
nsxiv for images, mpv for video and audio, File Roller for archives, and Sublime Text for text (with nvim as the
fallback). Change one with Thunar's *Open With* and *Set Default*; once you do, the file is yours and updates never
replace it. [docs/THUNAR.md](https://github.com/YoussefFjel/dots/blob/main/docs/THUNAR.md) covers the details.

## Calendar

Left-click the clock for this month's calendar under it. Click again, press Escape, or focus another window to close
it. Without python3-gobject installed, the click shows the month as a notification instead.

## Sounds

The desktop plays the freedesktop sound theme through PipeWire: a chime at login, a sound for each notification (a
different one when critical), a tick on the volume keys and a shutter for a screenshot. Focus mode is silent.

```sh
dwm-sound off      # silence all of them; dwm-sound on brings them back
dwm-sound status
```

To replace a sound, put a file of the same name in `~/.local/share/sounds/freedesktop/stereo/`.

## Night light

`Super` + `n` turns a blue-light filter on or off. It follows fixed times: full daylight (6500 K) from 07:00 to 19:00,
full night (4000 K) from 20:00 to 06:00, with a gradual change in between. There is no location lookup; to move the
times, edit the constants at the top of `config/dwm/bin/dwm-nightlight`. Left-clicking the brightness block toggles
it too.

## Lock and idle

`Super` + `Shift` + `l` locks the screen. When idle, the screen fades to 40% at 9 min 45 s (any input brings it
back), locks at 10 minutes, and powers the monitor down at 11. Every suspend locks the screen first.

## Displays

`Super` + `Shift` + `d` opens the monitor layout menu: your saved autorandr profiles first, then layouts built from
the screens actually connected. Its last entry, *save this layout as a profile*, saves the current arrangement, and
plugging the same screens in again restores it. The wallpaper is repainted after every switch.

When you plug a monitor back in, dwm returns its windows to it.

## Apps that start at login

An app's own "start at login" switch (Syncthing, Discord, KeePassXC) writes an entry to `~/.config/autostart`, and
dots starts those once per login. `dwm-xdg-autostart --list` shows what would start. The desktop's own daemons are
started by `~/.local/share/dwm/autostart.sh`, which is yours to edit. See
[docs/DESKTOP.md](https://github.com/YoussefFjel/dots/blob/main/docs/DESKTOP.md#autostart-apps).

## Flatpak

Flathub is added to your user installation, so `flatpak install --user flathub <app>` works without sudo. Flatpak
apps appear in the `Super` + `space` launcher, follow the GTK theme, icons and fonts (read-only), and reach the
keyring through the desktop portal.

## Passwords and the keyring

gnome-keyring stores passwords for browsers, VS Code and git credential helpers, and ly's login unlocks it. If an
app keeps asking for the keyring password, see
[docs/DESKTOP.md § Keyring](https://github.com/YoussefFjel/dots/blob/main/docs/DESKTOP.md#keyring).
