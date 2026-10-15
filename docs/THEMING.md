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
         |     fastfetch/config.jsonc  .gtkrc-2.0  (see "App templates")
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
  |     dunst     dunstctl reload (pause level kept)              |
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
dots wallpaper --login-random on   # a new random wallpaper at every login (off|status)

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

Wallpapers come from `wallpapers/` in your pictures folder (`xdg-user-dir PICTURES`, so a
localised or moved one is honoured; else `~/Pictures`); override with
`DOTS_WALLPAPER_DIR`. The default folder is created on first use and seeded
with the generated default wallpaper below, so the picker (`Super` +
`Shift` + `w`) always has something to offer. Every failure is also a notification, since the keys run
it through sxhkd, which discards error output.

### The wallpaper collection

No image is committed to this repo. The restore stage
(`scripts/install-restore-wallpapers.sh`) shallow-clones the wallpaper repo,
[yousseffjel/wallpaper](https://github.com/yousseffjel/wallpaper), into
`wallpapers/dots/` in your pictures folder. The picker searches subfolders,
so the collection shows up next to anything of your own. Its file names are
`<category>-<description>[-nord].<ext>`, so typing `space` or `nord` in the
picker filters it.

- **Download.** About 400 MB, and about 780 MB on disk (the images plus
  git's packed copy of them): a shallow clone still carries every current
  image. To skip it, run the installer with `DOTS_WALLPAPER_REPO=` (empty);
  to use another collection, set that variable to its git URL.
- **Updates.** A re-run of the restore stage, which is what `dots update`
  does, fast-forwards the clone. A failed pull (offline, or local changes
  in the way) skips the new images and never fails the install.
- **Yours or ours.** A folder already at `wallpapers/dots/` before the clone
  is left alone and never recorded. Uninstall removes the clone only while
  it is unchanged (`docs/UNINSTALL.md`, step 5c).
- **The first wallpaper.** A new install opens on a random image from the
  collection: the restore stage's theme apply runs
  `dots wallpaper --initial` after `dots theme dark`, but only on the run
  that made the clone, so an update never swaps your wallpaper. On a
  headless install `~/.xinitrc` does the same at the first login.
  A later re-run of the restore stage (`dots update` from a terminal in
  your session) re-applies the theme you are actually using, not `dark`:
  your wallpaper's colours if you last chose a wallpaper, else the static
  theme you last switched to (whichever of `wall.set` and `theme.set` in
  `~/.cache/dots/theme/` is newer).
- **Progress.** On a terminal, the clone shows git's progress; it goes to the
  terminal only, so `install.log` never fills with it.
  `--initial` picks from the collection only and does nothing without one,
  which leaves the generated wallpaper below in place.

### A random wallpaper at every login

`dots wallpaper --login-random on` makes every login pick a new random
wallpaper and re-derive the colours from it (`off` turns it back off,
`status` prints which). It is off by default. The setting is a flag file,
`~/.config/dots/random-wallpaper`, and `~/.xinitrc` reads it before dwm
starts. It cannot be done from `autostart.sh`: re-theming a running dwm
restarts it, and every dwm start re-runs `autostart.sh`. The pick is bounded
by `timeout 120`, and if it fails the last wallpaper is restored instead.

An `~/.xinitrc` written before this option existed never reads the flag, and
the installer never rewrites one that exists. `--login-random on` says so
and prints the lines to use instead of its `~/.fehbg` line:

```sh
if [ -e "${XDG_CONFIG_HOME:-$HOME/.config}/dots/random-wallpaper" ] &&
    timeout 120 "$HOME/.local/bin/dots" wallpaper --random; then :
elif [ -x "$HOME/.fehbg" ]; then "$HOME/.fehbg"; fi
```

### The generated default wallpaper

No wallpaper image is committed to this repo (see
`themes/dark/wallpapers/README.md`). Instead, every **static** theme apply runs
`scripts/theme/wallpaper-default.sh`, which renders a 2560×1440 diagonal
gradient from the palette itself — `dcol_1xa2` (a lifted tint of the
background) into `dcol_pry1` (the background) — to
`~/.cache/dots/theme/wallpapers/<theme>.png`, and points `~/.fehbg` at it.
`reload.sh` then runs `~/.fehbg`, so it is on screen in the same apply.

It **never replaces a wallpaper you chose**: `~/.fehbg` is only written when
it is absent or carries the `# dots: generated wallpaper` marker line this
script writes (uninstall uses the same marker to remove it). Once you run
`dots wallpaper <image>`, theme switches leave your image alone. To go back to
the generated one, delete `~/.fehbg` and re-run `dots theme <name>`.
`--wallbash` does not generate anything — it derives a palette *from* a
wallpaper you set. `tests/wallpaper-default.sh` covers all of this.

**After a resolution change** the wallpaper is re-painted: feh draws at the
screen size of the moment, and at every login `~/.xinitrc` draws it *before*
`autorandr --change` switches to your saved layout. The installer copies an
autorandr hook, `~/.config/autorandr/postswitch.d/10-dots-wallpaper`, that
re-runs `~/.fehbg` after every switch: at login, on hotplug, and on a profile
loaded from Super+Shift+d. `dwm-display` (Super+Shift+d) also re-runs it after its xrandr
presets. A raw `xrandr` typed by hand has no hook, so run `~/.fehbg` after one.
To keep a resolution across logins, save it once with `autorandr --save <name>`.

## App templates

Five templates theme ordinary applications rather than the desktop shell.
None of them appears in `reload.sh`: each app re-reads its config on its own,
so there is nothing to signal.

| Template | Writes | Picked up |
| --- | --- | --- |
| `alacritty.dcol` | `~/.cache/dots/theme/alacritty-colors.toml` | `alacritty.toml` imports it; `live_config_reload` re-reads it |
| `starship.dcol` | `~/.cache/dots/theme/starship.toml` | every prompt is a fresh `starship` process |
| `fastfetch.dcol` | `~/.config/fastfetch/config.jsonc` | read on each run |
| `vim.dcol` | `~/.vim/colors/wallbash.vim` and/or `~/.config/vim/colors/` | `:colorscheme wallbash` |
| `gtk2.dcol` | `~/.cache/dots/theme/gtkrc-2.0`, moved into `~/.gtkrc-2.0` | read when a GTK2 app starts |

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

### GTK 2

The GTK2 app that matters is `lxpolkit`, the password prompt for privileged
actions. `gtk2.dcol` is a **whole theme**, not overrides like `gtk.css`:
Fedora 44 retired `gnome-themes-extra`, the package that carried Adwaita-dark
for GTK2, so the `Adwaita-dark` name xsettingsd sends to GTK2 resolves to
nothing and GTK2 draws its built-in default. The rc paints that default with
plain styles — no engine, so nothing extra is installed. Icons, font and
cursor still come from xsettingsd.

The target is `~/.gtkrc-2.0`, outside `~/.config`, which the engine's tokens
cannot name. So it renders to the cache, and the post-command copies it to a
temp file and `mv`s it into place, so a GTK2 app starting mid-write never
reads half a file.

**Unlike `gtk.css`, a `~/.gtkrc-2.0` of your own is never replaced** — the
post-command only overwrites a file whose first line is the engine's
`Generated by` header, and leaves anything else (a symlink to your dotfiles
included) alone, unthemed. The stricter rule is needed because this
post-command runs on every wallpaper change, including on an install that
predates the template: nothing would have backed the file up first. The
installer claims an engine-written `~/.gtkrc-2.0` for uninstall even when it
finds one already there, for the same reason.

Keybinds (`Super` + `Shift` + `w` pick, `Super` + `w` random, `Super` + `Shift` + `t` theme) live
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
- **picom's backend is NOT taken from `picom.conf`.** The config says
  `backend = "glx"`, but `autostart.sh` runs `dwm-picom`
  (`config/dwm/bin/dwm-picom`), which passes `--backend` explicitly:
  **`xrender` in any virtual machine**, even one with 3D passed through;
  `glx` on bare metal only when `glxinfo -B` (package `glx-utils`) reports
  direct rendering on a renderer that is not llvmpipe/softpipe/swrast; and
  `xrender` in every other case, including when `glxinfo` is missing. On a
  GPU without 3D acceleration the glx backend freezes the screen while
  everything underneath keeps running (first VM install, 2026-10-05).
  `dwm-picom backend` prints the choice and why, and `dots doctor`
  compares it with what picom is running. `tests/picom-backend-probe.sh`
  pins the choice. Editing `backend` in the config changes nothing; change
  `dwm-picom`. It is linked, so a change reaches every install. An
  `autostart.sh` written before 2026-10-14 has its own copy of the old probe
  and is told to replace its picom lines with `dwm-picom &`.

### At login

dwm reads its colours once, at startup, so the theme has to be in the X
resource database **before** dwm starts. The `~/.xinitrc` the installer
writes does that: with a cache under `~/.cache/dots/theme/` it merges
`xresources` and runs `~/.fehbg`; with no cache yet — every headless
install, since the installer can only theme a running X session — it runs
`dots theme dark` once, bounded by `timeout`, and dwm starts regardless.

This must never move into `autostart.sh`. Re-theming a running dwm means
`kill -HUP` (restartsig re-exec), and dwm re-runs `autostart.sh` on every
start — a theme step there loops the session. An existing `~/.xinitrc` is
never edited; the installer prints the lines to paste.

### Desktop portal

GTK4/libadwaita apps, Firefox and Electron get dark mode from the desktop
portal's Settings interface, which `xdg-desktop-portal-gtk` serves from the
dconf `color-scheme` key. Apps also get the portal file chooser from it. In a
dwm session that only works if `~/.xinitrc` starts **`dots-session.target`**:

- `xdg-desktop-portal.service` (1.22) has
  `Requisite=graphical-session.target`, so it refuses to start unless that
  target is active;
- a full desktop such as GNOME activates it, but startx/ly + dwm never did;
- `graphical-session.target` has `RefuseManualStart=yes`, so
  `~/.config/systemd/user/dots-session.target` (copied there by the restore
  stage) pulls it in with `BindsTo=`.

Until 2026-10-06 nothing did this, and *no* portal worked in a dwm session.

The `~/.xinitrc` the installer writes starts the target before dwm and stops it
when the session ends. The same exit step (2026-10-07) also stops
`clipmenud`, the clipboard daemon. It is a shell loop over `clipnotify` and
`xsel` and holds no X connection of its own, so it outlives X. Once X is gone
both commands fail instantly in an endless loop, which floods the login TTY with
`xsel: Can't open display` after every logout. It stops two more that outlive
X: the night-light daemon (also a shell loop) and `dwmblocks`, which only
notices X is gone on its next bar update. A quick re-login used to find the old
copies still running, so `autostart.sh` started neither, and once they died the
bar was empty (`dwm-6.8`) and night light was off. Since 2026-10-12 it also
stops `xss-lock` (the screen-lock daemon) while X is still up: left to die
with X, it aborts with a core dump at every logout. If you had a `~/.xinitrc` before
installing, replace its `exec dwm`, and any `dots-session.target` block above
it, with:

```sh
dots_session_target=
dots_session_end() {
  pkill -u "$(id -u)" -x clipmenud
  pkill -u "$(id -u)" -x clipnotify
  pkill -u "$(id -u)" -x dwmblocks
  pkill -u "$(id -u)" -f '/dwm-nightlight daemon$'
  pkill -u "$(id -u)" -x xss-lock
  [ -z "$dots_session_target" ] || systemctl --user stop dots-session.target
}
trap dots_session_end EXIT
trap 'exit 0' HUP INT TERM
systemctl --user import-environment DISPLAY XAUTHORITY
systemctl --user daemon-reload
systemctl --user start dots-session.target && dots_session_target=1
dwm
```

then log out and back in. `dots doctor` checks both halves:

- `graphical-session.target` is active;
- the portal really answers `color-scheme`.

The dconf line only proves the preference is stored.

## How reload works, per tool

| Tool | Reads colours from | Reload mechanism |
| --- | --- | --- |
| dwm | `dwm.normbgcolor`, `dwm.selbgcolor`, … | `kill -HUP` — the restartsig patch re-execs dwm, which re-reads xresources at startup |
| st | `st.background`, `st.color0`–`15`, … | `pkill -USR1` — the signal-reload patch re-reads in place, so running shells survive |
| dmenu | `dmenu.background`, `dmenu.selbackground`, … | next invocation (dmenu is short-lived) |
| slock | `slock.initcolor`, … | next invocation |
| nsxiv | `Nsxiv.window.background`, `Nsxiv.bar.*`, … (native, no patch) | next invocation — a running viewer keeps its colours |
| dwmblocks | `statusbar-colors.sh` | restart — block scripts read the palette at exec time, so there is nothing to signal |
| dunst | its own generated `dunstrc` | `dunstctl reload` in place: the notification history and focus mode survive (reload resets the pause level, so `reload.sh` puts it back). Until 2026-10-15 dunst was killed, which emptied the history and ended focus mode on every wallpaper change |
| picom | nothing — see below | `pkill -USR1` reloads config in place |
| GTK 3 | generated `gtk.css` | none needed — GtkCssProvider watches the file |
| GTK 2 | generated `~/.gtkrc-2.0` | none — read at startup, so an open window keeps the old colours |
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

### The cursor outside GTK

`settings.ini` and xsettingsd reach GTK apps only. dwm (the wallpaper and the
bar), st and alacritty load their cursor through libXcursor, which reads
neither, so until 2026-10-07 the pointer changed shape on its way from Firefox
onto the wallpaper. Two more identity outputs carry `theme.conf`'s
`cursor_theme` there, in the order libXcursor consults them:

- **`Xcursor.theme` / `Xcursor.size`** — `~/.cache/dots/theme/xcursor`,
  written by `theme_write_xcursor_resources` and merged after `xresources`,
  by `reload.sh` (before dwm is HUPed: dwm sets the root-window cursor only
  at startup) and by `~/.xinitrc` at login. The only output that sets the
  size. An `~/.xinitrc` from before this gets one paste line from the
  installer:

  ```sh
  c="${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme"; [ -r "$c/xcursor" ] && xrdb -merge "$c/xcursor"
  ```

- **`~/.local/share/icons/default/index.theme`** — the XDG "default" theme
  (`Inherits=`), the fallback for everything else, Qt included; it needs no
  `.xinitrc` at all. The **directory** is the manifest's `THEME` row, so
  uninstall removes it whole. One that already exists and is not ours is never
  touched.

Check with `xrdb -query | grep Xcursor`, or `dots doctor`.

## Static themes

`themes/<name>/` holds:

- `colors.dcol` — the palette (same format `colorgen.sh` emits)
- `theme.conf` — gtk/icon/cursor theme names and font
- `wallpapers/` — optional

Four ship: `dark` (Catppuccin Mocha), `gruvbox`, `nord` and `tokyo-night`.
Switch with `theme-apply.sh <name>`, or `Super+Shift+t` for the dmenu picker.

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

- **The ly login screen** — see below. A static switch only; `--wallbash` never
  touches it.

### The login screen (ly)

`scripts/theme/ly-theme.sh` (`dots login-theme [<theme>]`) writes four keys of
`/etc/ly/config.ini`, in place, and nothing else:

| Key | Value | Same as |
| --- | --- | --- |
| `fg` | the theme's `txt1`, as a console colour | `dwm.normfgcolor` |
| `border_fg` | the theme's `1xa7`, as a console colour | `dwm.selbordercolor` |
| `bigclock` | `en` | — |
| `hide_version_string` | `true` | — |

No animation, by decision: it costs CPU on the TTY for as long as the login
screen is up. The background stays ly's `0x00000000`, which means "the
terminal's own"; ly's colours are `0xSSRRGGBB`, the first byte being style
bits (bold, underline, …), not alpha.

It runs from the installer's services stage (the active theme, else `dark`) and
from every `theme-apply.sh <name>`. The file is root's, so it needs sudo: in a
terminal you are asked, and from `Super+Shift+t` — where nobody can type a
password — it tries `sudo -n` and otherwise leaves ly alone and sends a
notification naming the command to run. Wallbash palettes are never written:
each wallpaper change would be another root write.

The first change saves ly's original lines to
`~/.local/state/dots/ly-config.orig`, and `dots uninstall` writes them back. The
file is replaced with `cp` onto itself, so its owner, mode and SELinux label are
kept, and because it is the package's `%config(noreplace)` an ly upgrade keeps
our edit and drops its new defaults beside it as `config.ini.rpmnew`. A key a
future ly no longer has is reported and skipped, never appended.

**On a Linux console a theme colour becomes one of 16.** ly runs in 24-bit
mode, but the kernel's VT draws only its 16-colour palette, and its rule
(`rgb_foreground()` in `drivers/tty/vt/vt.c`) lights red, green or blue only
when that component is over half the largest one. Every shipped accent is a
soft pastel (`#9A9AE6` in dark) with all three over half, so written as-is
each border was drawn **white** — seen on the VM, 2026-10-12. `ly-theme.sh`
therefore picks the console colour nearest the accent's hue and writes the RGB
the kernel maps exactly to its bright variant: dark, nord and tokyo-night get
a bright blue border, gruvbox a bright red one. A grey (under 1/5 saturation)
stays white. `tests/ly-theme.sh` checks every theme against its own copy of
the kernel's rule. Exact theme colours would need the console's palette
itself recoloured (`setvtrgb`), which was rejected: it changes every TTY,
tty1's rescue login included.

### The no-clobber rule

The identity writers refuse any `settings.ini` or `xsettingsd.conf` the manifest
does not record as ours — a hand-written one survives a theme switch and gets a
yellow line saying the identity was not applied there. The difference between
the two callers is only what happens to a file we *did* write: the installer
leaves it alone (you may have edited it since), a theme switch replaces it
(that is the point of switching). Both are covered by `tests/theme-identity.sh`.

### All four currently share one identity

Every shipped `theme.conf` names `Adwaita-dark` + `Papirus-Dark`, because this
repo declares exactly one dark GTK theme and `packages/extra.lst` adds no other.
Adwaita-dark is built into GTK4 but **not** into GTK 3.24: GTK3 gets it from
`assets/themes/Adwaita-dark`, the one-line shim `gnome-themes-extra` used to
ship before Fedora 44 retired it. Without that shim GTK3 falls back to *light*
Adwaita and discards `gtk-application-prefer-dark-theme` too (see
`assets/themes/README.md`). `dots doctor` warns when the name resolves to
nothing. The values are repeated per theme rather
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
`~/.cache/dots/theme` cache, and writes ly's original login-screen lines back
(the `LY` row; see "The login screen" above). `~/.fehbg` is left alone — it records the user's
wallpaper choice and is normally feh's own file.

The vendored cursor theme is a `THEME` row too, so it comes out with the rest.
It is the one THEME entry that is a directory rather than a file, which works
because `uninstall_theme` uses `rm -rf` — see `assets/cursors/README.md`.

`gtk.css`, `~/.gtkrc-2.0` and `fastfetch/config.jsonc` are removed too even
though the installer never wrote their contents: all three are claimed as `THEME` rows at
install time precisely so uninstall can reach them. A file that already
existed at one of those paths when the installer ran is deliberately *not* claimed,
and so is left behind — `uninstall_theme` deletes every `THEME` row outright,
and leaving a stray file is recoverable where deleting someone else's config
is not. The exception is a `gtk.css` or `~/.gtkrc-2.0` whose first line is the
engine's own `Generated by` header: an apply wrote it, so it is claimed.

Removing the theme cache also removes `starship.toml` from it, at which point
`conf.d/99-prompt.zsh` falls back to the repo config on the next shell.
