# alacritty-main-terminal
Date: 2026-08-07
Files: 13 | Lines: +443/-12

Epic sub-task 3 of `.claude/tasks/scope-b-app-roster-finalization.md`.

## What changed

- **`config/alacritty/alacritty.toml` (new).** Static base config: font,
  window, scrolling, cursor, selection, mouse. Carries no colours — it
  `import`s them from the cache instead (below).
- **`config/theme/templates/always/alacritty.dcol` (new).** Renders the
  wallbash palette to `${cacheDir}/alacritty-colors.toml`: primary, cursor,
  vi-mode cursor, selection and all 16 ANSI slots. The ANSI mapping is
  slot-for-slot identical to `xresources.dcol`'s st section so the two
  terminals never disagree about what "red" is.
- **`suckless/dwm/config.def.h`.** `termcmd` -> `alacritty`. `fonts[]` ->
  `{ "Cascadia Code NF:size=10", "monospace:size=10" }`, `dmenufont` ->
  `Cascadia Code NF:size=10`.
- **`suckless/dmenu/config.def.h`.** `fonts[0]` -> `Cascadia Code NF:size=10`,
  single entry to mirror dwm's `dmenufont` exactly.
- **`suckless/st/config.def.h`.** `Liberation Mono:pixelsize=12` ->
  `Cascadia Code NF:size=11`.
- **`scripts/symlinks.sh`.** `config/alacritty` added to `LINKS`.
- **`KEYBINDINGS.md`.** Terminal row now reads `alacritty`; added the st
  fallback note and the stale-`config.h` rebuild caveat. Also corrected a
  reference to `config/zsh/conf.d/20-path.zsh`, deleted in sub-task 1.
- **`config/theme/templates/always/README.md`.** Documents a third target
  style — render to `${cacheDir}` and let the app import it.

## Why

Locked decision 1 makes alacritty the primary terminal (GPU-accelerated,
matching the "max performance" constraint of locked decision 9) with st
retained as the no-GPU fallback. Both stay themed.

