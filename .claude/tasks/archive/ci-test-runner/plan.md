# Plan — ci-test-runner

## Goal
No script owns "run every test." CI's `tests` job inlines a `for t in
tests/*.sh` loop, `TESTING.md`'s quick-start hand-copies the same loop, and
`/test` has failed to discover this suite four separate logged times because
nothing declares `test_command`. Add `tests/run-tests.sh` as the single
owner (glob + skip list + report), harden it per scope-d locked decision 2
(ported from `dwm-titus/scripts/run-tests`, minus its runner-token and
root/EUID branches, which back cases this repo has none of), and point
`.claude/config.yml`, `ci.yml` and `TESTING.md` at it instead of restating
the loop.

## Scope
- tests/run-tests.sh (new)
- .claude/config.yml (new)
- .github/workflows/ci.yml (tests job)
- TESTING.md (quick-start + individual-scripts section)

## Allowed
- tests/run-tests.sh
- .claude/config.yml
- .github/workflows/ci.yml
- TESTING.md

## Forbidden
- Any other tests/*.sh (their behavior is unchanged, only invoked differently)
- packages/*.lst

## Steps
1. Write `tests/run-tests.sh`: workspace-root validation (refuse empty/
   symlinked/`/`/`/tmp` roots), `mktemp` workspace + `TMPDIR` export,
   `trap`-driven cleanup on EXIT/HUP/INT/TERM, run the glob+skip+report loop
   as a `setsid`-grouped child so an interrupted run kills the whole group.
2. Add `.claude/config.yml` with `test_command: "tests/run-tests.sh"`.
3. Replace `ci.yml`'s inline `tests` job loop with a single
   `tests/run-tests.sh` invocation; move the skip-list rationale comment
   into the script itself (single owner, not two copies).
4. Update `TESTING.md`: quick-start's `for t in tests/*.sh...` line becomes
   `tests/run-tests.sh`, plus one documentation bullet in "Individual test
   scripts" crediting the dwm-titus harvest and stating what's ported vs.
   deliberately dropped.
5. Verify: run `tests/run-tests.sh` locally (normal exit, and Ctrl-C mid-run
   leaves no orphaned `bash` child via `pgrep`); confirm `/test` now
   discovers it via `.claude/config.yml`.

## Out of scope
- scope-d slots C, D.
- Adding new individual test scripts.

## Risks
- Backgrounding a shell function across a `setsid bash -c` boundary loses
  ordinary variable scope — mitigated by inlining the skip list literally
  inside the backgrounded function body (only `DOTS_DIR`, an exported plain
  string, crosses the boundary).
- No real container/root scenario to test EUID branches against — mitigated
  by decision 2's explicit instruction to drop them, not port them unverified.
