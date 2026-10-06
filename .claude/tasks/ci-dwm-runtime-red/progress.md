# Progress — ci-dwm-runtime-red

## Status
`in-progress`

## Steps
- [x] 1. ci.yml: add procps-ng to the test-deps install line.
- [x] 2. dwm-runtime.sh: pgrep/pkill prerequisites; cleanup() cannot change the exit status.
- [x] 3. check_restartsig: X event after SIGHUP; rewrite the wrong comments.
- [x] 4. Verify in a fedora:latest container on a copy.
- [x] 5. Promote restartsig to hard FAIL if it passes reliably; else keep advisory with reason.
- [x] 6. TESTING.md + CHANGELOG.md; run-tests.sh + lint.sh green.

## Deviations
- Step 2: `pgrep` dropped instead of added to the prerequisites — the
  post-restart `pgrep` line was removed (execvp keeps the PID, so it only
  re-found the same number). Only `pkill` is required now.
- Step 3: the X-event poke alone passed 1/3 container runs. Root cause #2:
  the restart detector compared check-window IDs, and the re-exec'd dwm
  usually gets the same X client slot, hence the same ID. Replaced with
  delete-`_NET_SUPPORTING_WM_CHECK`-and-wait-for-it; the delete doubles as
  the waking event. Then 5/5, so step 5 promoted restartsig to hard FAIL.

## Blockers
