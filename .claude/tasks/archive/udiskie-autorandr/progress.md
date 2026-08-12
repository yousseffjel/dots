# Progress — udiskie-autorandr

## Status
`in-progress`

## Steps
- [x] 1. Declare `udiskie` + `autorandr` in `desktop.lst` with consequence comments.
- [x] 2. Split `session_autostart_daemons()` FIRST — 57/60, cannot take two more. Verify tests/autostart-daemons.sh needs no change across the split.
- [x] 3. Add udiskie to the daemon set (`command -v` + `pgrep -x`, backgrounded).
- [x] 4. Add `autorandr --change` — a one-shot, not a daemon. Decide how the test's backgrounded-command detector treats it, explicitly.
- [x] 5. Paired report branches for both in `install-session-report.sh`.
- [x] 6. Roster 7 -> 9; re-confirm by mutant that an unpaired entry still fails.
- [x] 7. CLAUDE.md; full suite + `tests/lint.sh --strict`.

## Deviations
- **The FILE cap bit too, not just the function cap.** The plan foresaw
  `session_autostart_daemons()` breaching 60 lines and split it (step 2), but
  `scripts/install-session.sh` then reached **254 of 250** once both daemons and
  their comments landed. Split again: the whole autostart body
  (`session_autostart_template` + `_display` + `_daemons` + `_services`) moved
  to `scripts/install-session-template.sh`, leaving orchestration behind. Same
  seam the reporting half used at this cap before, and covered by the existing
  `scripts/install-session*.sh` scope glob, so no scope expansion.
- **Removed a stale daemon enumeration rather than extending it.**
  `install_session_autostart()`'s two user-facing strings listed the daemons by
  name and had *already* gone stale — xsettingsd was added last slot without
  updating them. Replaced with wording that cannot drift instead of adding a
  third and fourth name to a list nothing tests.

## Blockers
