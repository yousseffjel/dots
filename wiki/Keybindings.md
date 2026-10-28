# Keybindings

The keys you will use most, grouped by task. This is a selection, not the full list:
[KEYBINDINGS.md](https://github.com/YoussefFjel/dots/blob/main/KEYBINDINGS.md) is the complete reference, and
`Super` + `/` shows every binding in a searchable list on the desktop itself.

Every binding is on **Super**, the Windows key. Alt is left to applications, so tmux's Alt bindings work.

## Two owners

The keys are split between two programs, and which one owns a key decides how you change it:

- **dwm** owns window management, plus the launcher, terminal, power menu, clipboard and drop-down terminal. Its
  keys are compiled in from
  [suckless/dwm/config.def.h](https://github.com/YoussefFjel/dots/blob/main/suckless/dwm/config.def.h): changing one
  means a rebuild.
- **sxhkd** owns everything else (media, volume, screenshots, theming, apps), from
  [config/sxhkd/sxhkdrc](https://github.com/YoussefFjel/dots/blob/main/config/sxhkd/sxhkdrc). Edit it and press
  `Super` + `Ctrl` + `r` to reload.

The two sets must never overlap: when both grab the same key, one of them silently gets nothing. The repo's
`tests/key-collisions.sh` checks this. See [Suckless and Patches](Suckless-and-Patches) for rebuilding dwm.

## Launching

| Keys | Action |
| --- | --- |
| `Super` + `space` | App launcher: installed graphical applications |
| `Super` + `Return` | Terminal (alacritty) |
| `Super` + `grave` | Drop-down terminal: show or hide it |
| `Super` + `Shift` + `b` | Firefox |
| `Super` + `e` | Thunar, the file manager |
| `Super` + `/` | Every keybinding, searchable |

## Windows

| Keys | Action |
| --- | --- |
| `Super` + `j` / `k` | Focus the next / previous window |
| `Super` + `Shift` + `Return` | Move the focused window into the master area |
| `Super` + `Shift` + `q` | Close the focused window |
| `Super` + `h` / `l` | Shrink / grow the master area |
| `Super` + `Shift` + `space` | Float or tile the focused window |
| `Super` + `Shift` + `f` | Fullscreen |
| `Super` + `t` / `f` / `m` | Tiled / floating / monocle layout |

With the mouse: `Super` + left-drag moves a window (a tiled one drops into another window's slot and stays tiled),
`Super` + right-drag resizes, and `Super` + middle-click toggles floating.

## Tags and monitors

| Keys | Action |
| --- | --- |
| `Super` + `1`–`9` | View that tag |
| `Super` + `Shift` + `1`–`9` | Move the focused window to that tag |
| `Super` + `Tab` | Back to the previous tag |
| `Super` + `0` | View all tags |
| `Super` + `,` / `.` | Focus the previous / next monitor |
| `Super` + `Shift` + `,` / `.` | Move the focused window to the previous / next monitor |
| `Super` + `Shift` + `d` | Monitor layout menu |

## Scratchpads

| Keys | Action |
| --- | --- |
| `Super` + `Shift` + `s` | Stash the focused window in the scratchpad |
| `Super` + `s` | Show or hide all stashed windows together |

## Screenshots, recording, clipboard

| Keys | Action |
| --- | --- |
| `Print` | Screenshot menu: choose what to capture, then where it goes |
| `Super` + `a` | Drag a region, straight to the clipboard |
| `Super` + `Alt` + `p` | Whole screen, to the clipboard and saved as a file |
| `Super` + `r` | Start a screen recording, or stop the one running |
| `Super` + `v` | Clipboard history |
| `Super` + `c` | Colour picker: the hex of the pixel under the pointer, to the clipboard |
| `Super` + `;` | Emoji picker |

## Notifications and theming

| Keys | Action |
| --- | --- |
| `Super` + `Ctrl` + `n` | Notification centre |
| `Super` + `Shift` + `n` | Focus mode (do not disturb) on or off |
| `Super` + `w` | Random wallpaper, and re-colour the desktop |
| `Super` + `Shift` + `w` | Pick a wallpaper |
| `Super` + `Shift` + `t` | Theme menu |
| `Super` + `n` | Night light on or off |

## Session and power

| Keys | Action |
| --- | --- |
| `Super` + `Shift` + `l` | Lock the screen |
| `Super` + `Shift` + `x` | Power menu |
| `Super` + `Shift` + `p` | Power profile menu (laptops) |
| `Super` + `Shift` + `Escape` | Quit dwm (log out) |
| `Super` + `Ctrl` + `Shift` + `q` | Restart dwm in place; windows and tags are kept |
| `Super` + `Ctrl` + `r` | Reload the sxhkd hotkeys |

Your keyboard's own keys work too. Volume, microphone mute and brightness show a pop-up with the new level; play,
pause, next and previous reach any player that speaks MPRIS (through `playerctl`).

## Changed keys

The keys were remapped on 2026-10-13: the launcher moved from `Super` + `p` to `Super` + `space`, the terminal to
`Super` + `Return`, close to `Super` + `Shift` + `q` and quit to `Super` + `Shift` + `Escape`. Before 2026-10-12
dwm's modifier was Alt. An older install picks up dwm's half of a remap on its next build and a logout. The
[KEYBINDINGS.md](https://github.com/YoussefFjel/dots/blob/main/KEYBINDINGS.md) note lists every move.
