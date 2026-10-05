# config-restore-undo-mode

## Session Date
2026-08-05

## Context
Third and final sub-task of the "Installer framework, Package management,
Config restore" epic (see
`.claude/changes/2026-08-05-package-management-lst-extraction.md` and
`.claude/changes/2026-08-05-installer-stage-dispatcher-split.md` for the
first two). User chose the narrower option for this sub-task: extend
`symlinks.sh`'s existing backup-on-conflict mechanism with an explicit
`--restore [timestamp]` undo mode, rather than HyDE's fuller per-path
policy vocabulary (overwrite/sync/preserve/backup-only/ignore).

## What Was Requested
Add a `--restore [timestamp]` mode to `symlinks.sh` that reverses a prior
backup snapshot from `~/.dotfiles-backup/<timestamp>/` back into place.

## What Was Implemented or Decided
- `scripts/symlinks.sh` arg parsing rewritten from a `for arg in "$@"`
  loop to a `while [[ $# -gt 0 ]]; do ... shift` loop, since `--restore`
  needs to optionally consume a following non-flag argument (the
  timestamp) — the old loop couldn't express that.
- `list_backups()`: with no timestamp given, lists everything under
  `~/.dotfiles-backup/` (or says none found) and exits — read-only, no
  mutation, no `--dry-run` needed for this path since it never writes
  anything regardless.
- `restore_backup(ts)`: for each entry in the existing `LINKS` array whose
  basename exists in that backup dir:
  - If the current target **is** this script's own symlink (`readlink`
    matches the `LINKS` source) — removes it, moves the backup back.
  - If the target is a symlink pointing somewhere else (user repointed it
    after install) — **skipped** with a yellow warning, never touched.
  - If the target exists as a non-symlink (unknown/manually-restored
    state) — **skipped** with a yellow warning, never touched.
  - If nothing is at the target — just moves the backup into place.
  This mirrors the existing `link()` function's "never blind-overwrite"
  philosophy (rule 7) symmetrically for the reverse direction.
  Full `--dry-run` support: every mutating branch has a
  `(dry-run) would ...` counterpart that returns before touching anything.
  After processing, attempts `rmdir` on the timestamp dir (fails
  harmlessly if non-empty — e.g. because an entry was skipped).
- **Bug caught during manual testing, fixed before audit**: built an
  isolated fake-`$HOME` sandbox under the scratchpad dir and ran the full
  round-trip (link -> backup created -> dry-run restore -> real restore ->
  verify original content back, symlink gone, backup dir cleaned up), plus
  the critical safety case (repoint the symlink elsewhere, then restore —
  must skip, not clobber). The dry-run test surfaced a real bug: the
  end-of-function "nothing restored" message was gated on a flag
  (`restored_any`) only set by the branch that actually calls `mv`, so a
  dry-run that printed "(dry-run) would remove symlink..." for a real
  match would *also* print the contradictory "nothing restored" right
  after. Fixed by splitting into `matched_any` (set whenever a backup
  entry is found at all, independent of dry-run/skip/restore outcome),
  used for the "nothing to restore" message.
- `CLAUDE.md`: project map line for `symlinks.sh` now mentions
  `--restore [timestamp]`; rule 7 extended with a sentence describing the
  undo mode and its skip-on-unknown-state safety property.
- Ran the `audit-loop` skill (Medium+ tier — 2 files, +113/-8 per
  `git diff --cached --shortstat`; substituted checklist as in every prior
  session). Iteration 4 caught the CLAUDE.md doc gap (fixed in the same
  pass).
- Spawned the `reviewer` subagent gate against the staged diff: `READY` —
  independently re-traced every dry-run branch to confirm none reach
  `rm`/`mv`, confirmed the skip-condition ordering can't be bypassed,
  re-derived the `matched_any` fix from the diff (didn't just trust the
  description), confirmed `rmdir` can never remove something it shouldn't,
  confirmed quoting/`set -e` safety, confirmed the `--help` sed range, and
  confirmed the CLAUDE.md doc matches actual behavior.

## Files Modified
- `scripts/symlinks.sh` (modified)
- `CLAUDE.md` (modified — untracked file, pre-existing content)

## Key Technical Decisions
1. **Explicit restore/undo mode, not a fuller policy vocabulary** — per
   the user's chosen scope. `LINKS`-driven (only ever touches the 3 paths
   `symlinks.sh` itself manages), no new config format, no new state file
   beyond the backup directories that already existed.
2. **Never overwrite a target that isn't this script's own symlink.** The
   single most important safety property of this feature, since restore
   is inherently destructive-adjacent (removes a symlink, moves files back
   over whatever's there). Verified both by manual sandbox testing (the
   repoint-then-restore case) and by the reviewer's independent trace.
3. **`rmdir`, not `rm -rf`, for backup-dir cleanup.** Only ever removes an
   *already-empty* directory — if any entry was skipped (e.g. the
   not-our-symlink case), the dir still has content and `rmdir` fails
   harmlessly (`2>/dev/null || true`), leaving the partial backup intact
   for the user to handle manually. Never risks deleting anything with
   content.

## Assumptions Made
- **Type C** — `list_backups()` and the "nothing to restore" message don't
  distinguish "backup timestamp directory doesn't exist at all" (handled
  earlier, exits 1) from "directory exists but has no entries matching
  our `LINKS` basenames" (handled by `matched_any`) — both are legitimate,
  non-error outcomes worth two different messages, which the code already
  does correctly; noting this only because it was worth double-checking
  during the bug fix.

## Trade-offs
- No `--restore latest` shorthand — the user must copy a timestamp from
  the `list_backups()` output. Kept minimal per the chosen scope; trivial
  to add later (`ls -t` the backup dir and take the first entry) if it
  turns out to be annoying in practice.

## Open Questions / Blockers
N/A

## Next Steps
- This closes the 3-part epic (package management, installer
  stage-dispatcher, config restore). All three sub-tasks tested manually
  (dry-run + sandboxed functional tests) and passed both the audit-loop
  self-check and the independent reviewer gate.
- Not tested against a live Fedora `dnf`-based install or a real dwm/X11
  session — same pre-existing gap noted in every prior installer session
  in this repo. The restore/undo feature itself *was* fully exercised
  end-to-end in an isolated sandbox `$HOME`, including the safety-critical
  skip case.
- Possible future follow-up (not requested, noted for the backlog): a
  `--restore latest` shorthand; extending `--dry-run`-style safety checks
  to `install-pkg.sh`'s COPR-enable step if it's ever made more complex.
