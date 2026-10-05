# 2026-08-06 — theming engine: vim + cava app templates

Post-Epic follow-up to `.claude/tasks/scope-a-theming-engine.md`. Extends
the engine from desktop surfaces to two applications.

## What changed

- `config/theme/templates/always/vim.dcol` **(new)** — renders a
  `wallbash` Vim colorscheme (editor surfaces, selection, chrome, syntax,
  diff, spell) and installs it into every existing Vim config directory.
- `config/theme/templates/always/cava.dcol` **(new)** — renders a
  `[color]` block and splices it into the user's own cava config below a
  marker line, then `SIGUSR2`s cava to re-read it.
- `config/theme/templates/always/README.md` **(new)** — documents the
  group's two target styles and the maintainer coupling noted below.

## Why

The user asked which of HyDE's remaining assets were worth porting. Of
its six app templates, only `vim` and `cava` were selected — the other
four (chrome, discord, spotify, VS Code) theme applications this desktop
does not assume. Everything else in HyDE is Wayland-specific and out of
scope per the Epic's scope file.

**Reimplemented, not copied.** HyDE is GPL-3.0 and is a read-only
reference clone (CLAUDE.md rule 9). Verified mechanically: the only lines
these files share with HyDE's equivalents are `endif`,
`let g:colors_name = 'wallbash'` and `[color]` — syntax mandated by Vim
and cava respectively, not copied expression.

## Key Technical Decisions

**cava's config is user-owned; dunstrc and picom.conf are not.** cava has
no include directive, but unlike dunst and picom its config is a file
users tune (input method, bar geometry, smoothing). Overwriting it
wholesale — the contract used for the engine-owned files — would be
destructive. The template renders only the colour block to `$cacheDir`
and splices it in below a marker, replacing what it wrote last time and
leaving everything above untouched. Same conclusion HyDE reached, arrived
at independently.

**Both templates render to `$cacheDir`, not to their real destination.**
`apply-templates.sh`'s install-check is "does the target's parent
directory exist". That is a good signal for apps whose config sits one
level under `$confDir`, and a bad one for these two. `$cacheDir` is
engine-owned and always present, so the render never skips and the real
install happens in the post-command, which can apply its own conditions.

**Post-commands derive paths from XDG variables, not from the engine's
`${cacheDir}` token.** This duplicates `apply-templates.sh:25` and is the
one accepted wart — see the reviewer WARN below.

## Assumptions

- **Type B** — the colorscheme emits `gui*` attributes only. The palette
  is 24-bit hex with no 256-colour equivalents, so `termguicolors` is
  required; documented in the file header. Alternative considered:
  approximating cterm indices, which would misrepresent the palette.
- **Type C** — an existing Vim config directory is the signal that Vim is
  set up here. Neither directory is created if both are absent.

## Bugs found and fixed during audit + review

1. **vim.dcol would have skipped for essentially every user (reviewer
   BLOCK).** It originally targeted `${confDir}/vim/colors/wallbash.vim`,
   so the install-check tested `~/.config/vim/colors` — a directory Vim
   creates neither half of on its own. The template would have reported
   "app not installed" on every real machine. Now renders to `$cacheDir`
   and installs into `~/.vim` and/or `$XDG_CONFIG_HOME/vim`.
2. **Path-driven quoting break in both post-commands.** `expand_path`
   substitutes `${confDir}`/`${cacheDir}` into the command string *before*
   `bash -c` parses it, so a `$HOME` containing a single quote terminated
   the surrounding quoting and corrupted the command — the same class of
   injection `apply-templates.sh` was deliberately hardened against for
   palette values in sub-task 3. Found by a `$HOME` fixture containing a
   space and a quote; both post-commands now contain no substituted
   tokens at all.
3. **Template rationale leaked into the user's cava config.** Every line
   after the header is body, so a long explanatory comment block was
   being appended into `~/.config/cava/config`. Trimmed to three lines;
   the rationale moved to the new `always/README.md`, which is also where
   the reviewer's WARN is recorded so it does not leak either.

## Test coverage

All in isolated `$HOME` fixtures (`env -i`, all four XDG vars redirected,
`DISPLAY=` — see the note below on why that matters):

- vim: no config dir anywhere (clean no-op), only `~/.vim`, only XDG
  `~/.config/vim`, both present, and a `$HOME` containing a space and a
  single quote. Correct in all five.
- vim: generated colorscheme sourced by **real `vim`** — exits 0, no
  errors, `g:colors_name` set, `Normal`/`Comment`/`Error` resolve to
  actual palette hex.
- cava: three consecutive applies leave exactly one marker, 8 gradient
  lines, and the user's `[general]`/`[input]` keys intact; a user key
  added above the marker survives the next apply; quoted `$HOME` works;
  no config is created when the user has none.
- All 24 `<wallbash_*>` placeholders used exist in a real generated
  palette; zero unsubstituted placeholders and zero malformed hex in the
  rendered output.
- cava post-command passes `shellcheck -S warning` in isolation.
- `tests/lint.sh` passes (shellcheck + shfmt + markdownlint).

**Testing note worth keeping:** the `always/` group includes
`xresources.dcol`, whose post-command is a bare unbounded
`xrdb -merge`. Running the group with `DISPLAY` inherited connects to the
live X server — it hung the harness twice and merged a test palette into
the running session's X resource database before this was understood.
Always pass `DISPLAY=` when exercising `apply-templates.sh`.

Reviewer subagent: BLOCK (bug 1) -> fixed -> WARN (accepted, below).

## Trade-offs

**Accepted reviewer WARN — duplicated cache-path expression.** Both
templates re-derive `"${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme"`
independently of `apply-templates.sh:25`. If that definition ever moves,
the templates point at a stale path. The alternative — using the engine's
`${cacheDir}` token — reintroduces bug 2, and the alternative of exporting
`confDir`/`cacheDir` from `apply-templates.sh` would touch a file the
unmerged `theming-packaging` slot also modifies. The failure mode is
benign: the post-command's `cat`/`cp` fails, the engine warns and
continues, nothing is written or lost. Recorded in `always/README.md`.

## Follow-ups

- **`docs/THEMING.md` needs a section on these two templates.** Dropped
  from this slot's scope deliberately: that file exists only in the
  unmerged `theming-packaging` slot, so editing it here would guarantee a
  merge conflict. Do it on `main` after both slots are merged.
- `xresources.dcol`'s `xrdb -merge` post-command is unbounded, unlike
  `reload.sh`'s, which wraps it in `timeout 10`. Pre-existing, outside
  this diff, but it is what made the harness hang.
- Neither `vim` nor `cava` was added to `packages/*.lst` — neither is a
  desktop dependency, and both templates no-op when absent.
