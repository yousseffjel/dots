# `always/` templates

Processed by `scripts/theme/apply-templates.sh` on **every** wallpaper
change and on every theme switch. See `../theme/README.md` for the group
that only runs on a theme switch.

Line 1 of each `.dcol` is `target_path|post_command`. `${confDir}` and
`${cacheDir}` are string-substituted in that line only — never in the
body, where the substitutions are the `<wallbash_NAME>` placeholders.

Everything after line 1 is written to the target verbatim (`tail -n +2 |
sed -f …`), comments included. So a comment in a template body is a comment
in the user's generated config — keep template rationale short and write it
for the reader of the *output*, not for the reader of the template.

## Three target styles

| Style | Used by | Why |
| --- | --- | --- |
| Write the target directly | `xresources`, `dunst`, `picom`, `gtk`, `statusbar`, `fastfetch` | The file is engine-owned. Nothing of the user's lives there. |
| Render to `${cacheDir}`, install via post-command | `vim`, `starship` | The real destination is user-owned, or is not detectable by the engine's install-check. |
| Render to `${cacheDir}`, let the app import it | `alacritty` | The app's own config is a **symlink into this repo**, so it can never be rewritten — but the app can pull a second file in itself. |

The third style is the one to reach for whenever a themed app's config is
symlinked by `scripts/symlinks.sh`. `config/dunst` and `config/picom` are
copied rather than symlinked precisely because their templates rewrite the
whole file; alacritty avoids that trade entirely because `general.import`
lets the colours live somewhere else.

Two properties were **verified** against alacritty 0.17.0 (the version
Fedora 44 ships): a missing import is not fatal, so a fresh install works
before any palette exists — confirmed with a `HOME` containing no `.cache`
at all; and `~` in an import path expands to `$HOME`, but nothing else does,
so the import cannot follow a relocated `$XDG_CACHE_HOME` the way
`${cacheDir}` can. The two agree on any default setup; see the comment in
`config/alacritty/alacritty.toml`.

One property is **assumed, not verified**: that `live_config_reload` picks
up a rewrite of the *imported* file, which is the reason this template has
no post-command and alacritty has no step in `scripts/theme/reload.sh`. The
basis is that alacritty's startup log reports imports as loaded config files
and the watcher watches that set — but the reload was never reproduced end
to end. Confirm it on real hardware. The symptom if it is wrong is narrow
and recognisable: already-open terminals keep the old palette after a
wallpaper change while newly-launched ones are correct.

The install-check is `[[ -d "$(dirname "$target")" ]]` — a missing parent
directory means "app not installed" and the template is skipped. That
works for apps whose config sits one level under `$confDir`. It does not
work for `vim`, which creates neither `~/.config/vim` nor a `colors/`
subdirectory on its own, so that template renders to `${cacheDir}` —
always present, never skipped — and does its real install in the
post-command.

## Engine-owned targets with no static base config

`gtk.css` and `fastfetch/config.jsonc` have **no copy under `config/`** at
all: the `.dcol` is the only authored version. That is cheaper than the
`dunst`/`picom` arrangement, where a static base config is copied by the
installer *and* the template rewrites the same file — two files carrying
the same settings, which have to be edited together or the first wallpaper
change silently reverts one of them.

The cost is that `scripts/install-restore-theme.sh` has to do two things
the deploy-a-base-file path gets for free:

1. **Create the parent directory**, or the install-check above skips the
   template forever and the app is simply never themed. `theme_write_gtk_ini`
   creates `~/.config/gtk-3.0` as a side effect of writing `settings.ini`;
   `theme_claim_fastfetch` creates `~/.config/fastfetch` explicitly.
2. **Claim the path in the install manifest** (`theme_claim_gtk_css`,
   `theme_claim_fastfetch`), so `uninstall_theme` removes a file the
   installer never wrote the contents of. Both keep the no-clobber rule: a
   pre-existing file at that path is left untouched and deliberately *not*
   claimed, because uninstall deletes every `THEME` row outright.

The trade-off, accepted for both: on a box where no theme has ever been
applied — the documented headless fresh-server path — the app runs on its
own built-in defaults until `scripts/theme/theme-apply.sh` runs.

## Maintainer note: path derivation in post-commands

`vim.dcol` and `starship.dcol` re-derive their paths from the XDG variables
(`"${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme"`) instead of using the
engine's `${cacheDir}` token.

This is deliberate. `expand_path` substitutes those tokens into the
command string *before* `bash -c` parses it, so a home directory
containing a quote character would break out of the surrounding quoting —
the same class of injection `apply-templates.sh` was hardened against for
palette values. Deriving the path at run time keeps it correctly quoted
whatever the path contains.

**The cost:** those expressions duplicate `apply-templates.sh`'s own
`cacheDir` definition (currently line 25). If that definition ever moves,
update both templates too. The failure mode if you forget is benign — the
post-command's `cat`/`cp` fails, `apply-templates.sh` warns and continues,
and nothing is written or lost — but the app silently stops following the
theme.

`starship.dcol` additionally guards on a marker line being present in
`~/.config/starship/starship.toml` before splicing. Without that guard a
hand-replaced starship config would get the palette table appended to it
wholesale — and if it already declared `[palettes.dots]`, the result is a
duplicate-table TOML parse error rather than a merely wrong colour.
