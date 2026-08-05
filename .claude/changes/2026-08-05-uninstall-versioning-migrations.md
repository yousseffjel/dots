# uninstall-versioning-migrations

## Session Date
2026-08-05

## Context
User requested a full uninstall + versioning + migrations subsystem for
this repo, modeled after HyDE-Project/HyDE's `uninstall.sh`/`version.sh`/
`migrations/` (referenced in an earlier log,
`2026-08-05-installer-stage-dispatcher-split.md`, as functionality this
repo deliberately hadn't built yet). Delivered as one consolidated
five-part feature with separate commits per part, per the user's explicit
request, rather than split across worktree slots.

Landed concurrently with an unrelated parallel effort in the same working
tree (another session/the user directly) that added CI/lint tooling
(`.github/workflows/ci.yml`, `.pre-commit-config.yaml`, `.shellcheckrc`,
`tests/{lint,build,pkglist}.sh`, `TESTING.md`) and rewrote `README.md`'s
top section. Surfaced to the user twice (a `SUDO=""` → `SUDO=()` shellcheck
fix mid-edit, then the broader CI scaffold + competing README edit) and
confirmed how to proceed both times before continuing.

## What Was Requested
1. `VERSION` file (semver) + `scripts/version.sh` (repo/installed
   version, commit, install date, Fedora version, dwm version; `--json`).
2. An install manifest at `~/.local/state/dots/manifest` recording what
   `install-fedora.sh` actually deployed, per stage.
3. `scripts/uninstall.sh` — interactive, `--yes`/`--dry-run`, reversing
   configs/suckless binaries/packages/services/state from the manifest.
4. A migrations framework (`scripts/migrations/`, `scripts/migrate.sh`)
   run automatically by `install-fedora.sh`.
5. `docs/UNINSTALL.md` + a versioning-policy section in `README.md`.

Shared requirements: bash with `set -euo pipefail`, shellcheck-clean,
shared helpers in `scripts/global_fn.sh`, separate commits per feature
with conventional-commit messages.

## What Was Implemented or Decided

### Assumptions disclosed up front (see also `## Assumptions Made`)
The request's file paths/names (`install.sh`, `pkgs/`,
`~/.config/backup_YYYYMMDD_HHMMSS/`) didn't match this repo's actual
structure (`install-fedora.sh`, `packages/{core,extra}.lst`,
`~/.dotfiles-backup/<timestamp>/` via `symlinks.sh`) — built against the
real repo throughout.

### 1. VERSION + scripts/version.sh + scripts/global_fn.sh (commit f46fcc2)
`VERSION` at repo root, starting `0.1.0`. `scripts/global_fn.sh`: shared
`confirm()`/`refuse_root()` plus a manifest read/write library —
`~/.local/state/dots/manifest`, a single tab-separated file, one row per
line, first field is a row type (`META`/`CONFIG`/`SUCKLESS`/`PACKAGE`/
`SERVICE`). Plain `sed`/`awk`/`grep`-parseable by design — no `jq`
dependency, matching this repo's existing package-list parsing
convention. `scripts/version.sh` reads it plus `git rev-parse`, `/etc/
fedora-release` (or `rpm -E %fedora`), and `dwm -v` (confirmed via
`suckless/dwm/dwm.c`: `-v` calls `die("dwm-"VERSION)` to stderr, exit 1 —
handled with `2>&1 | head -1`).

**DECISION REVERSAL**: this repo's own `CLAUDE.md` rule 2 says new scripts
should define their own inline `red()/green()/yellow()/blue()` rather than
"introducing ... a shared sourced file." The user's request this session
explicitly asked for shared helpers in `scripts/global_fn.sh` — treated as
a live, specific override of that standing rule for this one file only.
Existing `install-*.sh` keep their own inline color functions untouched
(no forced refactor) and additionally source `global_fn.sh` only for the
new `confirm()`/`refuse_root()`/`manifest_*` helpers.

Reviewer WARN (fixed pre-commit): `version.sh --json` emitted the string
`"null"` instead of a real JSON `null` for unset manifest fields.

### 2. Manifest tracking wired into every install stage (commit 0068a70)
`install-pkg.sh`, `install-suckless.sh`, `install-services.sh`,
`install-restore.sh` each call `manifest_init` (guarded by `--dry-run`)
and append/upsert rows as they go:
- `PACKAGE` rows only for packages not already installed (checked via
  `rpm -q` before each `dnf install`) — so uninstall later never touches
  anything pre-existing.
