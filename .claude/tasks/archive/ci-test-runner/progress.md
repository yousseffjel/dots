# Progress — ci-test-runner

## Status
`done`

## Steps
- [x] 1. Write tests/run-tests.sh with hardening
- [x] 2. Add .claude/config.yml
- [x] 3. Replace ci.yml's inline tests-job loop
- [x] 4. Update TESTING.md
- [x] 5. Verify locally (normal + interrupted run, /test discovery)

## Deviations
- Verifying the interrupt path against the real `bash tests/run-tests.sh`
  invocation was unreliable: the whole suite finishes in ~3s, faster than a
  human/tool round-trip can land a `kill -INT` mid-run. Verified instead
  against a minimal standalone reproduction using the exact same trap/
  child-management code from run-tests.sh, substituting `setsid sleep 30 &`
  for the real `run_suite` payload so the interrupt window is generous.
  Confirmed: external SIGINT to the parent -> `interrupt` trap -> `stop_child`
  forwards the signal, escalates to SIGKILL after ~1s if the child (whose
  async `&` start makes bash ignore SIGINT/SIGQUIT by default per POSIX
  shell semantics — a real quirk, not a script bug) is still alive -> child
  reaped via `wait` -> parent exits 130 -> EXIT trap removes the workspace.
  No orphaned process, no leftover workspace directory.

## Blockers
(empty — unblocked)
