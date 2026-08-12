# Review — theme-roster-identity

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 0. Near-miss checked: `usage()` prints its own lines 3-7 via `sed`, and the header rewrite kept them intact. Source order verified on both call paths — `global_fn.sh` before the identity file. |
| 2 | Size/Performance | ✅ | 0. Largest file 225/250 (`tests/theme-identity.sh`), largest function 26/60. The `theme_identity_may_write` extraction shrank both writers from 33 to 26 lines. |
| 3 | Types/Validation | ✅ | 1 found, 1 fixed — a `grep -c \| grep -v '^0$' \|\| true` assertion replaced with an `assert_absent` helper. No suppressions anywhere; `set -u` probe confirms both new globals default correctly when nothing presets them. |
| 4 | Dependencies | ✅ | 0. The identity file sources nothing (leaf — no cycle possible); its only external deps are `manifest_has_path` / `manifest_append_row`, supplied by `global_fn.sh` in both callers. |

**Audit verdict:** ✅ READY

Mutation coverage re-confirmed after the Iteration 3 fix: **9 of 9 deliberate
defects fail the suite**, including both shipped-default mutations.

## Test Gate
**Command:** CI's own two jobs, run verbatim rather than reinvented —
`tests` (glob over `tests/*.sh`, skipping `build.sh`/`lint.sh`) and
`lint` (`bash tests/lint.sh --strict`).

**Discovery:** the `/test` table matched nothing — this repo has no
`.claude/config.yml`, `package.json`, `Makefile`, pytest config, `go.mod` or
`Cargo.toml`. It does have a suite; the table simply does not describe "bash
scripts discovered by a glob in CI". Recorded as a real run, **not** as a skip.

**Result:** ✅ PASSED — 11 tests OK, 0 failed (`tests-job exit: 0`), linters
clean under `--strict` (`lint-job exit: 0`).

**Not run:** `tests/build.sh` — it compiles the suckless programs inside a
Fedora container and needs `dnf`, which this Arch dev host does not have. CI's
`build-suckless` job is the only place it runs. Nothing in this diff touches
`suckless/`, but the gap is real and is stated rather than assumed harmless:
a stale gitignored `suckless/*/config.h` broke that job on main once before
(see `2026-08-12-manifest-has-path.md`), invisible to both CI and the worktree.

## Reviewer Gate
**Verdict:** READY (round 2)

**Notes:** Round 1 returned `WARN` on a real defect the audit missed:
`themes/dark/theme.conf`'s header still described the pre-change behaviour
("theme-apply.sh … reports it") while the three *new* theme.conf files had been
written against the new behaviour. Fixed — dark's header now names the identity
writers and both callers, and dates the change so the "used to only print" fact
survives. Round 2 confirmed the fix, and confirmed no second stale-behaviour doc
remains (it checked `CLAUDE.md`'s claim independently and found it already in
past tense).

**Worth carrying forward:** the stale file was the one I did *not* create.
Writing three new files correctly is what made the fourth look done.