The theming route is the interesting part. `config/alacritty/` is symlinked
into this repo, so the engine must never write to it — the same hazard that
forced `config/dunst` and `config/picom` to be *copied* rather than
symlinked (CLAUDE.md's theming rule). Alacritty escapes that trade entirely:
`general.import` lets the colours live in a separate cache file, so the
user's config stays fully symlinkable and the engine only ever touches
`$XDG_CACHE_HOME/dots/theme/`.

Fonts came along because this sub-task inherited the follow-up recorded in
`2026-08-06-packages-roster-fonts.md`: nothing in the repo pointed at the
Nerd Font that task packaged. dwm and dmenu asked for `monospace`, st for
`Liberation Mono`. On a fresh Fedora box the starship prompt's glyphs and
`eza --icons` would have rendered as tofu.

## Assumptions

- **(Type B) `live_config_reload` picks up a rewrite of the *imported*
  file**, which is the sole reason `scripts/theme/reload.sh` gains no
  alacritty step. Basis: alacritty's startup log reports imports alongside
  the main file under "Configuration files loaded from", and that set is
  what its config watcher watches. **Not observed end to end** — windows
  would not stay alive long enough in the dev environment to witness a
  reload. Documented at all three sites rather than asserted as fact, after
  the reviewer flagged the overclaim. Symptom if wrong: already-open
  terminals keep the stale palette after a wallpaper change while
  newly-launched ones are correct. Remedy: add an explicit reload step.
- **(Type B) The import path is spelled `~/.cache/dots/theme/...`** while
  the engine computes `${XDG_CACHE_HOME:-$HOME/.cache}/dots/theme`.
  Verified that alacritty expands `~` to `$HOME` but performs no
  environment-variable expansion, so it cannot follow a relocated
  `$XDG_CACHE_HOME`. The two agree on every default setup; documented in the
  config. Alternative considered and rejected: a post-command that copies
  into a second fixed location, which adds a moving part to cover a case
  this repo never creates.
- **(Type C) st's font size changed, not only its family.** `pixelsize=12`
  is roughly 9pt at 96 dpi, so a family-only swap would have left the
  fallback terminal visibly smaller than the primary one and scaling
  differently with DPI. Both now specify points.

## Test coverage

All three CI-mirroring suites, run in the slot worktree (branch confirmed
before invoking):

- `tests/lint.sh` — shellcheck, `shfmt -d`, markdownlint: **pass**.
- `tests/pkglist.sh` — format, duplicates, core/extra overlap: **pass**.
- `tests/build.sh` — all five suckless programs built, including dwmblocks
  and slock which this task did not touch: **pass**.

Verified beyond the suites, against alacritty 0.17.0 — the exact version
Fedora 44 and rawhide both ship, so local results transfer:

- A **missing import is not fatal**: with `HOME` pointed at an empty
  directory containing no `.cache` at all, alacritty starts and exits 0 with
  no stderr. This is the fresh-install path.
- The config and the rendered palette both load with **zero errors, warnings
  or unused keys**.
- The template renders against `themes/dark/colors.dcol` with **no leftover
  `<wallbash_*>` tokens**, and the result parses as TOML.
- `~` expands to `$HOME` and ignores `$XDG_CACHE_HOME` (forced
  `XDG_CACHE_HOME=/tmp/nowhere` and watched the resolved path).
- `st -e true` exits 0 — the `pixelsize=` -> `size=` switch touches st's
  `usedfontsize` path, so it was smoke-tested rather than assumed.
- The **in-repo** generated `config.h` files carry the new values, not just
  the scratch-copy builds used during `/code`.

Font-family verification (CLAUDE.md rule 8, no `dnf` on this Arch host): the
family is **`Cascadia Code NF`**, read from the shipped RPM's `name` table
and from `/usr/share/fontconfig/conf.avail/60-cascadia-code-nf-fonts.conf`.
Fedora packages *Microsoft's* Nerd Font release, not the ryanoasis
nerd-fonts patch that names the same typeface `CaskaydiaCove Nerd Font`. The
dev machine carries the nerd-fonts build in `~/.local/share/fonts`, which is
why the wrong spelling resolves here and would not on a clean install —
`fc-match "Cascadia Code NF"` on this host returns DejaVu Sans, confirming a
wrong family degrades silently rather than erroring.

## Follow-ups

- **Confirm the live-reload assumption on real hardware** — change wallpaper
  with an alacritty window already open. This is the one unproven claim.
- **`alacritty` sits in `packages/extra.lst`, which is best-effort.** A
  failed install leaves `Mod+Shift+Return` dead. Consider promoting it to
  `core.lst`. Not done here: `packages/` was in this plan's `## Forbidden`,
  and the impact is bounded by st still being built and documented as the
  fallback.
- **`ROADMAP.md` and `docs/THEMING.md` are now stale** — the former still
  calls alacritty optional ("or use st from suckless/"), the latter omits it
  from the themed-app list. Both are outside this plan's `## Allowed` and
  belong to sub-task 9. Note that THEMING.md's "generated targets must not be
  symlinked" section is not made *wrong* by this change, only incomplete:
  alacritty's generated target is the cache file, not the symlinked config.
- **`CLAUDE.md:35` still cites the deleted `conf.d/20-path.zsh`** — the
  `KEYBINDINGS.md` twin was fixed here; this one is sub-task 9's.
- **New Epic sub-task 11 — dynamic scratchpads.** Raised by the user while
  answering a question in this task: they want to stash the *focused*
  window (any app) into a scratchpad, toggle it, and drop it back out. That
  is the `dynamicscratchpads` dwm patch replacing the vendored `scratchpads`
  one, not terminal work, so it was recorded in the scope file rather than
  folded in here. It also means this task correctly left scratchpads alone —
  with dynamic assignment there is no hardcoded `st -n spterm` left to
  convert. Retiring the current patch also retires the `ranger` and
  `keepassxc` scratchpads, neither of which is in `packages/*.lst` today.
- **`suckless/st/config.def.h` is 479 lines, over the 250-line cap.**
  Pre-existing vendored upstream source; this task added 5 comment lines.
  Splitting it would break CLAUDE.md rule 5's patch workflow. Reported in the
  audit rather than self-excepted.
- **tmux's `terminal-overrides` lists `xterm-kitty` and `xterm-256color`,
  neither of which matches `alacritty`'s `TERM`.** Truecolor inside tmux may
  not engage. Not a regression — st's `st-256color` was already unmatched —
  and `config/tmux/` was out of scope here.
