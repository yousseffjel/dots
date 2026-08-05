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