- `SUCKLESS` rows for every binary a program's Makefile actually installs
  (dmenu ships four: `dmenu`, `dmenu_path`, `dmenu_run`, `stest`; all
  confirmed via each Makefile's default `PREFIX=/usr/local`).
- `SERVICE` rows only when `ly.service` wasn't already enabled
  (`systemctl is-enabled` guard added).
- `CONFIG` rows (source, target, backup-path-or-`-`) via a new
  `symlinks.sh --list-links` mode (prints the script's managed
  source/target pairs so `install-restore.sh` doesn't duplicate that
  array) plus a before/after scan of `~/.dotfiles-backup/` to detect the
  run's backup dir, if any.

**Bug caught by reviewer (BLOCK, fixed before commit)**: the first cut of
`CONFIG` row writes used plain append-if-missing dedup, but the backup
field legitimately changes between runs (a real path once, then `-` on
every later no-op run) — exact-line dedup can't catch that, so an
idempotent re-run would duplicate the row, and worse, could clobber a real
backup path back to `-`. Fixed with a new `manifest_upsert_row()` in
`global_fn.sh` (replaces by category+first-two-fields) plus an explicit
existing-row check in `install-restore.sh` so a no-op run never overwrites
a previously-recorded real backup with `-`. Verified against a sandboxed
fake `$HOME`: fresh install, backup-triggering conflict, and idempotent
re-run all produce correct, non-duplicated rows.

### 3. scripts/uninstall.sh (commit 829a96e)
Reads the manifest, one confirm() per category: configs (remove + restore
per-row backup), suckless (`make uninstall` per recorded program),
packages (`dnf remove`, manifest-recorded only, list shown before
confirming), services (`systemctl disable`, manifest-recorded only),
state (remove `~/.local/state/dots/`, offering to save a copy of
`uninstall.log` elsewhere first). `--yes`/`--dry-run`, `refuse_root()`,
logs every step to `uninstall.log` via color-helper overrides that mirror
each line (ANSI-stripped) to the log file.

**Two real bugs caught via hands-on sandboxed testing** (not just
`bash -n` — actually running the script against a fake `$HOME`), both
`set -e` traps:
- `_log_line()`'s original `[[ $DRY_RUN -eq 0 ]] && printf ...` as its
  last statement returned non-zero (short-circuited) on every `--dry-run`
  call, and — because it's called as the *last* statement inside
  `red()/green()/yellow()/blue()`, which are themselves called as bare
  top-level statements — this silently aborted the entire script at its
  first log line under `--dry-run`. Fixed with an explicit trailing
  `return 0` plus an `-d "$MANIFEST_DIR"` guard (also needed once state
  removal deletes the log's own directory before the final "complete"
  line).
- The "keep a copy of the log" step did an unconditional interactive
  `read -r -p` for a custom path even under `--yes`, which hangs forever
  non-interactively — reproduced as an actual 2-minute hang, fixed by
  skipping the read when `ASSUME_YES=1`.

(Confirmed empirically, for future reference: a *bare top-level*
`cond && cmd` statement does **not** trip `set -e` when `cond` is false —
only when that pattern is the tail of a function whose call site is
itself unguarded. Both real bugs here were the latter shape.)

### 4. Migrations framework (commit 8baf8a0)
`scripts/migrate.sh` compares the manifest's recorded version against
`VERSION`, walks `scripts/migrations/<from>-to-<to>.sh` one hop at a time,
advancing the manifest's version only after each script exits 0. No-op on
a fresh install or one already current; stops (without falsely claiming
success — see bug below) if no path is found.
`scripts/migrations/0.1.0-to-0.2.0.sh` is a no-op template (inert today
since `VERSION` is still `0.1.0`) documenting the naming convention and
idempotency/fail-loudly expectations for a real migration.
`install-fedora.sh` calls `migrate.sh` unconditionally right after the
pre stage — its own no-op behavior for fresh/current installs makes this
equivalent to gating on "an existing older install" without duplicating
that detection in the orchestrator.

**Bug caught via hand-testing** (a scratch copy of the repo with `VERSION`
temporarily bumped, never the real repo state): the final summary printed
`"already at $repo_version"` even when the chain broke early stuck at the
wrong version — fixed by checking `current != repo_version` first.
**Reviewer WARN (fixed pre-commit)**: the from-version glob match had no
tie-break or ambiguity check if two migration files ever shared the same
`$current-to-` prefix — fixed to error loudly instead of silently picking
one.

### 5. Docs (commit 6c8717c)
`docs/UNINSTALL.md` (what's removed per category, what's always kept,
how backups are restored) and a `README.md` "Versioning" section (patch/
minor/major policy for this repo, tied to `scripts/migrate.sh`). Re-read
`README.md` immediately before editing since the parallel session's
rewrite of it was still possibly in flight — appended cleanly once
confirmed settled (no further edits in ~17 minutes).

## Files Modified
- `VERSION` (new)
- `scripts/global_fn.sh` (new)
- `scripts/version.sh` (new)
- `scripts/uninstall.sh` (new)
- `scripts/migrate.sh` (new)
- `scripts/migrations/0.1.0-to-0.2.0.sh` (new)
- `docs/UNINSTALL.md` (new)
- `scripts/install-pkg.sh`, `scripts/install-restore.sh`,
  `scripts/install-services.sh`, `scripts/install-suckless.sh`,
  `scripts/symlinks.sh`, `scripts/install-fedora.sh` (modified)
- `README.md` (modified — Versioning section only; the CI/pre-commit
  content in it came from the parallel session, not this work)

## Key Technical Decisions
- Manifest format: single tab-separated file with a row-type first field,
  not JSON — no new `jq` dependency, consistent with this repo's existing
  `sed`/`tr`/`grep`-only parsing convention for `packages/*.lst`.
- `manifest_upsert_row()` added alongside `manifest_append_row()` rather
  than changing append semantics globally — only `CONFIG` rows have a
  field that legitimately changes between idempotent runs; `PACKAGE`/
  `SERVICE`/`SUCKLESS` rows are stable once written, so plain
  append-if-missing stays correct and simpler for those.
- `symlinks.sh` gained `--list-links` rather than having
  `install-restore.sh` hardcode a second copy of the `LINKS` array — one
  source of truth for the managed config pairs.
- `uninstall.sh`'s config-restore step reads the manifest's per-row
  backup path directly rather than calling `symlinks.sh --restore` by
  "most recent timestamp" — correct even after multiple installer runs,
  and doesn't require `uninstall.sh` to duplicate `symlinks.sh`'s
  timestamp-picking logic.
- **DECISION REVERSAL** on `CLAUDE.md` rule 2 (shared logging file) — see
  above under part 1.

## Assumptions Made
- Built against the actual repo structure (`install-fedora.sh`,
  `packages/*.lst`, `~/.dotfiles-backup/`) rather than the request
  message's shorthand naming (Type B, disclosed and proceeded, per
  `assumption-transparency.md`).
