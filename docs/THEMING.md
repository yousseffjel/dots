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
         |   ... and the app templates, which need no reload step:
         |     alacritty-colors.toml  starship.toml  wallbash.vim
         |     fastfetch/config.jsonc           (see "App templates")
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

The installer puts a single `dots` command on `$PATH` (a symlink to
`scripts/dots`), which forwards to the scripts below with arguments untouched:

```sh
dots wallpaper --select        # dmenu picker
dots wallpaper --random
dots wallpaper ~/pics/foo.png

dots theme --list
dots theme dark                # static palette
dots theme --wallbash          # re-derive from current wallpaper
```

Every subcommand is the corresponding script, so `dots theme --list` is exactly
`scripts/theme/theme-apply.sh --list`. Run the scripts directly when working in
a checkout that is not the installed one — nothing requires the dispatcher:

```sh
scripts/theme/theme-apply.sh --list
scripts/theme/reload.sh        # re-signal everything, no regen (no subcommand)
```

Wallpapers come from `~/Pictures/wallpapers`; override with
`DOTS_WALLPAPER_DIR`.

## App templates

Four templates theme ordinary applications rather than the desktop shell.
None of them appears in `reload.sh`: each app re-reads its config on its own,
so there is nothing to signal.

| Template | Writes | Picked up |
| --- | --- | --- |
| `alacritty.dcol` | `~/.cache/dots/theme/alacritty-colors.toml` | `alacritty.toml` imports it; `live_config_reload` re-reads it |
| `starship.dcol` | `~/.cache/dots/theme/starship.toml` | every prompt is a fresh `starship` process |
| `fastfetch.dcol` | `~/.config/fastfetch/config.jsonc` | read on each run |
| `vim.dcol` | `~/.vim/colors/wallbash.vim` and/or `~/.config/vim/colors/` | `:colorscheme wallbash` |

### starship

starship has **no include directive**, so a palette cannot be spliced into
the live config the way alacritty imports a second file. Instead:

- `config/starship/starship.toml` — the authored config, symlinked to
  `~/.config/starship/`. It ends with the marker line
  `# ### dots-theme palette ###` followed by a default `[palettes.dots]`
  table, and its five themed colours are referenced by name (`c_dir`,
  `c_git_branch`, `c_git_status`, `c_git_status_bg`, `c_time`).
- `starship.dcol` renders **only** that palette table, then its post-command
  writes a whole themed copy to `~/.cache/dots/theme/starship.toml`:
  everything above the marker in the repo config, plus the fresh table.
- `conf.d/99-prompt.zsh` points `$STARSHIP_CONFIG` at the themed copy **when
  it is newer than the repo config**, and at the repo config otherwise.

Editing the prompt therefore takes effect immediately (the repo file becomes
newer, so it wins) at the cost of dropping the wallpaper colours until the
next wallpaper change or `theme-apply.sh` run. That is the safe direction:
you lose the theme, never the edit.

Only the palette table is duplicated between the two files — the prompt's
structure lives once. Adding a themed colour means two edits: a `c_*` entry
in `starship.dcol`, and its default under the marker in `starship.toml`.

The `[palettes.dots]` table must exist in the repo config even unthemed. A
`palette` naming a table that is not there does not fall back silently: the
modules lose their colour and starship writes
`Could not find color palette: dots` to stderr twice on the first prompt of
each shell session — once per new terminal, not once per render, because it
dedupes through `$STARSHIP_CACHE/session_<key>.log`.

### fastfetch

There is **no `config/fastfetch/` in this repo**. `fastfetch.dcol` is the
only authored copy and it writes `~/.config/fastfetch/config.jsonc` whole,
the same arrangement `gtk.css` uses. `scripts/install-restore-theme.sh` has
to cover two things a copied base config would give for free — creating
`~/.config/fastfetch` (or the engine's install-check skips the template as
"app not installed"), and claiming the path in the install manifest so
`uninstall_theme` removes it. Both live in `theme_claim_fastfetch`.

Consequence: until a theme has been applied, fastfetch runs on its own
built-in defaults. On the documented headless fresh-server path that means
running `dots theme dark` after the first `startx`.

Two colours are themed — `display.color.keys` and `display.color.title`. The
`colors` module at the bottom of the output prints the terminal's own
16-colour palette, which `xresources.dcol` and `alacritty.dcol` theme
separately, so it doubles as a visual check that the whole engine ran.

