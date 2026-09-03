# Context — ci-test-runner

## Background
scope-d slot B (`.claude/tasks/scope-d-verification-harvest.md`), harvest
item #6 from the dwm-titus comparison (`.claude/changes/2026-08-24-dwm-titus-reference-clone.md`).
Also closes a bug logged four separate times: `/test` cannot discover this
repo's suite because no `.claude/config.yml` -> `test_command` exists.

## Prior Decisions
- Locked decision 1 (scope-d file): sequential A -> B -> C -> D; B is
  infrastructure, done before C.
- Locked decision 2 (scope-d file): port process-group safety and workspace
  handling from `dwm-titus/scripts/run-tests` — NOT its per-run token
  handshake or root/EUID branches, which back container-as-root tests this
  repo has none of.
- Locked decision 6 (scope-d file): all four XDG vars must be set in any
  sandboxed-`$HOME` test — not directly triggered here (this script doesn't
  sandbox `$HOME` itself, individual tests that do already handle it), noted
  for awareness only.

## References
- `dwm-titus/tests/../scripts/run-tests` — the reference implementation
  (read-only, CLAUDE.md rule 9).
- `.github/workflows/ci.yml` `tests` job — the loop being replaced.
- `TESTING.md` quick-start — the second copy of the same loop.
- `.claude/hooks/_lib.sh` `ck_config_get` — confirms `.claude/config.yml`'s
  simple `key: value` format is what the harness itself already reads.

## Notes
(filled during /code if anything surfaces beyond the plan)
