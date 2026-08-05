# install-fedora.sh run logging

## Session Date
2026-08-05

## Context
User request to add installation logging to the dotfiles installer so
full runs (including every stage script invoked as a child process) get
captured to a file for later review/debugging, without losing live
colored terminal output.

## What Was Requested
In `scripts/install-fedora.sh`, right after `set -euo pipefail` and
`SCRIPT_DIR`, redirect all stdout+stderr of the whole run (orchestrator +
every stage script it invokes) to both the terminal (colored, live) and
an append-mode `install.log` at the repo root (ANSI codes stripped from
the log only). Echo a timestamped "run started (args: ...)" header at the
start and a matching "run finished" line at the end. Decide and document
whether `--dry-run` runs are logged too. Add `install.log` to
`.gitignore`. No other behavior changes.

## What Was Implemented or Decided
- Added `DOTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"` immediately after
  `SCRIPT_DIR`, following the repo's existing `SCRIPT_DIR`→`DOTS_DIR`
  convention (project rule 3) — this script didn't have `DOTS_DIR` yet
  and needed the repo root for the log path anyway.
- `LOG_FILE="$DOTS_DIR/install.log"`, then
  `exec > >(tee >(sed -u 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE")) 2>&1`
  placed right after `set -euo pipefail`/`SCRIPT_DIR`/`DOTS_DIR`, before
  the color helper functions. Because it's an `exec` on the current
  shell (not a script-level pipe), every later `"$SCRIPT_DIR/install-*.sh"`
  child invocation inherits the same fds automatically — no per-stage
  changes needed.
- `echo "=== install-fedora.sh run started: $(date '+%Y-%m-%d %H:%M:%S') (args: $*) ==="`
  right after the redirect is wired up.
- `trap 'echo "=== install-fedora.sh run finished: ... ==="' EXIT` instead
  of a plain trailing echo, so the closing line prints on **every** exit
  path — success, the early `exit 0` in the `-h|--help` branch, and any
  `set -e`-triggered error exit — not just the happy path.
- `--dry-run` runs are logged too (not skipped) — see Key Technical
  Decisions.
- Added `install.log` to `.gitignore`.

## Files Modified
- `scripts/install-fedora.sh` — added `DOTS_DIR`, `LOG_FILE`, the
  `exec`+`tee`+`sed` redirect, start/finish log headers via `trap`.
- `.gitignore` — added `install.log`.

## Key Technical Decisions
1. **`--dry-run` runs are logged, not skipped.** The task explicitly left
   this as an open choice. Chose "always log" over branching logic: it's
   simpler (no conditional around the `exec` line), and a dry-run's
   printed stage plan is exactly the kind of output worth keeping to diff
   against a later real run.
2. **`trap ... EXIT` for the closing line, not a trailing `echo`.** A
   plain trailing `echo` at the bottom of the script would never run on
   the `-h`/`--help` early `exit 0` or on any `set -e` failure exit —
   both are real paths through this script. `trap EXIT` fires on both,
   so "run started" is always paired with a "run finished" in the log.
3. **`sed -u` (unbuffered), matching the user's suggested command plus
   one flag.** Without `-u`, GNU `sed` block-buffers when its output
   isn't a terminal (true here — it's writing to `install.log`), so log
   lines could lag behind terminal output instead of appearing live.
4. **Introduced `DOTS_DIR` for this script.** Not previously present in
   `install-fedora.sh`; added because the log path needs the repo root
   and the project already has a standard pattern for computing it
   (`file-architecture`/rule 3 in the project `CLAUDE.md`) — reused it
   rather than inlining a one-off `cd .. && pwd`.

## Assumptions Made
- **Type C** — placed the `exec` redirect before the `red/green/yellow/blue`
  helper definitions (matches the literal ordering requested: "right
  after `set -euo pipefail` and the `SCRIPT_DIR` variable") rather than
  after them. No functional difference either way since the helpers are
  just `printf` wrappers invoked later.

## Trade-offs
- Chose to always log `--dry-run` runs (see Decision 1) over adding a
  flag to opt out — simpler, and nothing in the request suggested users
  want dry-runs excluded from the log.
- Did not add per-stage script logging — the task explicitly scoped this
  to the orchestrator only ("child processes inherit the redirect"),
  which the `exec`-before-child-invocation approach delivers for free.

## Open Questions / Blockers
N/A

## Next Steps
- Not tested against a live Fedora `dnf`-based install — verified via
  `bash -n` syntax check and functional tests in this sandbox: `-h`
  (early `exit 0` path), an unknown-argument error path (`exit 1`), and
  two successive runs confirming append-mode accumulation with correct
  start/finish pairing. Confirmed terminal output retains raw ANSI escape
  bytes while `install.log` has zero ESC bytes.
- Passed both the audit-loop self-check (Small tier: Architecture +
  Size/Types sweeps, 17 lines/2 files, no violations) and the independent
  reviewer gate (verdict: READY).
