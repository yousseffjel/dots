# Theming

A dark-mode-only theming engine: point it at a wallpaper, and dwm, st,
dmenu, slock, dwmblocks, dunst, picom and GTK all re-colour to match.

Reimplements the **wallbash** architecture from
[HyDE-Project/HyDE](https://github.com/HyDE-Project/HyDE) for an X11 /
suckless stack. See `themes/CREDITS.md` for what was borrowed and how
this differs.

There is **no light mode**. `dcol_mode` is always `dark`, and colour
extraction forces the background below a luminance threshold even for a
white wallpaper.

## Architecture

```text
                  wallpaper.sh --select / --random / <path>
                                    |
                          feh --bg-fill  (sets it, writes ~/.fehbg)
                                    |
                                    v
  +-------------------------------------------------------------+
  |  colorgen.sh          ImageMagick only, no pywal/wallust     |
  |                                                               |
  |  magick -kmeans  ->  4 dominant colours                       |
  |        |             sorted dark -> light by real luminance   |
  |        |             pry1 forced dark (dark-mode floor)       |
  |        v                                                      |
  |  per primary:  txt colour  (invert + brighten, contrast floor)|
  |                9 accent shades (hue-locked HSB ramp)          |
  +-------------------------------------------------------------+
                                    |
                                    v
                  ~/.cache/dots/theme/colors.dcol
              (89 keys, cached on wallpaper path+mtime)
                                    |
                                    v
  +-------------------------------------------------------------+
  |  apply-templates.sh     always/  (every wallpaper change)     |
  |                         theme/   (theme switch only)          |
  |                                                               |
  |  line 1: target_path|post_command                             |
  |  body:   <wallbash_NAME> -> palette value                     |
  +-------------------------------------------------------------+
         |          |            |           |            |
         v          v            v           v            v
   xresources    dunstrc    picom.conf    gtk.css   statusbar-colors.sh
         |          |            |           |            |
         v          v            v           v            v
  +-------------------------------------------------------------+
  |  reload.sh                                                    |
  |                                                               |
  |  1. xrdb -merge   <- FIRST and ALONE. Everything below reads  |
  |                      the X resource database; merging after   |
  |                      signalling would apply the OLD palette.  |
  |                                                               |
  |  2. concurrently, each guarded on installed/running:          |
  |     dwm       kill -HUP     (restartsig re-exec)              |
  |     st        pkill -USR1   (in place — shells survive)       |
  |     dwmblocks restart       (blocks read colours at exec)     |
  |     dunst     kill          (D-Bus respawns it)               |
  |     picom     pkill -USR1   (config reload)                   |
  |     wallpaper ~/.fehbg      (repaint root window)             |
  +-------------------------------------------------------------+
```

## Commands

```sh
scripts/theme/wallpaper.sh --select        # dmenu picker
scripts/theme/wallpaper.sh --random
scripts/theme/wallpaper.sh ~/pics/foo.png

scripts/theme/theme-apply.sh --list
scripts/theme/theme-apply.sh dark          # static palette
scripts/theme/theme-apply.sh --wallbash    # re-derive from current wallpaper

scripts/theme/reload.sh                    # re-signal everything, no regen
```

Wallpapers come from `~/Pictures/wallpapers`; override with
`DOTS_WALLPAPER_DIR`.

Keybinds (`Super` + `w`, `Super` + `Shift` + `w`, `Super` + `Ctrl` + `w`) live
in `config/sxhkd/sxhkdrc` — see `KEYBINDINGS.md`. No dwm rebuild is needed;
they work as soon as sxhkd is installed and running.

> They used to ship commented out in `suckless/dwm/config.def.h` under `Mod` +
> `w`. **Do not re-add them there.** dwm and sxhkd both `XGrabKey()` on the root
> window, so a key claimed by both goes to whichever grabbed it first and the
> other silently gets nothing — no error, no log line.

## Writing a new `.dcol` template

Drop a file in `config/theme/templates/always/` (re-rendered on every
wallpaper change) or `.../theme/` (theme switch only — for things keyed
off `theme.conf` rather than colours).

**Line 1 is the header**, never output:

```text
${confDir}/myapp/colors.conf|myapp --reload-config
```

- Left of `|`: the target path. `${confDir}` and `${cacheDir}` expand.
  Everything else is literal — there is no `eval`, deliberately.
- Right of `|`: an optional post-command, run synchronously. Optional;
  omit the `|` entirely if there is nothing to run.
- If the target's **parent directory does not exist**, the template is
  skipped with a warning. That is the "app not installed" signal.

**The body** is copied verbatim with `<wallbash_NAME>` replaced, where
`NAME` is any `dcol_` key suffix:

| Placeholder | Value |
| --- | --- |
| `<wallbash_mode>` | always `dark` |
| `<wallbash_pry1>` .. `<wallbash_pry4>` | primaries, darkest to lightest |
| `<wallbash_txt1>` .. `<wallbash_txt4>` | readable text colour per primary |
| `<wallbash_1xa1>` .. `<wallbash_4xa9>` | accent N of primary M |
| `<wallbash_*_rgba>` | same colour as `R,G,B,255` |

Values are bare hex with no `#` — write `#<wallbash_pry1>` if you need one.

Run `scripts/theme/colorgen.sh <img>` then inspect
`~/.cache/dots/theme/colors.dcol` for the full key list.

### Constraints worth knowing

- **Palettes are parsed, never sourced.** A `.dcol` may only contain
  `dcol_NAME="VALUE"` lines and `#` comments; values are restricted to a
  conservative character set. Anything else is skipped with a warning.
  This is deliberate: a theme is data, and installing a third-party theme
  must not be equivalent to running its author's shell script.
- **xresources templates go through `cpp`.** `xrdb` preprocesses the file,
  so a literal `/*` sequence — even inside a `!` comment — opens a C block
  comment and breaks the merge, and an apostrophe opens a character
  literal and warns. Keep both out of `xresources.dcol`.
- **Generated targets must not be symlinked.** `config/dunst` and
  `config/picom` are deliberately absent from `symlinks.sh`: the engine
  rewrites those whole files, and a symlink would make every wallpaper
  change write into this git repo. The installer copies them instead.

## How reload works, per tool

| Tool | Reads colours from | Reload mechanism |
| --- | --- | --- |
| dwm | `dwm.normbgcolor`, `dwm.selbgcolor`, … | `kill -HUP` — the restartsig patch re-execs dwm, which re-reads xresources at startup |
| st | `st.background`, `st.color0`–`15`, … | `pkill -USR1` — the signal-reload patch re-reads in place, so running shells survive |
| dmenu | `dmenu.background`, `dmenu.selbackground`, … | next invocation (dmenu is short-lived) |
| slock | `slock.initcolor`, … | next invocation |
| dwmblocks | `statusbar-colors.sh` | restart — block scripts read the palette at exec time, so there is nothing to signal |
| dunst | its own generated `dunstrc` | killed; D-Bus reactivates it on the next notification |
| picom | its own generated `picom.conf` | `pkill -USR1` reloads config in place |
| GTK 3 | generated `gtk.css` | none needed — GtkCssProvider watches the file |

dmenu, powermenu and clipmenu pass **no** `-nb/-nf/-sb/-sf` flags on
purpose: dmenu's CLI colour flags override X resources, so passing them
would pin the menus to compiled-in colours and they would never follow
the theme.

## Static themes

`themes/<name>/` holds:

- `colors.dcol` — the palette (same format `colorgen.sh` emits)
- `theme.conf` — gtk/icon/cursor theme names and font
- `wallpapers/` — optional

`themes/dark/` is the one shipped theme, seeded from Catppuccin Mocha.
`install-restore.sh` writes `~/.config/gtk-3.0/settings.ini` from its
`theme.conf` and applies it, if an X session is running.

To add one, copy `themes/dark/`, replace `colors.dcol` (generate it with
`colorgen.sh` against a representative image, or hand-write it in the same
format), and adjust `theme.conf`.

## Troubleshooting

**Colours did not change.** Check `xrdb -query | grep dwm.` — if empty,
`apply-templates.sh` never ran or `xrdb -merge` failed. Run
`scripts/theme/reload.sh` (without `--quiet`) and read the per-step lines.

**dwm did not re-colour but everything else did.** dwm only re-reads on
re-exec; confirm the restartsig patch is applied and that `pidof dwm`
returns a pid.

**st did not re-colour.** The signal-reload patch must be built in —
rebuild with `scripts/install-suckless.sh --skip-deps`. Terminals started
before the rebuild keep the old binary.

**The status bar kept its old colours.** dwmblocks must actually restart;
`reload.sh` reports whether it found a running instance.

**A template was skipped.** Its target's parent directory does not exist,
meaning the app is not installed. Install it and re-run.

**Everything is stale after editing a template.** Templates are read at
apply time, so re-run `wallpaper.sh`/`theme-apply.sh`. `colorgen.sh` is
cached on wallpaper path+mtime — pass `--force` to regenerate the palette
itself.

## Uninstall

`scripts/uninstall.sh` removes deployed theme files (tracked in the
manifest as `THEME` rows) and the whole generated `~/.cache/dots/theme`
cache. `~/.fehbg` is left alone — it records the user's wallpaper choice
and is normally feh's own file.
