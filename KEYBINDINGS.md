# Keybindings

Generated from `suckless/dwm/config.def.h`. If you edit the keybindings
there, update this file too — nothing keeps them in sync automatically.

Two modifiers are in play:

- **Mod** = `Mod1Mask` = **Alt** (`#define MODKEY Mod1Mask`)
- **Super** = `Mod4Mask` = the Windows/Command key

Bindings that spawn a program run it with `execvp` and no shell, so they
use bare command names resolved through `PATH`. `~/.config/dwm/bin` is on
`PATH` via `config/zsh/conf.d/20-path.zsh`.

## Launching

| Keys | Action |
| --- | --- |
| `Mod` + `p` | `dmenu_run` application launcher |
| `Mod` + `Shift` + `Return` | Terminal (`st`) |
| `Super` + `Shift` + `x` | Power menu (`dwm-powermenu`) |
| `Super` + `v` | Clipboard history (`dwm-clipmenu`) |

## Window focus and layout

| Keys | Action |
| --- | --- |
| `Mod` + `j` / `k` | Focus next / previous window in the stack |
| `Mod` + `Return` | Promote the focused window to master (zoom) |
| `Mod` + `Tab` | Toggle back to the previously viewed tag |
| `Mod` + `Shift` + `c` | Close the focused window |
| `Mod` + `h` / `l` | Shrink / grow the master area |
| `Mod` + `i` / `d` | Increase / decrease the number of master windows |
| `Mod` + `b` | Toggle the status bar |
| `Mod` + `t` | Tiled layout |
| `Mod` + `f` | Floating layout |
| `Mod` + `m` | Monocle layout |
| `Mod` + `space` | Toggle between the last two layouts |
| `Mod` + `Shift` + `space` | Toggle floating for the focused window |
| `Mod` + `Shift` + `f` | Toggle real fullscreen (actualfullscreen patch) |

## Tags (workspaces)

| Keys | Action |
| --- | --- |
| `Mod` + `1`–`9` | View that tag |
| `Mod` + `Shift` + `1`–`9` | Move the focused window to that tag |
| `Mod` + `Ctrl` + `1`–`9` | Toggle that tag into the current view |
| `Mod` + `Ctrl` + `Shift` + `1`–`9` | Toggle that tag on the focused window |
| `Mod` + `0` | View all tags |
| `Mod` + `Shift` + `0` | Put the focused window on all tags |

## Monitors

| Keys | Action |
| --- | --- |
| `Mod` + `,` / `.` | Focus the previous / next monitor |
| `Mod` + `Shift` + `,` / `.` | Move the focused window to the previous / next monitor |

## Scratchpads

| Keys | Action |
| --- | --- |
| `Mod` + `y` | Terminal scratchpad (`st -n spterm`) |
| `Mod` + `u` | File manager scratchpad (`ranger`) |
| `Mod` + `x` | KeePassXC scratchpad |

## Session

| Keys | Action |
| --- | --- |
| `Mod` + `Shift` + `q` | Quit dwm |
| `Mod` + `Ctrl` + `Shift` + `q` | Restart dwm in place (restartsig) |

## Mouse

| Action | Effect |
| --- | --- |
| `Mod` + left-drag | Move a window (makes it floating) |
| `Mod` + right-drag | Resize a window |
| `Mod` + middle-click | Toggle floating |
| Drag the layout split | Adjust master/stack ratio (dragmfact) |
| Click a status block | Runs the block's click handler (statuscmd) |

## Theming engine — not bound by default

The theming engine ships its keybinds **commented out** in
`suckless/dwm/config.def.h`. Enabling them changes behaviour and needs a
dwm rebuild, so it is left as an explicit choice.

To enable: uncomment the `wallselcmd` / `wallrandcmd` / `thememenucmd`
arrays and their `keys[]` entries in `config.def.h`, then rebuild:

```sh
scripts/install-suckless.sh --skip-deps
```

Note that `config.h` is generated from `config.def.h` once and then left
alone — delete `suckless/dwm/config.h` first if you already have one, or
your edit will not take effect.

| Keys | Action |
| --- | --- |
| `Mod` + `w` | Pick a wallpaper from a dmenu list, then re-theme |
| `Mod` + `Shift` + `w` | Random wallpaper from the wallpaper dir, then re-theme |
| `Mod` + `Ctrl` + `w` | Theme menu — pick a static theme or `wallbash` |

The same commands work from a shell without any rebuild:

```sh
scripts/theme/wallpaper.sh --select      # or --random, or a path
scripts/theme/theme-apply.sh --list
scripts/theme/theme-apply.sh --wallbash  # re-derive from current wallpaper
```

Wallpapers are read from `~/Pictures/wallpapers` by default; override with
`DOTS_WALLPAPER_DIR`.
