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
