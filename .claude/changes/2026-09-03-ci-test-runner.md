# ci-test-runner
Date: 2026-09-03
Files: 4 | Lines: +212/-40 (excludes .claude/tasks/ci-test-runner/ + state bookkeeping)

## What changed
- New `tests/run-tests.sh` — the single owner of "run every test in
  `tests/*.sh`". CI's `tests` job and `TESTING.md`'s quick-start both used
  to hand-copy the same `for t in tests/*.sh; do bash "$t"; done` loop with
  its skip-list rationale as a duplicated comment; both now invoke this
  script instead.
- The script is hardened, logic ported from the local read-only reference
  clone `dwm-titus/scripts/run-tests` (CLAUDE.md "Reference clones") per
  scope-d locked decision 2: refuses an unsafe `$DOTS_TEST_TMP_ROOT` (empty,
  symlinked, `/`, or `/tmp`), `mktemp`s a workspace exported as `TMPDIR` for
  every test, and runs the suite loop as a `setsid`-grouped child under
  `trap`-driven cleanup (EXIT/HUP/INT/TERM) so an interrupted run cannot
  orphan a process. Deliberately **not** ported: dwm-titus's per-run token
  handshake and root/EUID branches, which back container-as-root tests this
  repo has none of.
- New `.claude/config.yml` declaring `test_command: "tests/run-tests.sh"` —
  closes a bug logged four separate times: `/test` had no way to discover
  this repo's suite.
- `ci.yml`'s `tests` job and `TESTING.md`'s quick-start now both just call
  `tests/run-tests.sh`.

## Why
scope-d slot B (`.claude/tasks/scope-d-verification-harvest.md`), harvest
item #6 from the 2026-08-24 dwm-titus comparison. Slot B is infrastructure
the rest of scope-d builds on (locked decision 1).

## Assumptions
- **Type B** — kept the skip list's mechanics (`build.sh`, `lint.sh`, plus
  `run-tests.sh` excluding itself) hardcoded as a literal string inside the
  backgrounded `run_suite` function rather than a variable, because
  `declare -f run_suite; run_suite` re-executed via `setsid bash -c "..."`
  crosses a process boundary that does not carry ordinary shell variables —
  only the explicitly `export`ed `DOTS_DIR` does. Verified this is actually
  necessary, not just easier: an external variable reference in that
  function body would silently resolve to nothing in the child process.

## Test coverage
- `bash tests/run-tests.sh` (both directly and via `/test`'s
  `.claude/config.yml` discovery) — all 15 non-skipped tests pass.
- `bash tests/lint.sh --strict` — clean (shellcheck/shfmt/markdownlint).
- Interrupt-safety was **not** verified against the real
  `tests/run-tests.sh` directly — the full suite completes in ~3s, faster
  than a `kill -INT` sent from a separate tool invocation can reliably land
  mid-run. Verified instead against a standalone reproduction using the
  exact trap/child-management code from the script, substituting
  `setsid sleep 30 &` for the real payload to get a generous interrupt
  window. Confirmed: external SIGINT to the parent -> `interrupt` trap ->
  `stop_child` forwards the signal, escalates to SIGKILL after ~1s if the
  child is still alive (backgrounded children have SIGINT/SIGQUIT ignored
  by default under POSIX shell semantics — a real quirk this design
  tolerates via the KILL escalation, not a script bug) -> child reaped via
  `wait` -> parent exits 130 -> the EXIT trap removes the workspace. No
  orphaned process, no leftover workspace directory. Full detail in
  `.claude/tasks/ci-test-runner/progress.md` ("Deviations").
- Reviewer subagent: **WARN** — `HANDOFF.md:238` still documented the old
  hand-copied loop and a stale "13 scripts" count (the plan's scope named
  `TESTING.md` but not `HANDOFF.md`). Fixed in-session rather than carried
  as debt: the bullet now points at `tests/run-tests.sh` and drops the
  hardcoded count. The separate, explicitly-dated 2026-08-13 decision table
  elsewhere in `HANDOFF.md` was deliberately left untouched — it is a frozen
  historical snapshot, not a currently-authoritative statement.

## Follow-ups
- Start scope-d slot C: `tests/dwm-runtime.sh` under Xvfb.
- scope-d slot D (install/uninstall symmetry) remains open.
