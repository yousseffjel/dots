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
