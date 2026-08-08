# Thunar, default applications, and the Xfce helper framework

What this repo ships for the file manager, where each file actually lands,
and the two non-obvious mechanisms behind it. Companion to
[THEMING.md](THEMING.md); Thunar's *appearance* is covered there (the
existing `gtk.dcol` template themes it like any other GTK app — there is no
Thunar-specific template).

## Files and where they go

| Repo file | Deployed to | Rewritten at runtime by |
| --- | --- | --- |
| `config/thunar/thunarrc` | `~/.config/Thunar/thunarrc` | — (migration only, see below) |
| `config/thunar/uca.xml` | `~/.config/Thunar/uca.xml` | Thunar, on editing custom actions |
| `config/xfce4/helpers.rc` | `~/.config/xfce4/helpers.rc` | `xfce4-mime-settings` |
| `config/mimeapps.list` | `~/.config/mimeapps.list` | `xdg-mime default`, GIO, Thunar's "Set Default" |
| `config/applications/dots-nvim.desktop` | `~/.local/share/applications/` | — |

All of these are **copied by the installer, never symlinked.** Every one of
them is rewritten in place by the program that owns it, and a symlink would
send those writes back into this git repo. It is the same rule that keeps
`config/dunst` and `config/picom` out of `scripts/symlinks.sh`, and
`config/thunar` and `config/xfce4` must stay out of it for the same reason.

Note the capital T: Thunar reads `$XDG_CONFIG_HOME/Thunar/`. The repo
directory is lowercase to match every other entry under `config/`.

Deployment is no-clobber. A file that already exists is left alone and
deliberately **not** recorded in the manifest, so `uninstall.sh` will never
remove config it did not create.

## thunarrc is a migration file, not the live config

Thunar 4.20 keeps preferences in the **xfconf `thunar` channel**
(`~/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml`), not in
`thunarrc`. Upstream `thunar_preferences_init()` reads `thunarrc` only when
xfconf has no `/last-view` property, and even then skips any property xfconf
already holds:

```c
if (!xfconf_channel_has_property (preferences->channel, check_prop))
  thunar_preferences_load_rc_file (preferences);
```

So on any machine where Thunar has ever run, a shipped `thunarrc` is inert.
That is why `scripts/install-restore-apps.sh` also runs an `xfconf-query`
pass — that pass is what actually applies the preferences. `thunarrc` is
kept for one case only: a fresh install where Thunar has not started yet
*and* the installer could not reach a session D-Bus (a headless server
install), so the xfconf pass was skipped.

The two must be kept in sync. `thunarrc`'s keys are the CamelCase GParamSpec
*nick*; the xfconf property is the kebab-case *name* with a leading slash —
`MiscFoldersFirst` ↔ `/misc-folders-first`. Enum values are the C identifier
(`THUNAR_DATE_STYLE_YYYYMMDD`), which is the form xfconf stores.

**The xfconf pass only sets a property that has no value yet.** A setting
you changed in Thunar's preferences dialog is yours, and re-running the
installer must not silently revert it. In practice, on a machine where
Thunar has run before, `/last-view` (which Thunar writes on its own to
remember the view you left it in) is kept, and the preferences nothing has
ever set are applied.

## The terminal, and why xfce4-settings is in the roster

Thunar hardcodes `exo-open --launch TerminalEmulator` for its built-in
"Open Terminal Here". In Xfce 4.20 that command does almost nothing on its
own — `libexo` reads `helpers.rc` and then delegates the launch to
`/usr/bin/xfce4-mime-helper`, which **is not part of exo**. exo 4.15.1
removed it:

> Removed binaries: exo-compose-mail, exo-helper-2

and `xfce4-settings` 4.15.1 picked it up:

> exo-helper -> xfce4-mime-helper

Fedora 43 ships exo 4.20.0 and xfce4-settings 4.20.1, both well past that
split. So `helpers.rc` without `xfce4-settings` installed is a file nothing
ever acts on, and the menu entry falls back to libexo's compiled-in default
of `xfce4-terminal.desktop` — which this roster does not install.

`xfce4-settings` is therefore in `packages/extra.lst` for one binary.
Nothing starts `xfsettingsd`; the rest of the package is inert on a dwm
session. The helper names in `helpers.rc` are basenames of
`/usr/share/xfce4/helpers/*.desktop`, and `alacritty.desktop`,
`firefox.desktop` and `thunar.desktop` all ship upstream in that package —
no custom helper file is needed.

`extra.lst` is best-effort, so if `xfce4-settings` fails to install nothing
aborts — it is named in the installer's closing summary and the run
continues. It stays in `extra.lst` rather than `desktop.lst` because the
consequence is contained: the **right-click** "Open Terminal Here" is a
custom action in `uca.xml` that calls `alacritty` directly and keeps working
regardless. Only Thunar's own File-menu entry goes quiet. `alacritty` itself
*is* in `desktop.lst`, since losing it takes the terminal keybind with it.

## Custom actions

`uca.xml`'s `<command>` is parsed with `g_shell_parse_argv` and spawned
directly — **there is no shell**, so `$HOME` and `~` do not expand. A bare
binary name resolves through the session `PATH`; anything under `$HOME`
needs an explicit `sh -c` wrapper.

| Action | Applies to | Command |
| --- | --- | --- |
| Open Terminal Here | directories | `alacritty --working-directory %f` |
| Set as Wallpaper | image files | `sh -c 'exec "${XDG_CONFIG_HOME:-$HOME/.config}/dwm/bin/dwm-wallpaper" "$1"' _ %f` |

"Set as Wallpaper" runs the full theming pipeline, so picking an image in
Thunar re-themes the whole desktop exactly as `Super+w` does.

## Default applications

`config/mimeapps.list` maps types to `thunar` (directories), `feh` (images),
`file-roller` (archives), `firefox` (web, PDF, SVG) and `dots-nvim.desktop`
(text and code). Two things worth knowing:

- **`[Added Associations]` is populated alongside `[Default Applications]`**
  on purpose. A default only takes effect for a type the application is
  actually associated with, and neither feh nor file-roller declares every
  type listed in its own `MimeType` line.
- **`dots-nvim.desktop` exists because `nvim.desktop` is `Terminal=true`.**
  That hands the job of finding a terminal to GLib, which picks from a
  compiled-in list of terminal names — so whether alacritty is chosen
  depends on the installed GLib version. Ours spells the terminal out:
  `alacritty --title nvim -e nvim %F`.

SVG deliberately goes to firefox rather than feh: feh rasterises through
imlib2 and renders most SVGs badly or not at all.

## Uninstall

`uninstall.sh` removes these under its own **app configs** prompt, by
manifest row (copies cannot be identified by a readlink check the way
symlinks can). Thunar's xfconf preferences are deliberately left in place —
see `docs/UNINSTALL.md`.
