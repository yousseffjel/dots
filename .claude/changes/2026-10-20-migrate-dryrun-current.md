# migrate-dryrun-current
Date: 2026-10-20
Files: 3 | Lines: +22/-3

## What changed
- `scripts/migrate.sh`: the closing report is one if/elif chain. The dry-run branch was a bare `[[ current != installed ]] && blue …`, which returned 1 when there was nothing to migrate.
- `tests/migrate.sh`: `--dry-run` must exit 0 with a hop to run, when already at VERSION (and say "already at"), and with no path onward.
- CHANGELOG `[Unreleased]` line.

## Why
Void VM edge-case pass: `install-void.sh --dry-run` on an up-to-date install printed `=== migrations ===` and stopped with rc=1 and no message. install-void.sh runs migrate.sh under `set -e`, so the false test ended the whole dry run before the install stage. Every existing install that is current, which is the normal state, was affected. A fresh install exits migrate.sh earlier with 0, so CI's container run never saw it. The old dry-run test never checked the exit code.

## Assumptions
- At VERSION, a dry run prints the same "already at" line a real run does. Type C.

## Test coverage
- 3 new checks failed before the fix; all pass after. Mutant on a copy (drop the `current != installed` half of the condition): caught by "...and says so".
- Void VM, fix overlaid on a main snapshot: `install-void.sh --dry-run` rc=0 through all four stages; manifest byte-identical; no file under HOME (cache and install.log aside) or /etc, /usr/local, /var/service, /usr/bin newer than the start mark.
- Full suite rc=0 (98 OK); lint passed; reviewer READY.

## Follow-ups
- `config/tmux/bin/tmux-sessions` and `tmux-windows` also end on a bare `[[ ]] && …`. Harmless (a popup closes either way), left as is.
- Same VM pass, no finding: `dots version --json` parses; `dots doctor --tsv` is 62 rows, all with 4 fields.
