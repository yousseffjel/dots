# Progress — manifest-has-path

## Status
`complete` — audit ✅ READY, reviewer READY. Awaiting /test + /commit.

## Steps
- [x] 1. Add `manifest_has_path` to global_fn.sh, carrying the pipefail/SIGPIPE rationale once.
- [x] 2. Rewire `theme_is_ours` + `theme_backed_up` onto it in install-restore-theme.sh.
- [x] 3. Rewire `app_is_ours` onto it in install-restore-apps.sh.
- [x] 4. Verify the other 9 global_fn.sh consumers — no collision, no sourcing-order change.
- [x] 5. Add tests/manifest-has-path.sh — mutant proving the old `| grep -qxF` shape fails.
- [x] 6. Re-measure: install-restore-theme.sh < 250, every function < 60.
- [x] 7. Run the full tests/ suite + `tests/lint.sh --strict`.

## Deviations
- **CLAUDE.md added to `## Scope`/`## Allowed` mid-task (announced, not silent).**
  It enumerates `tests/` by filename in two places and says the suite is 9;
  adding a 10th script makes both stale. Not foreseen at plan time. Scope grew
  by one documentation file, no code.
- Step 5: the first draft of the test defined its own `red`/`green`/`blue` per
  CLAUDE.md rule 2, but this test *sources* `global_fn.sh`, which redefines all
  three — so the local copies were dead code (shellcheck SC2329, a real finding,
  not noise). Dropped them; the pre-source failure path uses a raw `printf`.
- Step 5: assertions were rewritten from `cmd && pass || fail` to `assert_hit`/
  `assert_miss` helpers. SC2015 is correct that a failing `pass` would also run
  `fail` — a green suite could have been hiding a broken reporter.

## Blockers