- `manifest` is one flat file at exactly `~/.local/state/dots/manifest`
  (the literal path given), not a directory of category files — Type B,
  chosen for literal-path fidelity plus staying `sed`/`awk`-parseable.
- `install-fedora.sh` calls `migrate.sh` unconditionally rather than
  first checking "is there an existing older install" — Type B,
  equivalent in effect since `migrate.sh` itself no-ops correctly for
  fresh/current installs, and avoids duplicating version-detection logic
  in the orchestrator.

## Trade-offs
- Five commits landed in one continuous session rather than via separate
  `/plan` worktree slots — this is Epic-scope by the letter of
  `task-planning.md` (new subsystem, 3+ layers, 12+ files), but the user
  explicitly asked for one consolidated feature with separate commits per
  part, which is a materially different shape than "multiple independent
  tasks" the slot model is for. Reclassification disclosed at the start
  of the session.
- No `shellcheck`/`shfmt` available in this environment to verify
  shellcheck-cleanliness mechanically (`tests/lint.sh`, added by the
  parallel session, gracefully skips both when absent) — relied on
  careful manual review, `bash -n` syntax checks, and hands-on sandboxed
  functional testing (which is what actually caught the three real bugs
  above; static analysis alone would have caught none of them, since all
  three were runtime `set -e`/hang behaviors, not syntax issues).

## Open Questions / Blockers
- None. `tests/lint.sh` (markdownlint portion) passes on the new/modified
  docs.

## Next Steps
- Once `shellcheck`/`shfmt` are available (CI, or locally via
  `pre-commit run --all-files` per the parallel session's new tooling),
  run them against every file touched this session and fix anything
  flagged — not done here since neither tool was installed in this
  environment.
- `install-fedora.sh` has still not been run end-to-end on real Fedora
  hardware or in the disposable-container flow `TESTING.md` describes —
  this session's manifest/uninstall/migration code paths were verified
  via sandboxed `$HOME` testing and scratch-copy version bumps, not a
  real Fedora install.