**A typo in a module name is silent.** fastfetch rejects malformed JSON and
rejects an unsubstituted `<wallbash_*>` left in a colour ("invalid RGB color
code found"), but an unknown module `type` is ignored with exit status 0 and
the module simply vanishes from the output. `tests/fastfetch-template.sh`
therefore asserts on the rendered module names, not just the exit code.

### vim

`vim.dcol` renders to the cache and copies into `~/.vim/colors/` and
`~/.config/vim/colors/` for whichever of those directories exists, because
vim creates neither on its own and the engine's install-check would skip a
template pointed straight at them. Nothing is written if neither exists.
Neither `vim` nor a colourscheme loader is added to `packages/*.lst` — the
template themes vim if you have it and does nothing if you do not.

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
- **picom is a themed target in name only.** `picom.dcol` has no
  `<wallbash_*>` placeholders left. It had exactly one — `shadow-color` —
  and the performance pass dropped shadows entirely, which retired it. The
  template is kept anyway so that every deployed config still has a
  template behind it, but it now regenerates a file byte-identical to
  `config/picom/picom.conf` on every wallpaper change. Deleting it was
  weighed and declined.

  The consequence is a maintenance trap: **`config/picom/picom.conf` and
  `config/theme/templates/always/picom.dcol` must be edited together.** The
  first is what a fresh install gets; the second is what every wallpaper
  change writes over it. A setting changed in only one looks correct after
  install and is silently reverted the first time the wallpaper changes.
  `tests/picom-lockstep.sh` generates from the template and diffs the two,
  so that drift fails a test instead of surfacing weeks later.

## How reload works, per tool

| Tool | Reads colours from | Reload mechanism |
| --- | --- | --- |
| dwm | `dwm.normbgcolor`, `dwm.selbgcolor`, … | `kill -HUP` — the restartsig patch re-execs dwm, which re-reads xresources at startup |
| st | `st.background`, `st.color0`–`15`, … | `pkill -USR1` — the signal-reload patch re-reads in place, so running shells survive |
| dmenu | `dmenu.background`, `dmenu.selbackground`, … | next invocation (dmenu is short-lived) |
| slock | `slock.initcolor`, … | next invocation |
| dwmblocks | `statusbar-colors.sh` | restart — block scripts read the palette at exec time, so there is nothing to signal |
| dunst | its own generated `dunstrc` | killed; D-Bus reactivates it on the next notification |
| picom | nothing — see below | `pkill -USR1` reloads config in place |
| GTK 3 | generated `gtk.css` | none needed — GtkCssProvider watches the file |
| xsettingsd | nothing — see below | `pkill -HUP` re-reads its config and pushes to every GTK client |

dmenu, powermenu and clipmenu pass **no** `-nb/-nf/-sb/-sf` flags on
purpose: dmenu's CLI colour flags override X resources, so passing them
would pin the menus to compiled-in colours and they would never follow
the theme.

### xsettingsd is in the sweep but carries no palette

`~/.config/xsettingsd/xsettingsd.conf` is written by
`theme_write_xsettingsd_conf` in `scripts/install-restore-theme-identity.sh`,
**not** by a `.dcol` template, and that is deliberate. Every template under
`config/theme/templates/always/` re-renders on each wallpaper change because
its content is palette-derived. xsettingsd's is not: it holds the GTK theme
identity (theme name, icons, cursor, font) read from `themes/dark/theme.conf`,
plus the Xft font-rendering keys — `Xft/Antialias`, `Xft/Hinting`,
`Xft/HintStyle`, `Xft/RGBA` — which live nowhere else in this repo
(`xresources.dcol` carries colours only). A wallpaper change touches none of
it, so a template would rewrite an identical file every time.

It is still in `reload.sh`'s sweep so that an installer re-run or a
`theme.conf` edit applies without a logout.

**`Xft/DPI` is deliberately absent.** XSETTINGS expects 1024ths of an inch, and
hardcoding `96 * 1024` would override X's own autodetection and render wrong on
any HiDPI panel. Add the key only if `themes/dark/theme.conf` grows a `dpi=`
entry to source it from.

**What it does not do:** xsettingsd has no CSS channel, so it plays no part in
the wallpaper-driven accent colours. Those are `gtk.css`, which GTK re-reads on
its own. If you are chasing a GTK app that ignores a new palette, xsettingsd is
not the lever.

## Static themes

`themes/<name>/` holds:

- `colors.dcol` — the palette (same format `colorgen.sh` emits)
- `theme.conf` — gtk/icon/cursor theme names and font
- `wallpapers/` — optional

Four ship: `dark` (Catppuccin Mocha), `gruvbox`, `nord` and `tokyo-night`.
Switch with `theme-apply.sh <name>`, or `Super+Ctrl+w` for the dmenu picker.

### What a switch changes

Both halves of the theme, which is why `theme-apply.sh` processes both template
groups where `wallpaper.sh` processes only `always/`:

- **Colours** — `colors.dcol` through the template engine, as for a wallpaper.
- **Identity** — `theme.conf`'s GTK theme name, icons, cursor and font, rendered
  into `~/.config/gtk-3.0/settings.ini` and `~/.config/xsettingsd/xsettingsd.conf`
  by the writers in `scripts/install-restore-theme-identity.sh`. Not a template:
  none of it is palette-derived, so a `.dcol` would re-render an identical file
  on every wallpaper change (same reasoning as `xsettingsd.conf` itself).

`theme.conf` is optional. A theme without one changes colours and leaves the
identity as it was.

### The no-clobber rule

The identity writers refuse any `settings.ini` or `xsettingsd.conf` the manifest
does not record as ours — a hand-written one survives a theme switch and gets a
yellow line saying the identity was not applied there. The difference between
the two callers is only what happens to a file we *did* write: the installer
leaves it alone (you may have edited it since), a theme switch replaces it
(that is the point of switching). Both are covered by `tests/theme-identity.sh`.

### All four currently share one identity

Every shipped `theme.conf` names `Adwaita-dark` + `Papirus-Dark`, because this
repo declares exactly one dark GTK theme — Adwaita-dark is a GTK3 built-in and
`packages/extra.lst` adds no other. The values are repeated per theme rather
than inherited so that each theme *can* state its own; install another GTK theme
and edit one line to see the switch apply it.

### Adding a theme

Copy `themes/dark/`, then replace `colors.dcol`. Generate rather than hand-write
it — the engine guarantees the file parses and carries every key a template can
reference, which hand-written hex does not:

```sh
# a seed image of four equal blocks: background, then three accents
magick -size 256x256 xc:'#1a1b26' -size 256x256 xc:'#f7768e' \
       -size 256x256 xc:'#7aa2f7' -size 256x256 xc:'#9ece6a' \
       +append /tmp/seed.png
scripts/theme/colorgen.sh /tmp/seed.png
# then take ~/.cache/dots/theme/colors.dcol, drop its `# dcol_cache_key=` line,
# and give it a header saying which colours seeded it
```

`colorgen.sh` k-means-clusters the image to four colours and sorts them by
perceptual luminance, darkest first — so the darkest block becomes `dcol_pry1`
(the background) and the accent order follows brightness, not the order you
passed them. Each theme's committed header records its seed hex, so any of them
can be regenerated exactly.

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

**The compositor settings never seem to apply.** Check `pgrep -x picom`
first. `~/.config/picom/picom.conf` is deployed by the installer and rewritten
by `picom.dcol` on every wallpaper change, but neither of those *starts*
picom — the autostart hook does, and `scripts/theme/reload.sh` only signals a
picom that is already running. On an `autostart.sh` that predates 2026-08-07
the launch line is absent, because that file is yours once it exists and the
installer will not edit it; `install-suckless.sh` prints the line to paste.

**A template was skipped.** Its target's parent directory does not exist,
meaning the app is not installed. Install it and re-run. The one case where
that inference is wrong is `fastfetch`, whose directory is created by
`scripts/install-restore-theme.sh` rather than by fastfetch itself — if it
is skipped, run `scripts/install-fedora.sh --only-restore`, or just
`mkdir -p ~/.config/fastfetch` and re-apply.

**The prompt is not themed.** `conf.d/99-prompt.zsh` only prefers the themed
copy while it is newer than `~/.config/starship/starship.toml`, so any edit
or `git pull` touching the repo config hands the prompt back to it. Re-apply
the theme, then open a new shell — the choice is made once per shell, at
startup. `echo $STARSHIP_CONFIG` tells you which one you got.

**The prompt lost its colours and warns about a palette.** The
`[palettes.dots]` table at the bottom of `starship.toml` was removed, or the
`# ### dots-theme palette ###` marker above it was. The marker is also what
`starship.dcol` cuts at, so without it the theming silently stops too.

**Everything is stale after editing a template.** Templates are read at
apply time, so re-run `wallpaper.sh`/`theme-apply.sh`. `colorgen.sh` is
cached on wallpaper path+mtime — pass `--force` to regenerate the palette
itself.

## Uninstall

`dots uninstall` (or `scripts/uninstall.sh`) removes deployed theme files
(tracked in the manifest as `THEME` rows) and the whole generated
`~/.cache/dots/theme` cache. `~/.fehbg` is left alone — it records the user's
wallpaper choice and is normally feh's own file.

The vendored cursor theme is a `THEME` row too, so it comes out with the rest.
It is the one THEME entry that is a directory rather than a file, which works
because `uninstall_theme` uses `rm -rf` — see `assets/cursors/README.md`.

`gtk.css` and `fastfetch/config.jsonc` are removed too even though the
installer never wrote their contents: both are claimed as `THEME` rows at
install time precisely so uninstall can reach them. A file that already
existed at either path when the installer ran is deliberately *not* claimed,
and so is left behind — `uninstall_theme` deletes every `THEME` row outright,
and leaving a stray file is recoverable where deleting someone else's config
is not.

Removing the theme cache also removes `starship.toml` from it, at which point
`conf.d/99-prompt.zsh` falls back to the repo config on the next shell.
