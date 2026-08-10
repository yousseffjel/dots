# Context — manifest-has-path

## Background
The 2026-08-10 queue sweep fixed the third and last known `pipefail`/SIGPIPE
site by converting `theme_is_ours` and `theme_backed_up` from
`manifest_rows … | cut -f3 | grep -qxF "$1"` into read loops. `app_is_ours`
had already been converted the same way. The fix left three textually
near-identical functions — the duplication was recorded as an open follow-up
rather than closed in that sweep, because `global_fn.sh` is shared with
`uninstall.sh`/`version.sh` and deserved its own slot.

## Prior Decisions
- `.claude/changes/2026-08-10-queue-sweep-1-5.md` — the read-loop shape and why
  `|| true` is NOT the fix (it maps 141 to 0, the opposite wrong answer).
- MASTER_PLAN queue item 2 explicitly predicts this subsumes item 1.
- CLAUDE.md rule 3 — `SCRIPT_DIR`/`DOTS_DIR` resolution pattern.
- `global_fn.sh` header: callers run `set -euo pipefail` and resolve their own
  paths BEFORE sourcing; this file sets no shell options itself.
- Manifest rows are tab-separated; field 3 is the path. Tags in play: `THEME`,
  `THEMEBACKUP`, `APP`.

## References
- `scripts/global_fn.sh:116-120` — `manifest_rows`, the producer being consumed.
- `scripts/install-restore-theme.sh:18-58` — the two predicates + ~24 lines of
  rationale comment that collapse into one.
- `scripts/install-restore-apps.sh:23-41` — `app_is_ours`, same shape.
- `config/theme/templates/always/README.md` — why the roster slot needs a
  manifest claim in install-restore-theme.sh (engine-owned target, no static base).
- Memory: `installer-test-sandbox-xdg.md`, `bash-pipefail-sigpipe-grep-q.md`.

## Notes
- Verified at plan time: `grep -rn "manifest_has_path" scripts/ tests/` returns
  nothing — no name collision anywhere in the tree.
- 12 files source `global_fn.sh`: install-pkg, install-restore,
  install-restore-apps, install-restore-theme, install-services,
  install-suckless, migrate, migrations/0.1.0-to-0.2.0, uninstall-apps,
  uninstall, uninstall_steps, version.
- Open question for /code: keep `theme_is_ours`/`app_is_ours` as one-line
  wrappers (preserves call sites and their self-documenting names) or replace
  every call site with `manifest_has_path THEME "$x"`. Wrappers cost 3 lines
  each but keep the diff small; direct calls save more lines in the file that
  is up against the cap. Decide by measuring at Step 6.
