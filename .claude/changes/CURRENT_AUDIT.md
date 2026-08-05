# dots — Current Audit State

## Current Scope
Personal Fedora-only dotfiles + dwm/X11 desktop bootstrap repo. Two
threads active as of 2026-08-05: this session's CI/tooling setup
(shellcheck/shfmt/markdownlint/pre-commit/GitHub Actions/tests), and a
concurrent session building install-manifest/versioning/uninstall
tooling (`scripts/global_fn.sh`, `VERSION`, `scripts/version.sh`,
`scripts/uninstall.sh`) — still uncommitted as of this writing. See
recent dated logs in this directory for the running history.

## History Sources
- `.claude/changes/YYYY-MM-DD-*.md` — authoritative dated logs

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
