# dots — Current Audit State

## Current Scope
Personal Fedora-only dotfiles + dwm/X11 desktop bootstrap repo. The
uninstall/versioning/migrations subsystem (below) and the CI/tooling setup
both landed 2026-08-05, concurrently, in the same working tree — see each
thread's dated log for the full collision account (mutually surfaced and
handled without data loss on either side). See recent dated logs in this
directory for the running history.

## History Sources
- `.claude/changes/YYYY-MM-DD-*.md` — authoritative dated logs

## 2026-08-05 — uninstall + versioning + migrations subsystem
- Added `VERSION` + `scripts/version.sh` (repo/installed version, commit,
  Fedora version, dwm version, `--json`), `scripts/global_fn.sh` (shared
  confirm()/refuse_root()/manifest_* helpers — a deliberate, disclosed
  reversal of this repo's "no shared logging file" convention for this
  one file), manifest tracking wired into every install-*.sh stage,
  `scripts/uninstall.sh`, and a `scripts/migrations/` + `scripts/
  migrate.sh` framework auto-run by `install-fedora.sh`. Plus
  `docs/UNINSTALL.md` and a README Versioning policy section.
- Landed as 5 commits (f46fcc2, 0068a70, 829a96e, 8baf8a0, 6c8717c).
  Reviewer + hands-on sandboxed `$HOME` testing caught and fixed 3 real
  bugs pre-commit (two `set -e` traps in uninstall.sh, one in migrate.sh's
  version-chain summary) plus 2 reviewer WARNs (version.sh's JSON `null`,
  migrate.sh's ambiguous-migration-match guard).
- See `.claude/changes/2026-08-05-uninstall-versioning-migrations.md` for
  full detail. Reviewer verdict: READY (all 5 diffs).

## 2026-08-05 — install-fedora.sh run logging
- Added append-mode `install.log` capture (stdout+stderr, ANSI-stripped)
  for the whole orchestrator run plus every child stage script it
  invokes, with timestamped start/finish header lines (finish line uses
  `trap ... EXIT` so it fires on every exit path). `--dry-run` runs are
  logged too, by design. `install.log` added to `.gitignore`.
- See `.claude/changes/2026-08-05-install-fedora-run-logging.md` for
  full detail. Reviewer verdict: READY.

## 2026-08-05 — CI tooling: shellcheck/shfmt/markdownlint, pre-commit, GitHub Actions, tests
- Added `.shellcheckrc`, `.pre-commit-config.yaml` (shellcheck-py, shfmt,
  markdownlint, pre-commit-hooks hygiene), `.markdownlint.yaml` +
  `.markdownlintignore` (grandfathers pre-existing `.claude/changes/**`,
  `CLAUDE.md`, `ROADMAP.md`, vendored `suckless/**`), `.github/workflows/ci.yml`
  (lint / build-suckless / install-dry-run jobs, fedora:latest +
  fedora:41 matrix), `tests/{lint,build,pkglist}.sh`, `TESTING.md`, and a
  README CI badge + pre-commit setup section.
- Only real shellcheck fix needed: SC2086 `$SUDO` word-splitting in
  `install-pkg.sh`/`install-services.sh`/`install-suckless.sh`, converted
  to array form. **Applied but not yet committed** — a second Claude
  session was concurrently building an install-manifest/versioning
  feature across those same files in this working tree; committing was
  deferred to avoid bundling their in-progress work. See the dated log's
  Open Questions/Blockers for the full collision account, including a
  caught-and-fixed bare `git commit` that briefly picked up their staged
  files (undone via `git reset --soft`, not pushed).
- See `.claude/changes/2026-08-05-ci-tooling-shellcheck-precommit.md` for
  full detail.

## 2026-08-05 — post-push verification audit
- User asked to verify the day's two pushed sessions (above). Three
  parallel read-only audits (collision damage, versioning/uninstall/
  migrations correctness, CI tooling correctness) found: no collision
  damage; a real bug in `scripts/version.sh` (crashes on every real
  install — `dwm -v`'s intentional exit 1 under `set -euo pipefail`); a
  latent same-class footgun in `install-restore.sh`; `.shellcheckrc` not
  actually resolving sourced files (SC1091 on 7 scripts); `shfmt` diffs
  in all 14 scripts; two untracked/un-reversible uninstall gaps
  (dwmblocks block scripts, login-shell change).
- All fixed and verified with real `shellcheck`/`shfmt` (installed fresh
  for this audit — neither prior session had them available) plus
  sandboxed functional tests. `tests/lint.sh` and `tests/pkglist.sh` both
  pass end-to-end.
- See `.claude/changes/2026-08-05-post-push-verification-audit.md` for
  full detail, including a correction of a stale claim in the CI
  session's own log (the SC2086 fix it thought was still uncommitted
  actually landed in commit `0068a70`).

## 2026-08-05 — theming engine epic, sub-task 1: xresources patches
- Kicked off a 7-sub-task Epic (`.claude/tasks/scope-a-theming-engine.md`)
  to build a HyDE-wallbash-inspired dark-mode-only theming engine for the
  Fedora+dwm+X11+suckless stack. Sub-task 1 (this entry) adds xresources
  runtime color support to dwm, st, dmenu, slock — the prerequisite every
  later sub-task (color extraction, template engine, reload) targets.
- dwm and dmenu were hand-merged against 10 and 7 already-applied patches
  respectively (no `config.h` in this repo, only `config.def.h` with
  prior patches baked directly into the vendored source); st and slock
  were clean applies (zero prior patches on either). All 4 build clean
  (`make clean && make`, zero new warnings).
- Reviewer subagent (first pass) caught a real use-after-free in st's
  `xrdb_load()` — an `XrmDestroyDatabase()` call freed memory that
  `colorname[]` still pointed to, hit on every st launch and every
  `SIGUSR1` reload. Fixed by removing the destroy call (matches
  upstream's own behavior, which never destroys it either); rebuilt
  clean; second reviewer pass returned READY.
- Every tool's `patches/PATCHES.md` documents exact merge decisions and
  deviations from upstream (resource naming, precedence handling,
  trimmed scope).
- See `.claude/changes/2026-08-05-theming-xresources-patches.md` for
  full detail. Reviewer verdict: READY (after fix).

## 2026-08-05 — theming engine epic, sub-task 2: colorgen.sh
- Added `scripts/theme/colorgen.sh <wallpaper> [--force]` — ImageMagick-
  only (kmeans + histogram, HSB hue-locked accent curve), dark-mode-only,
  producing a HyDE-wallbash-compatible `colors.dcol` (dcol_pry1-4,
  dcol_txt1-4, dcol_NxaJ accent shades, `_rgba` siblings) at
  `~/.cache/dots/theme/colors.dcol`, cached by sha256(path+mtime).
  Reimplements (not copies) HyDE-Project/HyDE's `wallbash.sh` algorithm,
  read locally as a design reference per CLAUDE.md rule 9 — never
  sourced/shelled-out-to at runtime.
- Dark-mode floor verified live: a synthetic near-white test wallpaper
  correctly darkens `dcol_pry1` in a bounded loop until under the
  luminance threshold; a 4-distinct-color test wallpaper correctly sorts
  primaries darkest-to-lightest and produces a well-formed, sourceable
  90-line `colors.dcol`.
- Reviewer subagent (first pass) BLOCKed on the file exceeding this
  repo's 250-line cap (256 lines) — fixed by trimming the header comment
  to a concise summary (design rationale moved to the dated log, no
  logic change), landing at 235 lines; second pass returned READY.
- See `.claude/changes/2026-08-05-theming-colorgen.md` for full detail.

## 2026-08-05 — theming engine epic, sub-task 3: apply-templates.sh
- Added `scripts/theme/apply-templates.sh [--palette PATH] <always|theme|all>`
  — the template engine. Reads a dcol palette, then for each `*.dcol`
  under `config/theme/templates/{always,theme}/` parses line 1 as
  `target_path|post_command`, expands `${confDir}`/`${cacheDir}`,
  substitutes `<wallbash_NAME>` placeholders, writes atomically, runs the
  post-command. Missing target dir or failing post-command are non-fatal
  skips/warnings.
- **Three deliberate hardening divergences from HyDE's `fn_wallbash`**,
  all recorded under Key Technical Decisions in the dated log: parse the
  palette rather than `source` it; enforce a positive character allowlist
  on values; expand header paths by string substitution rather than
  `eval`. The allowlist is the non-obvious one — refusing to *execute* a
  palette isn't sufficient by itself, because sub-task 4's
  `statusbar-colors.sh` target is designed to be sourced by dwmblocks, so
  a literal `$(...)` written into it would execute one step downstream.
- Reviewer subagent ran 3 passes and drove two real fixes: the `source`
  injection surface (pass 1 WARN) and an `ARG_MAX` ceiling that made
  large palettes die with "Argument list too long" (pass 2 WARN, fixed by
  `sed -f scriptfile`). Pass 3 was interrupted before reporting; its
  scoped check (temp-file cleanup on all exit paths) was completed
  in-thread and surfaced a third fix — an un-trapped per-template temp
  file, now cleaned up via `trap ... EXIT INT TERM HUP`.
- Verified live end-to-end (`colorgen.sh` -> `colors.dcol` ->
  `apply-templates.sh` -> rendered target), plus hostile-palette,
  1.5 MB/60k-rule palette, placeholder-prefix-collision, graceful-skip,
  and error-path cases. shellcheck + shfmt clean, 201 lines.
- See `.claude/changes/2026-08-05-theming-apply-templates.md` for full detail.

## 2026-08-05 — theming engine epic, sub-task 4: templates + base configs
- Added the 5 `.dcol` templates (xresources, dunst, picom, gtk,
  statusbar), all in `always/` since every one is purely color-driven;
  plus base `config/dunst/dunstrc` and `config/picom/picom.conf`
  generated from the templates themselves so they cannot drift.
- **Base configs are copied, never symlinked** — the templates write the
  whole file into `~/.config`, so adding `config/dunst`/`config/picom` to
  `symlinks.sh` (CLAUDE.md rule 7) would make every wallpaper change
  write back into the repo. Noted in each file; sub-task 7 must honor it.
- Resolved a spec/repo conflict on the statusbar contract: the spec asks
  for `STATUS_*` status2d escape strings, but the existing dwmblocks
  scripts source `COL_*` raw hex. Emitting only `STATUS_*` would have
  left the file inert. The generated file now emits both, and the 3 block
  scripts prefer it over their static `dwm-colors`, with fallback.
- Validated against the real parsers rather than by eye, which caught
  three bugs: `xrdb` pipes through `cpp` so a `/*` in a comment broke the
  merge outright and apostrophes warned on every change; `mktemp`'s 0600
  survived the `mv` leaving every generated config user-only-readable
  (fixed in `apply-templates.sh`); and a deprecated picom `@:c` type
  specifier. `xrdb -query` confirmed the emitted resource names match the
  `resources[]` arrays in the sub-task 1 C patches exactly.
- Reviewer verdict: READY (independently re-verified all of the above).
- See `.claude/changes/2026-08-05-theming-templates.md` for full detail.

## 2026-08-05 — theming engine epic, sub-task 5: reload.sh
- Added `scripts/theme/reload.sh [--quiet]`, the single reload entry
  point: `xrdb -merge` alone and first (everything downstream re-reads
  the X resource database, so merging after signalling would apply the
  previous palette), then six concurrent guarded reloads (dwm SIGHUP via
  restartsig, st SIGUSR1 in-place, dwmblocks restart, dunst kill for
  D-Bus reactivation, picom SIGUSR1, `~/.fehbg` re-run).
- Serialized on a `flock` because it is hotkey-bound; `xrdb` and
  `~/.fehbg` bounded by a 10s `timeout`.
- **Three review passes (WARN -> BLOCK -> WARN) found five real bugs**,
  all fixed and re-verified live. The BLOCK is the one worth remembering:
  the first `flock` fix used `exec flock ... "$0" "$@"`, which leaks the
  lock fd into every descendant — including the detached long-lived
  `setsid dwmblocks` daemon, which then held the lock for its whole
  lifetime. First reload worked; every later one blocked 30s and silently
  failed. That regression was strictly worse than the TOCTOU it replaced
  and only manifests on the *second* invocation, so it would not have
  been caught without an independent pass. Now held on an explicit fd
  closed in that spawn via `{LOCKFD}>&-`, verified by `/proc/<pid>/fd`
  and `lslocks`.
- Also fixed: unbounded `wait` (a hung `~/.fehbg` blocked forever), the
  dwmblocks TOCTOU, `mkdir -p` hard-aborting under `set -e` on an
  uncreatable cache dir, and a bash redirection-order leak where
  `: >>"$lock" 2>/dev/null` let the error escape to real stderr because
  redirections apply left to right.
- Reviewer also settled a race noted but unresolved in-thread: dwm
  re-execs while dwmblocks restarts concurrently, and dwm finds dwmblocks
  by `pidof -s dwmblocks` for statuscmd click routing — `getstatusbarpid()`
  self-revalidates, so a stale pid is harmless.
- See `.claude/changes/2026-08-05-theming-reload.md` for full detail.

## 2026-08-05 — theming engine epic, sub-task 6: user commands + keybinds
- Added `scripts/theme/wallpaper.sh [path|--random|--select]` (dmenu
  picker, feh, then the full colorgen -> templates -> reload pipeline) and
  `scripts/theme/theme-apply.sh <name|--wallbash|--list>` (static theme or
  wallpaper-derived, processes both template groups). Plus
  `config/dwm/bin/dwm-wallpaper` / `dwm-theme` wrappers and a new
  `KEYBINDINGS.md` covering all bindings.
- dwm keybinds ship **commented out** in `config.def.h` — enabling them
  changes behavior and needs a rebuild, so it stays the user's choice.
- **Removed the hardcoded `-nb/-nf/-sb/-sf` from `dmenucmd`,
  `dwm-powermenu` and `dwm-clipmenu`.** dmenu CLI colour flags override X
  resources (a deliberate precedence decision in sub-task 1), so those
  three would have kept their compiled-in colours forever — the engine
  would have looked broken exactly where a user looks first. They now
  follow the theme and fall back to compiled defaults when unthemed.
  A stale comment in `suckless/dmenu/config.def.h` asserting the old
  behaviour was also corrected (reviewer catch).
- Verified live with an isolated HOME and a stub dmenu: all three
  wallpaper modes, `--wallbash`, static theme, `--list`/`--help`, and six
  error paths with correct exit codes. dwm and dmenu both still build.
- Reviewer verdict: WARN (the stale comment), fixed. Otherwise READY.
- See `.claude/changes/2026-08-05-theming-user-commands.md` for detail.

## 2026-08-06 — theming engine epic, sub-task 7/7: static theme + packaging + docs
- Closes the Epic. Adds `themes/dark/` (Catppuccin-Mocha-seeded palette
  produced by this repo's own `colorgen.sh`, plus `theme.conf` for what a
  palette cannot express), `themes/CREDITS.md`, `ImageMagick` in
  `extra.lst`, installer deployment of the dunst/picom/GTK base configs
  with manifest tracking, an `uninstall_theme` teardown step, and
  `docs/THEMING.md`.
- **This work was already written but uncommitted and unreviewed** when
  picked up — it had been left in `slot/theming-packaging` with a stub
  plan file. Reconstructed the plan from the diff, then ran the full
  audit + reviewer gate.
- `install-restore.sh` had reached 263 lines (over the 250 cap), so the
  theming block moved to a sourced `scripts/install-restore-theme.sh`,
  mirroring the existing `uninstall.sh` -> `uninstall_steps.sh` precedent.
- **Two real breakages found and fixed.** (1) A failed backup called
  `exit 0`, ending the restore stage with a *success* code and silently
  skipping the zinit/TPM bootstrap clones while `install-fedora.sh`
  proceeded to the services stage. (2) Reviewer BLOCK: the only backup
  step ran inside the `$DISPLAY` gate, so a headless install backed up
  nothing — and when the user later ran `theme-apply.sh` by hand as
  instructed, `apply-templates.sh` overwrote their pre-existing
  `dunstrc`/`picom.conf` with no copy anywhere.
- Also: `gtk-murrine-engine` dropped (GTK2-only engine; `theme.conf`
  selects Adwaita-dark, a GTK3 built-in that never loads it), and
  `CREDITS.md`'s claim that HyDE is MIT-licensed corrected — it is
  GPL-3.0, which is precisely why the engine reimplements rather than
  vendors it.
- See `.claude/changes/2026-08-06-theming-packaging.md`. Reviewer: READY.

## 2026-08-06 — theming engine: vim + cava app templates
- Post-Epic follow-up. Extends the engine from desktop surfaces to two
  applications: `config/theme/templates/always/{vim,cava}.dcol` plus an
  `always/README.md` documenting the group's two target styles.
- Selected from HyDE's six app templates after a survey of what remained
  worth porting; the other four (chrome, discord, spotify, VS Code) theme
  applications this desktop does not assume, and everything else in HyDE
  is Wayland-specific. Reimplemented, not copied — verified mechanically
  that the only lines shared with HyDE's equivalents are `endif`,
  `let g:colors_name = 'wallbash'` and `[color]`, all syntax-mandated.
- **Both render to `$cacheDir` and install via their post-command**,
  rather than writing their real destination directly. The engine's
  install-check is "does the target's parent directory exist", which is a
  good signal for apps configured one level under `$confDir` and a bad
  one here: vim creates neither `~/.config/vim` nor a `colors/` subdir
  (reviewer BLOCK — the template would have skipped for every real user),
  and cava's config is user-tuned, so it is spliced into below a marker
  rather than overwritten.
- **Path-driven quoting break fixed in both post-commands.**
  `expand_path` substitutes `${confDir}`/`${cacheDir}` into the command
  string before `bash -c` parses it, so a `$HOME` containing a single
  quote broke out of the surrounding quoting — the same injection class
  `apply-templates.sh` was hardened against for palette values in
  sub-task 3. Both now derive their paths from XDG variables at run time.
- Accepted reviewer WARN: that fix duplicates `apply-templates.sh`'s own
  `cacheDir` definition. Failure mode is benign (post-command warns and
  continues); recorded in `always/README.md`.
- See `.claude/changes/2026-08-06-theming-app-templates.md`.
  Reviewer: BLOCK -> fixed -> WARN (accepted).

## 2026-08-06 — housekeeping
- `~/.local/state/dots/manifest` held `THEME` rows pointing at the real
  `~/.config/picom/picom.conf` and `gtk-3.0/gtk.css`, left by an earlier
  session that ran the installer against the live `$HOME`. Since
  `uninstall_theme` deletes every `THEME` row outright, `uninstall.sh`
  would have removed configs the installer never created. Backed up to
  `manifest.bak-20260806-114948` and pruned, with the user's approval.
- **Testing note:** sandboxing installer runs requires overriding all four
  XDG variables, not just `HOME` — `XDG_STATE_HOME` is set in the ambient
  environment here, so the manifest write escapes an otherwise-isolated
  test. Likewise always pass `DISPLAY=` when exercising
  `apply-templates.sh`: `xresources.dcol`'s post-command is a bare,
  unbounded `xrdb -merge` that will talk to the live X server.

## 2026-08-06 — roster Epic, sub-task 1/10: zsh de-HyDE + X11 retarget
- Opens Scope B (`.claude/tasks/scope-b-app-roster-finalization.md`), a
  10-sub-task Epic reconciling this repo's app/tool/package roster against
  HyDE's. Locked decisions live in that scope file.
- Deleted 14 HyDE leftovers from `config/zsh/` and ported the genuine
  keepers into their existing owner files (`60-aliases.zsh`,
  `40-completion.zsh`, `70-functions.zsh`) rather than a catch-all.
- **The headline was a live performance bug, not the de-branding.**
  `config/zsh/.zshenv` was HyDE's and sourced all of `conf.d/*.zsh` itself,
  while `.zshrc` ran the same loop behind an interactive guard `.zshenv`
  lacked. Every file loaded twice interactively and once in *every*
  non-interactive shell. Measured `zsh -c true` at **674 ms** against 1.8 ms
  bare — ~570 ms burned per script invocation. `.zshenv` is now env-only
  (XDG + PATH, absorbing the deleted `conf.d/20-path.zsh`), `.zshrc` owns the
  conf.d loop alone. Result: **674 ms -> 4.6 ms** non-interactive,
  **925 ms -> 392 ms** interactive, and the "No plugin system found" banner
  that printed on every shell open is gone.
- `config/zsh/functions/` and `completions/` turned out to be dead code —
  reachable only from `terminal.zsh` branches this machine never hits. Proved
  by running a shell (`eza alias: ABSENT`) rather than by reading; the
  reviewer re-traced it independently.
- zoxide now replaces `cd` outright (`--cmd cd`), so `z`/`zi` cease to exist;
  the `..` aliases and a dead fzf-tab zstyle were updated to match.
- Added `config/starship/starship.toml` (the repo shipped none — the prompt
  ran on stock defaults) plus a `symlinks.sh` LINKS entry and a
  `$STARSHIP_CONFIG` export, since starship reads
  `$XDG_CONFIG_HOME/starship.toml` but `symlinks.sh` links directories.
- **Post-merge discovery, not in the dated log:** the user already has a
  405-line hand-tuned `~/.config/starship/starship.toml` and 135 Nerd Font
  matches installed. The shipped ASCII config is worse than theirs, and
  `symlinks.sh` would displace it. Resolved as its own follow-up before any
  installer step runs.
- See `.claude/changes/2026-08-06-zsh-dehyde-x11.md`. Audit: READY.
  Reviewer: READY. Tests: `tests/lint.sh` + `tests/pkglist.sh` pass.

## 2026-08-06 — roster Epic, sub-task 2/10: package roster + starship + Nerd Font
- Closes the second of the two sub-tasks that unblock the rest of Scope B.
  `packages/extra.lst` gains alacritty, firefox, cascadia-code-nf-fonts, maim,
  slop, xss-lock, bluez, blueman, thunar-volman, ffmpegthumbnailer, unar,
  catfish, zoxide, fastfetch; `kitty` dropped. A "NOT LISTED HERE" header
  documents five deliberate exclusions with the command to get each anyway.
- **16 names verified against packages.fedoraproject.org** (no `dnf` on the
  Arch dev host, so rule 8 meant real lookups). Two failed:
  - **`starship` is not in Fedora at all** — dropped around F37, now COPR-only
    (`atim/starship`). Not cosmetic: sub-task 1 had already made it *the*
    prompt, so a fresh Fedora box would fall back to `prompt adam1` with the
    adopted config unused. The user chose the upstream install script over the
    COPR; `install-pkg.sh` now runs it idempotently, dry-run-aware and
    best-effort, with hardened curl flags.
  - **No JetBrains Mono Nerd Font exists in Fedora.** Cascadia is the only
    `-nf-fonts` family packaged, so it supplies the glyphs and
    `jetbrains-mono-fonts-all` stays for plain UI surfaces.
- **A bug the audit caught before it shipped:** the first draft recorded
  starship as a `PACKAGE` manifest row. `uninstall_packages()` pipes every
  PACKAGE value into a *single* `dnf remove`, so one un-removable name would
  have failed that call and left every other package installed. Row dropped;
  manual removal documented instead.
- **Reviewer BLOCK, and it was right.** The user's adopted `starship.toml` was
  420 lines against the 250-line hard cap, and the audit loop self-granted an
  exception rather than surfacing it — the user had been asked about trimming
  for *performance*, never about the rule. Escalating beat both instincts:
  `split-oversized-file` could not apply (starship has no include directive, so
  the choice was adopt-vs-don't), and the user chose to drop `[section]` blocks
  for toolchains the repo neither declares nor installs. 44 of 59 removed,
  420 -> 151 lines, **byte-identical right-prompt output** verified against the
  original in a directory carrying markers for every kept language.
- **A planning-stage worry retracted, not deferred:** trimming `right_format`
  buys ~1.9 ms/prompt, while `git_status` alone costs ~4.7 ms — about 2.5x what
  all sixty language modules cost together. Measured, not assumed.
- **Open follow-up worth carrying into sub-tasks 3 and 7:** installing the Nerd
  Font does not point the terminals at it. `dwm`/`dmenu` use `monospace`
  (DejaVu Sans Mono here) and `st` uses `Liberation Mono`, so glyphs render via
  fontconfig per-glyph fallback — functional, but with mismatched metrics.
  Also: `uninstall.sh` cannot remove starship without a new `BIN` manifest
  category.
- See `.claude/changes/2026-08-06-packages-roster-fonts.md`. Audit: READY.
  Reviewer: BLOCK -> fixed -> READY. Tests: lint + pkglist pass.

## 2026-08-07 — roster Epic, sub-task 3/11: alacritty as main terminal
- alacritty becomes dwm's `termcmd`; st stays vendored, patched and themed as
  the no-GPU fallback (locked decision 1). Both terminals now agree slot-for-slot
  on the 16 ANSI colours.
- **The theming route is the reusable part.** `config/alacritty/` is symlinked,
  so the engine must never write into it — the hazard that forced `config/dunst`
  and `config/picom` to be *copied*. Alacritty's `general.import` sidesteps the
  trade: colours render to `${cacheDir}/alacritty-colors.toml`, the config
  imports that path, and the repo directory stays fully symlinkable. Recorded as
  a third target style in `config/theme/templates/always/README.md`.
- **Locked decision 15 — the font family is `Cascadia Code NF`, not
  `CaskaydiaCove Nerd Font`.** Fedora's `cascadia-code-nf-fonts` ships
  *Microsoft's* NF release, not the ryanoasis patch. The dev host carries the
  ryanoasis build under `~/.local/share/fonts`, so the wrong spelling resolves
  here and would have rendered tofu on a clean Fedora box. `fc-match` on a wrong
  family returns DejaVu Sans — it degrades silently, never errors. This closed
  the open follow-up from sub-task 2: dwm/dmenu asked for `monospace`, st for
  `Liberation Mono`; all three now name the packaged font.
- **One assumption ships unproven and is flagged as such at all three sites:**
  that `live_config_reload` fires on a rewrite of the *imported* file. It is the
  sole reason `reload.sh` gains no alacritty step. The reviewer returned WARN on
  the first round precisely because the shipped comments asserted it as fact;
  rewritten to separate verified from assumed, with the symptom and remedy named.
- **New sub-task 11 — dynamic scratchpads.** Raised by the user mid-task: they
  want to stash the *focused* window (any app) into a scratchpad, toggle it, and
  drop it back out. That is the `dynamicscratchpads` dwm patch replacing the
  vendored `scratchpads` one — recorded in the scope file as the Epic's
  highest-risk item rather than folded into a terminal task.
- See `.claude/changes/2026-08-07-alacritty-main-terminal.md`. Audit: READY.
  Reviewer: WARN -> fixed -> READY. Tests: lint + pkglist + build pass.

## 2026-08-07 — roster Epic, sub-task 4/11: sxhkd keybind split
- `config/sxhkd/sxhkdrc` is new and is now the second keybinding authority.
  sxhkd had been packaged since sub-task 2 but the repo shipped no config, so
  the installer pulled in a daemon that never started. It takes media
  (`playerctl`/MPRIS), volume + mic (`pamixer`), brightness, the theming
  engine and two app launchers; screenshot and lock ship commented out.
- **The split rule is structural, not stylistic.** dwm and sxhkd both
  `XGrabKey()` on the root window; a keysym+modifier claimed by both goes to
  whichever grabbed first and **the loser silently gets nothing** — no error,
  no log line. Every sxhkd binding is therefore an `XF86*` key or in the
  `Super` space, avoiding the only two Super chords dwm owns
  (`Super+Shift+x`, `Super+v`). Check `keys[]` before adding to either file.
- **The user chose the most conservative split — dwm keeps every binding it
  already has.** Consequence worth recording: `config.def.h`'s diff came out
  **comment-only** (verified mechanically), so existing installs get the whole
  sxhkd layer with **no rebuild** and none of the `rm -f config.h` staleness
  dance sub-task 3 needed. The theming binds are the one thing that moved
  (`Mod+w` → `Super+w`); they had shipped commented out *because* enabling
  them cost a recompile, and that objection is gone.
- `config/dwm/bin/dwm-brightness` (new) implements locked decision 12 —
  `xrandr --brightness` software gamma, clamped 10–100%, every connected
  output. `get` is the read side for sub-task 7's interval-0 status block.
  Two `set -e` bugs were caught in audit and are now a memory entry: under
  `set -euo pipefail` a failing `var="$(cmd)"` exits the script **printing
  nothing at all**, and inlining `apply "$(($(current) + STEP))"` continues
  past a failed read with the empty string treated as 0.
- **DEVIATION — `scripts/install-session.sh` extracted.** The sxhkd autostart
  branch pushed `install-suckless.sh` to 253 lines, past the 250-line hard
  stop. Escalated to the user rather than self-granted as an exception; the
  split was chosen. Same arrangement `install-restore.sh` already has with
  `install-restore-theme.sh`. Proven behaviour-preserving by diffing the
  generated `autostart.sh` against HEAD's.
- `docs/THEMING.md` and `CLAUDE.md` both told the reader to uncomment the
  theming binds in `config.def.h` — not merely stale but actively harmful,
  since following them now collides with `Super+w` and the loser fails
  silently. Fixed in scope-extension after `/test`, with approval.
- **Open:** `sxhkd` sits in `extra.lst` (best-effort), so a failed install
  leaves every binding here dead — same shape as sub-task 3's `alacritty`
  follow-up; consider promoting both to `core.lst`. `tests/lint.sh` globs
  `-maxdepth 2 -name '*.sh'`, so all five `config/dwm/bin/*` scripts are
  outside CI. Grab-disjointness is unverified on real hardware (`xev`).
- See `.claude/changes/2026-08-07-sxhkd-keybind-split.md`. Commits `b8a17e0`,
  `eaff715`. Audit: READY. Reviewer: READY. Tests: lint + pkglist + build pass.

## 2026-08-07 — roster Epic, sub-task 5/11: screenshot (maim + slop)
- `config/dwm/bin/dwm-screenshot` (new, 246 lines) wraps maim + slop + xclip
  behind two sequential dmenu prompts — mode (`full`/`window`/`region`), then
  destination (`clipboard`/`file`/`both`). Either prompt is skipped when the
  matching flag is passed, so a keybind jumps straight to one combination.
  `Print` opens the menu; `shift + Print` is region -> clipboard directly.
- **The slop selector is themed off `dwm.selbordercolor`**, read live from
  `xrdb -query` and converted to the float RGBA `slop --color` wants (hex is
  rejected). The selection rectangle therefore matches the border dwm draws
  around the focused window and re-themes with the wallpaper at no template
  cost. Unthemed it falls back to slop's grey rather than failing.
- **`xprop` chosen over `xdotool`** for the active-window id (user decision,
  offered with the trade-off). `xprop -root _NET_ACTIVE_WINDOW` plus one `awk`
  yields the `0x`-prefixed form and `maim -i` parses it verbatim — confirmed by
  invocation, not assumed. xdotool would need no parsing but drags in libxdo
  for a single lookup.
- **`Print` is absent from dwm's `keys[]`**, so sxhkd may grab it and
  `config.def.h` is untouched — no rebuild, same as sub-task 4.
- **`window` mode overlaps `region` mode more than the scope file implies.**
  slop's default `--tolerance` of 2 means a plain click inside a region
  selection already snaps to the window under the pointer. Window mode's only
  real advantage is being mouse-free. Kept, but documented as not an
  independent capability.
- **Three live bugs came out of the audit loop, none from the plan:** `xclip`
  was required at startup though `--file` never touches it; slop's stderr was
  discarded, making a failed pointer grab both silent and indistinguishable
  from a cancel (slop exits 1 with empty stdout for *both*); and the
  destination was validated only inside `deliver()` — after the capture, i.e.
  in region mode after a whole selection drag performed for nothing.
- **Testing memory updated, twice, from false passes.** Leaving `/usr/bin` on
  the harness `PATH` made all three "binary not installed" cases exercise the
  real binaries; and once `PATH` really was isolated, the fake `dmenu` broke
  because it called `cat`. `PATH` must be the fake dir and nothing else, with
  the handful of real tools symlinked in explicitly.
- **Open:** `maim`, `slop` and `xprop` all sit in `extra.lst` (best-effort) —
  third sub-task running to raise this; `dwm-screenshot` is at 246/250 lines,
  so the next edit crosses the cap (seam: the two theming helpers, which
  sub-task 6 may want anyway); `tests/lint.sh` still globs `-maxdepth 2`, so
  all six `config/dwm/bin/*` scripts are outside CI.
- See `.claude/changes/2026-08-07-screenshot-maim-slop.md`. Commits `b2dcb13`,
  `68eed57`. Audit: READY. Reviewer: READY. Tests: lint + pkglist + build pass,
  plus 70 assertions across 25 scenarios against faked binaries.

## 2026-08-07 — roster Epic, sub-task 6/11: lock / idle (xss-lock)
- `config/dwm/bin/dwm-lock` (new, 140 lines) owns every path to a locked
  screen. `--daemon` arms `xset s 600 600` + `xset dpms 0 0 660` then execs
  `xss-lock -- slock`; bare `dwm-lock` locks now. `super + l` goes live —
  it was `sxhkdrc`'s last pending binding, so every entry in that file is
  now active. `dwm-powermenu`'s Lock entry routes through the same script.
- **`--transfer-sleep-lock` is deliberately omitted, and this is the
  non-obvious part.** xss-lock(1): the fd "will only be set if the reason for
  locking is that the system is preparing to go to sleep. The locker should
  close this file descriptor to indicate it is ready." slock has never heard
  of `$XSS_SLEEP_LOCK_FD` and never closes it, so the delay inhibitor would be
  pinned for the whole locked session; logind then waits `InhibitDelayMaxSec`
  (5s default) and suspends anyway. Up to five seconds added to every suspend
  for nothing — slock grabs instantly, so there is no readiness to wait on.
- **Manual lock prefers logind with a fallback** (user decision, offered with
  all three shapes): `loginctl lock-session` while xss-lock runs, else `slock`
  directly. Keeps logind's `Locked` state truthful and gives one place to swap
  the locker, without the silent no-op a bare `loginctl` would produce.
- **Timings: lock at 10 min, monitor off at 11** (user choice from four
  options). The ordering carries the reasoning — lock must precede blank or
  the display goes dark while unlocked and a mouse wiggle lands on a live
  desktop. Both are named constants at the top of the script.
- **The autostart line spells the path out in full** rather than trusting
  PATH, unlike the three system daemons above it. `~/.config/dwm/bin` reaches
  PATH via `.zshenv`, which only runs if the display manager starts the session
  through a login zsh. A powermenu that fails to spawn is noticed instantly; a
  lock daemon that fails to start is noticed the first time the screen doesn't
  lock. `autostart.sh` is user-owned on creation (rule 6), so that line can
  never be corrected later — verified by md5 that a pre-existing file comes
  out byte-identical, with the missing line printed instead.
- **No rebuild.** `MODKEY` is `Mod1Mask`, so dwm's `XK_l` is `Alt+l`
  (setmfact); dwm's only Super chords remain `Super+Shift+x` and `Super+v`.
- **`dwm-lock` contains no command substitutions at all**, so the
  `var="$(cmd)"`-aborts-silently-under-`set -e` class that produced two bugs in
  sub-task 4 is structurally absent rather than merely avoided. The one audit
  finding was different: extra arguments were silently ignored, so
  `dwm-lock --daemon --transfer-sleep-lock` would have started the daemon and
  dropped the flag — realistic, given the header explains why that flag is
  absent. Now rejected by an arity check.
- **Testing memory extended: mutation-test the harness before believing it.**
  "64/64 passed" is a claim about the assertions as much as the code, so two
  mutants (a wrong `LOCK_SECS`, a disabled logind route) were injected and each
  confirmed to break a different set of assertions before the green run was
  reported.
- **Open:** `procps-ng`/`pgrep` is undeclared in `packages/*.lst` while
  `autostart.sh` and now `dwm-lock` both depend on it — folded into the
  extra.lst promotion item now queued below.
- See `.claude/changes/2026-08-07-lock-idle-xss-lock.md`. Commits `4ebf84b`,
  `7dced3f`. Audit: READY. Reviewer: READY (clean first round). Tests: lint +
  pkglist + build pass, plus 64 assertions across 22 scenarios and four
  sandboxed installer runs.

## 2026-08-07 — roster Epic, sub-task 7/11: status bar blocks (Layout A)
- **Seven new block scripts** under `suckless/dwmblocks/scripts/` — `dwm-updates`,
  `dwm-disk`, `dwm-temp`, `dwm-brightness-block`, `dwm-mic`, `dwm-vol`,
  `dwm-bluetooth` — completing the locked ten-row order
  `UPD DISK TEMP CPU MEM GAMMA MIC VOL BT clock`, systray still furthest right.
  The three pre-existing blocks were renumbered (cpu 1->4, ram 2->5, clock
  3->10) in lockstep with `blocks.def.h`.
- **Blocks 6-8 run at interval 0 — signal-driven only, never polled.** That is
  locked decision 9 applied to the three values that change only on a keypress;
  sub-task 4's `pkill -RTMIN+6/7/8 dwmblocks` senders are what refresh them.
  Verified mechanically that those three signals map to exactly those blocks.
  Accepted cost: changing volume/mic/gamma from a shell leaves the bar stale
  until the next keypress.
- **DEVIATION — `suckless/dwm/config.def.h` moved from Forbidden into Scope**
  (surfaced before writing `dwm-vol`, resolved by the user). The locked table
  gives block 8 "scroll -> +/-5%", but dwm bound `ClkStatusText` for Button1/2/3
  only, so scroll was discarded before any block saw it. Two rows in `buttons[]`
  fix it for every block. **Consequence: this needs a dwm rebuild, not just a
  dwmblocks one** — existing installs need `rm -f suckless/dwm/config.h` before
  `install-suckless.sh --skip-deps`. Documented inline in `KEYBINDINGS.md`.
- **`updates` is `dnf -C check-update`, cache-only** (user choice of three).
  `-C` is load-bearing, not an optimisation: dwmblocks runs blocks
  synchronously, so one network-bound block stalls the entire bar. Fedora's own
  `dnf-makecache.timer` keeps metadata fresh, so no unit of ours is needed.
  **Unverified — no dnf on this Arch host.**
- **The brightness block is `dwm-brightness-block`, not `dwm-brightness`.**
  Blocks install to `~/.local/bin`, which `.zshenv` puts *ahead* of
  `~/.config/dwm/bin`, so the natural name would have shadowed the control
  script it calls and sxhkd's `dwm-brightness up` would have invoked the status
  block instead — silently. Only collision in the roster; found by checking.
  Its label is `GAMMA` per locked decision 12, since `xrandr` scales the output
  signal and saves no power.
- **`dwm-temp` matches sensors by name, never by hwmon number**, and prints
  `n/a` rather than falling back. This host proves the risk: its `hwmon0` *is*
  the NVMe drive, so "first sensor with `temp1_input`" would report drive
  temperature as CPU temperature.
- **Two harness bugs found mid-run, both of which had produced a false pass:** a
  `\-C` pattern bash never matches literally, and a `${FAKE_BRIGHT:-70}` whose
  `:-` substituted the default for the deliberately-empty value, so the "xrandr
  returned nothing" case had never run. Both folded into the testing memory.
- **Open:** `tests/lint.sh`'s `-maxdepth 2 -name '*.sh'` glob excludes all ten
  block scripts — third sub-task to raise it and now the most acute, this one
  adding 452 lines CI never sees; `SC1090` fires on all ten; `dwm-updates` is
  unverified against real `dnf5`; nothing has rendered in a real dwm bar.
- See `.claude/changes/2026-08-07-statusbar-blocks.md`. Commits `d2a2c57`,
  `b8a9dce`. Audit: READY. Reviewer: READY. Tests: lint + pkglist + build pass,
  plus 53 assertions across 29 scenarios and five mutants, all caught.

## 2026-08-07 — roster Epic, sub-task 8/11: thunar finalization
- **Five new config files**, none of which existed before — `config/thunar/
  {thunarrc,uca.xml}`, `config/xfce4/helpers.rc`, `config/mimeapps.list`,
  `config/applications/dots-nvim.desktop` — deployed by a new
  `scripts/install-restore-apps.sh` (sourced by `install-restore.sh`) and
  removed by a new `scripts/uninstall-apps.sh` (its own file because
  `uninstall_steps.sh` sits at 230 of the 250-line cap).
- **All COPIED, never symlinked.** Thunar rewrites `uca.xml`,
  xfce4-mime-settings rewrites `helpers.rc`, GIO rewrites `mimeapps.list` —
  a symlink would send every one of those writes into this repo. Same rule
  that keeps `config/dunst` and `config/picom` out of `symlinks.sh`, which
  was accordingly in the plan's Forbidden list.
- **`thunarrc` is a one-time migration file, not the live config.** Thunar
  4.20 keeps preferences in the xfconf `thunar` channel; upstream
  `thunar_preferences_init()` reads `thunarrc` only when xfconf has no
  `/last-view` and skips any property xfconf already holds. This host proves
  it — `thunar.xml` has `/last-view` and no `thunarrc` exists at all. So the
  mechanism that actually applies preferences is a guarded `xfconf-query`
  pass; `thunarrc` survives only for a fresh box that has never launched
  Thunar *and* had no session D-Bus at install time. The pass **only sets a
  property with no value yet**, so an installer re-run never reverts a choice
  made in Thunar's own dialog.
- **`exo-open --launch TerminalEmulator` no longer works unaided** (user
  decision, re-asked). exo 4.15.1 moved the helper framework out
  ("Removed binaries: exo-compose-mail, exo-helper-2") into xfce4-settings,
  which ships `xfce4-mime-helper` and the `/usr/share/xfce4/helpers/*.desktop`
  definitions. Proved by intercepting the call with a fake `xfce4-mime-helper`
  on `PATH`. The user's first answer ("helpers.rc only, no package") rested on
  the opposite premise, so it was surfaced with the evidence and re-asked
  rather than shipped inert; `xfce4-settings` is now in `extra.lst` for that
  one binary. `alacritty.desktop` ships upstream there, so no custom helper
  file was needed.
- **GIO silently drops any `.desktop` whose `Exec` binary is missing** — found
  while verifying `mimeapps.list` against real GIO, where the archive entries
  looked broken until the stub pointed at a binary that exists. Hence
  `TryExec=alacritty` on `dots-nvim.desktop`, which degrades cleanly instead
  of leaving `text/plain` on a launcher that cannot run.
- **Audit caught a real shipped-code bug class:** `producer | grep -q` under
  `set -o pipefail` returns 141 even when grep matched, because grep's early
  exit SIGPIPEs the producer. Demonstrated 5/5 on a 200k-row manifest. Fixed
  in the new `app_is_ours`; `install-restore.sh:72` already carried a `|| true`
  for the same trap, and **`install-restore-theme.sh` still has it** in two
  functions — left alone as it was outside this plan's Allowed list.
- `docs/THUNAR.md` is new; `docs/UNINSTALL.md`'s category list gained both the
  new **app configs** entry and the **theme files** entry it had been missing
  since the theming Epic.
- **Open:** `xfconf`/`desktop-file-utils` undeclared (transitive thunar deps,
  both `command -v` guarded) — fifth sub-task feeding the core.lst pass; the
  44-assertion harness is scratchpad-only, as sub-tasks 5-7's were; nothing has
  been run against a real Fedora box or a launched Thunar.
- See `.claude/changes/2026-08-07-thunar-finalization.md`. Commits `b11fd73`,
  `fef865a`. Audit: READY. Reviewer: READY (clean first round). Tests: lint +
  pkglist + build pass, plus 44 assertions across 9 scenarios, six mutants all
  caught, and 12 mime types resolved through real GIO.

## 2026-08-07 — roster Epic, sub-task 10/11: picom performance tuning
- **`config/picom/picom.conf` and `config/theme/templates/always/picom.dcol`
  retuned identically**: `shadow = false` (retiring `shadow-radius`,
  `-opacity`, `-offset-x`, `-offset-y`, `-color` and the whole
  `shadow-exclude` list), `unredir-if-possible = true`, and the removal of
  `detect-rounded-corners` and `detect-transient`. `wintypes` shrank to one
  `tooltip` entry — every other block existed only to switch shadows off per
  window type.
- **Both this host and Fedora 43/44 ship picom v13**, and the user confirmed
  this machine *is* the target, so every option was checked against the
  installed v13 man page rather than inferred. All 23 options in the previous
  config were still valid — nothing had bit-rotted.
- **`unredir-if-possible` with no delay** (user choice of three). Upstream is
  blunt that it is "known to cause flickering when redirecting/unredirecting
  windows"; accepted deliberately — one frame entering or leaving fullscreen
  against a saving on every frame in between. v13's WINDOW RULES `unredir` key
  is the per-window escape hatch; `unredir-if-possible-exclude` is discouraged
  upstream.
- **`detect-transient` came out during the audit, not the plan.** It groups
  windows via `WM_TRANSIENT_FOR` so a group counts as focused together, which
  only changes rendering if focus does — and here it cannot: `inactive-opacity`
  equals `active-opacity`, with no `inactive-dim` or `focus-exclude`. It read a
  property per window to feed a decision with no output. Same reasoning that
  had already removed `detect-rounded-corners`.
- **`picom.dcol` now has zero `<wallbash_*>` placeholders** — `shadow-color`
  was the only one. The user was offered deleting the template outright (which
  would have removed the lockstep hazard the scope file calls this sub-task's
  highest risk) and chose to keep it, so the two files must still be edited
  together by hand.
- **`tests/picom-lockstep.sh` (new)** runs the real template engine against the
  static palette and diffs the output against `picom.conf`, so drift is a red
  build rather than a silent revert. Six mutants, all caught.
- **Testing the engine is itself hazardous, and that shaped the test.** Running
  the whole `always` group fires every post-command, three of which act on the
  live session: `pkill -x dunst`, `pkill -x dwmblocks`, `xrdb -merge`. `pkill`
  matches by process name system-wide, so XDG/HOME sandboxing cannot contain
  it. The test points the engine at a throwaway tree holding only `picom.dcol`,
  with a fake `pkill` on `PATH`; dunst kept the same PID throughout.
- **DEVIATION — `.github/workflows/ci.yml` moved into Allowed** (user-approved
  mid-task). CI lints `tests/*.sh` but has never executed them, so the new test
  would have been linted and never run. A `tests` job now runs them by glob.
  `build.sh` and `lint.sh` are skipped by name with the reason printed — they
  need the X11 toolchain and the three linters respectively — which also means
  **those two have never run in CI and still do not**; the workflow's inline
  reimplementations are what execute.
- **Open:** picom has never parsed this config (not running here; launching it
  would composite over the live session, and a dead `DISPLAY` makes it bail
  before reading the file, with no Xvfb available); making the `lint` and
  `build-suckless` jobs invoke the scripts instead of duplicating them is now
  queued below.
- See `.claude/changes/2026-08-07-picom-perf-tuning.md`. Commits `f4a44aa`,
  `291dfb3`. Audit: READY. Reviewer: READY (clean first round). Tests: lint +
  pkglist + lockstep + build pass, six mutants caught, and the new CI job
  verified to exit 1 on drift.

## 2026-08-07 — roster Epic, sub-task 11/11: dynamic scratchpads (dwm patch swap)
- **The static `scratchpads` patch was un-baked from `dwm.c` and
  `config.def.h`, and `dynamicscratchpads` hand-merged in.** The two cannot
  coexist: old `SPTAG(i) ((1 << LENGTH(tags)) << (i))` vs new
  `SCRATCHPAD_MASK (1u << LENGTH(tags))` both claim bit `LENGTH(tags)`.
  `TAGMASK` is back to vanilla. `dwm-scratchpads-20200414-728d397b.diff`
  deleted; `dwm-dynamicscratchpads-20260807-local.diff` (292 lines) vendored
  in its place, captured against a pre-edit baseline the same way
  `dwm-xresources-20260805-local.diff` was.
- **Dynamic, not pre-declared** — the user asked for *"keybind to put the
  selected window on scratchpads and key for show it and hide it and one to
  drop window from scratchpads"*. `Mod`+`Shift`+`-` stashes the focused
  window, `Mod`+`-` shows/hides and cycles, `Mod`+`=` drops it out.
- **Two of the scope file's three risk warnings did not hold**, and reading
  the source rather than trusting them is what showed it: `pertag` sizes its
  arrays `LENGTH(tags) + 1`, never `NUMTAGS`; `drawbar()` loops
  `i < LENGTH(tags)`, so `hide_vacant_tags` never draws the scratchpad bit.
  The third (that `patch -p1` would not apply against an 11-patch-deep tree)
  was correct.
- **Only one of the three retired scratchpads ever worked** — neither
  `ranger` nor `keepassxc` is in `packages/*.lst`, so `Mod`+`y`'s `st`
  terminal is the single real capability lost. `Mod`+`y`/`u`/`x` are now free.
- **A green `make` would have proved nothing here.** `config.h` is generated
  once from `config.def.h` and gitignored, so the build was re-run after
  `rm -f suckless/dwm/config.h`, and `nm` on the linked binary confirmed the
  five new symbols present and `togglescratch` absent — the swap reached the
  artifact, not just the source.
- **Audit caught two errors, both descriptions of correct code**: an inline
  comment claiming a branch re-shows a window when it stashes one, and a
  `KEYBINDINGS.md` line saying press-again cycles when it hides. Both fixed
  and the vendored diff regenerated and round-trip re-verified.
- **Open:** nothing has run in a live dwm — stash/show/hide/cycle/drop are
  verified by construction, symbol presence and tag arithmetic only.
  **Existing installs need a dwm rebuild** (`rm -f suckless/dwm/config.h` then
  `scripts/install-suckless.sh --skip-deps`). Two upstream behaviours kept and
  documented rather than fixed: a stashed tiled window returns floating, and
  the cycle scans only the current monitor.
- See `.claude/changes/2026-08-07-dynamic-scratchpads.md`. Commits `9202bfb`,
  `2f4006a`. Audit: READY. Reviewer: READY. Tests: lint + pkglist + lockstep +
  build pass, plus a byte-for-byte diff round-trip and numeric tag-mask
  verification.
