# `always/` templates

Processed by `scripts/theme/apply-templates.sh` on **every** wallpaper
change and on every theme switch. See `../theme/README.md` for the group
that only runs on a theme switch.

Line 1 of each `.dcol` is `target_path|post_command`. `${confDir}` and
`${cacheDir}` are string-substituted in that line only — never in the
body, where the substitutions are the `<wallbash_NAME>` placeholders.

## Two target styles

| Style | Used by | Why |
| --- | --- | --- |
| Write the target directly | `xresources`, `dunst`, `picom`, `gtk`, `statusbar` | The file is engine-owned. Nothing of the user's lives there. |
| Render to `${cacheDir}`, install via post-command | `vim`, `cava` | The real destination is user-owned or is not detectable by the engine's install-check. |

The install-check is `[[ -d "$(dirname "$target")" ]]` — a missing parent
directory means "app not installed" and the template is skipped. That
works for apps whose config sits one level under `$confDir`. It does not
work for `vim` (which creates neither `~/.config/vim` nor a `colors/`
subdirectory on its own) or for `cava` (whose config file is user-tuned
and must be spliced into, not overwritten). Both therefore render to
`${cacheDir}` — always present, so never skipped — and do their real
install in the post-command.

## Maintainer note: path derivation in post-commands

`vim.dcol` and `cava.dcol` re-derive their paths from the XDG variables
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
