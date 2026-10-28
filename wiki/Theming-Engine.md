# Theming Engine

dots re-colours the whole desktop from the wallpaper: dwm, st, dmenu, slock, the bar, dunst, GTK, Qt, alacritty,
the prompt and more. This page is how the engine works and how to extend it. The full reference, including
per-tool reload details and troubleshooting, is
[docs/THEMING.md](https://github.com/YoussefFjel/dots/blob/main/docs/THEMING.md). For using themes, see
[Theming](Theming).

It is **dark-mode only**. Colour extraction forces a dark background even from a white wallpaper.

## The pipeline

```text
dots wallpaper <path> | --random | --select          dots theme <name>
        |                                                   |
        v                                                   |
 feh sets it, writes ~/.fehbg                               |
        |                                                   |
        v                                                   |
 colorgen.sh   ImageMagick k-means -> 4 colours, darkest    |
               first; text colour + 9 accents per colour    |
        |                                                   |
        v                                                   v
 ~/.cache/dots/theme/colors.dcol              themes/<name>/colors.dcol
 (cached on wallpaper path + mtime)           + theme.conf (identity)
        |                                                   |
        +-------------------------+-------------------------+
                                  v
 apply-templates.sh   always/ on every change; theme/ as well on a theme switch
                      line 1 of each .dcol: target|post-command
                      body: <wallbash_NAME> -> palette value
                                  |
                                  v
 reload.sh   1. xrdb -merge, first and alone (everything else reads it)
             2. then, concurrently: dwm HUP, st USR1, dwmblocks restart,
                dunst reload, picom USR1, xsettingsd HUP, ~/.fehbg
```

The scripts are in [`scripts/theme/`](https://github.com/YoussefFjel/dots/tree/main/scripts/theme):

- `wallpaper.sh` and `theme-apply.sh` are the user commands (`dots wallpaper`, `dots theme`).
- `colorgen.sh` turns an image into a `.dcol` palette.
- `apply-templates.sh` renders templates; `--check --palette <file> all` only validates.
- `reload.sh` tells running programs to pick up the new colours.
- `theme-lock.sh` makes sure only one change runs at a time.

## The palette

A `.dcol` file holds only `dcol_NAME="VALUE"` lines and comments. It is **parsed, never sourced**: a theme is
data, and installing someone's theme must not mean running their shell code. Lines that don't match are skipped
with a warning.

Keys are four primaries (`pry1` darkest to `pry4` lightest), a readable text colour for each (`txt1`..`txt4`), and
nine accents for each (`1xa1`..`4xa9`), plus `_rgba` variants. Run `scripts/theme/colorgen.sh <image>` and read
`~/.cache/dots/theme/colors.dcol` for the full key set.

A palette missing any key a template uses is refused before anything is written, naming the missing keys. That
check exists because an unresolved placeholder once reached X resources and dwm exited on an unallocatable
colour.

## Templates

Templates live in
[`config/theme/templates/`](https://github.com/YoussefFjel/dots/tree/main/config/theme/templates):

- `always/` renders on **every** wallpaper change and every theme switch.
- `theme/` renders only on a theme switch. It is empty today; a template belongs there only if it depends on
  something a theme defines but a wallpaper doesn't, and is still palette-derived.

A template's first line is a header, never output:

```text
${confDir}/myapp/colors.conf|myapp --reload-config
```

Left of `|` is the target. `${confDir}` and `${cacheDir}` are substituted; nothing else is expanded, and there is no
`eval`. Right of `|` is an optional post-command run after writing. If the target's **parent directory does not
exist**, the template is skipped: that is the engine's "app not installed" signal. The rest of the file is written
verbatim with `<wallbash_NAME>` replaced by the palette value (bare hex, no `#`). Comments in the body end up in
the user's generated file, so write them for that reader.

### The three target styles

[config/theme/templates/always/README.md](https://github.com/YoussefFjel/dots/blob/main/config/theme/templates/always/README.md)
describes these in detail. **Read it before adding a template.**

1. **Write the target directly**, for files the engine owns outright (X resources, dunst, picom, GTK CSS, the bar
   colours, fastfetch).
2. **Render to the cache, install with the post-command**, when the real destination is user-owned or not
   detectable by the install-check (vim, starship, GTK 2).
3. **Render to the cache and let the app import it**, when the app's own config is symlinked into this repo or
   belongs to the user (alacritty imports a colours file; qt5ct/qt6ct point at one).

Style 3 is the right choice for any themed app whose config is linked by `symlinks.sh`.

## Static themes

[`themes/`](https://github.com/YoussefFjel/dots/tree/main/themes) holds one directory per theme: `colors.dcol`,
`theme.conf` (GTK theme, icons, cursor, font) and a `wallpapers/` directory. No wallpaper image is committed:
applying a static theme renders a gradient wallpaper from its palette (`wallpaper-default.sh`), and a `~/.fehbg`
the user set themselves is never replaced.

Every `colors.dcol` is **generated** by `colorgen.sh` from a seed image of four solid blocks, never hand-written,
and records its seed colours in its header so it can be regenerated. Hand-written hex is how you get a palette
missing a key. The recipe for a new theme is in
[docs/THEMING.md](https://github.com/YoussefFjel/dots/blob/main/docs/THEMING.md#adding-a-theme).

A theme switch applies both halves: colours through the templates, and identity through the writers in
[`scripts/install-restore-theme-identity.sh`](https://github.com/YoussefFjel/dots/blob/main/scripts/install-restore-theme-identity.sh),
which render `theme.conf` into GTK's `settings.ini` and `xsettingsd.conf`. Those writers never touch a file the
manifest does not claim, and only a switch (not an installer re-run) replaces one it does.

Tests hold the identity together: `tests/cursor-theme.sh` checks `cursor_theme` against the vendored cursor
archive, and `tests/gtk3-adwaita-dark-shim.sh` checks every `gtk_theme` resolves for GTK 3.

## Why dunst and picom are copied

The engine rewrites `dunstrc` and `picom.conf` whole on every wallpaper change. If `config/dunst` or
`config/picom` were symlinked, every change would write into the git repo. So the installer copies them, and they
must never be added to `symlinks.sh`.

picom has a trap. Its template has no colour placeholders left, so it regenerates a file identical to
`config/picom/picom.conf`. That means **the two must be edited together**: the config is what a fresh install
gets, the template is what overwrites it on the next wallpaper change. `tests/picom-lockstep.sh` diffs them.
picom's backend is also not taken from its config; `config/dwm/bin/dwm-picom` chooses it at session start.

Some outputs have **no** static copy under `config/` at all: GTK's `gtk.css` and fastfetch's `config.jsonc` exist
only as templates. Don't add a `config/fastfetch/` or `config/gtk-3.0/`; it would recreate the lockstep problem.
The cost is that the restore stage must create their parent directory (or the install-check skips them forever)
and claim the path in the manifest.

## xsettingsd

`xsettingsd.conf` is written by the installer's identity writer, not a template. It holds the GTK theme identity
plus the Xft font-rendering keys, none of which come from the palette, so a template would rewrite an identical
file on every change. It is still in `reload.sh`'s sweep so a `theme.conf` change applies without a logout.
`Xft/DPI` is deliberately left out so X's own DPI detection works on HiDPI screens. xsettingsd has no part in GTK's
accent colours; that is `gtk.css`.

## starship is spliced

[`config/starship/starship.toml`](https://github.com/YoussefFjel/dots/blob/main/config/starship/starship.toml) is
the authored config and stays symlinked. The template renders only a `[palettes.dots]` table, and its
post-command writes a combined copy into the cache: everything above the marker line
`# ### dots-theme palette ###`, then the new palette. The zsh prompt config uses the cached copy while it is
newer. The marker is load-bearing; without it the template refuses to touch the file.

## X resources and cpp

`xrdb` runs its input through `cpp`. A literal `/*` anywhere, even inside a `!` comment, opens a C comment and
breaks the merge, and an apostrophe opens a character literal. Keep both out of `xresources.dcol`.

## The theme at login

dwm reads X resources once at startup, so the theme must be merged **before** dwm starts. That happens in
`~/.xinitrc`, never in `autostart.sh`: re-theming a running dwm restarts it, and every restart re-runs
`autostart.sh`, so a theme step there would loop. See [Session and Autostart](Session-and-Autostart).

## Adding a template

1. Read the `always/` README and pick a target style.
2. Add `config/theme/templates/always/<app>.dcol` with the header line and body.
3. If the target directory might not exist on a fresh install, have the restore stage create it and claim the
   file in the manifest, or it will never render and uninstall cannot remove it.
4. If the app needs a reload, use the post-command, or add a step to `reload.sh` if it must follow `xrdb`.
5. Add a test in a sandbox (see the existing `*-template.sh` tests), stubbing anything that would signal real
   processes.
6. Document it in `docs/THEMING.md`.
