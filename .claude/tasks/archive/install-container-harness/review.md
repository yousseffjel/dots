# Review — install-container-harness

## Audit Loop

Tier: **Medium+** (8 files, +301/−32 at the time of the sweep).

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 1 found / 1 fixed — the stage-banner list was a hand-written enumeration. A renamed stage failed loudly but a newly ADDED stage was silently unchecked. Now extracted from `install-fedora.sh` itself; mutation M7 (inserting a new banner) proves it. |
| 2 | Size/Performance | ✅ | 2 found / 2 fixed — the assert body was 104 lines against a repo max of 30 elsewhere, and `ci.yml` had grown 210 → 418. Resolved by splitting the job into `.github/workflows/install-container.yml` (user's choice of three options); `ci.yml` is byte-for-byte back to 210. |
| 3 | Types/Validation | ✅ | 1 found / 1 fixed — the SERVICE loop used `grep \| while`, whose subshell would swallow a `note()`'s `fail=1` and turn a real finding green. Converted to process substitution, matching the other three loops. |
| 4 | Dependencies | ✅ | 0 found — no new action versions (`checkout@v7`, `cache@v6.1.0` already in use; `upload-artifact` was deliberately dropped rather than pin an unverifiable fourth), no new packages, and only established interfaces consumed (`symlinks.sh --list-links`, the manifest tags `uninstall.sh` already reads). |

**Audit verdict:** ✅ READY

### Residuals — accepted, not fixed

- The assert body is still ~110 inline lines and `tests/lint.sh` does **not**
  lint bash embedded in YAML. It is shellcheck-clean as of 2026-08-13 only
  because it was extracted and checked by hand. Recorded in the new workflow's
  header with instructions to do the same when editing.
- `install-container.yml` is 267 lines, over the 250 this repo enforces on
  `scripts/*.sh`. The cap has never been applied to a workflow (`ci.yml` sat at
  210 without scrutiny), so this is flagged rather than treated as a violation.

## Verification performed

- **Live `fedora:latest` container**, installer run to completion: `RERUN_EXIT=0`,
  all five stage banners plus `✓ install complete`. The re-run doubles as the
  rule-1 idempotency check.
- **Assert step: 22 OK assertions**, exiting 1 on the one genuine problem
  (`polkit-gnome`), extracted verbatim from the workflow rather than paraphrased.
- **7/7 mutations caught**: removed symlink, repointed symlink, deleted suckless
  binary, stripped ZDOTDIR, truncated install.log, stripped the SERVICE row
  (wrong-unit-name proxy), and an added stage banner.
- **Cold install measured at 32 minutes**, which set `timeout-minutes: 90`.
- 12/12 local tests, `tests/lint.sh --strict` clean, all four `run` bodies
  shellcheck-clean.

## Test Gate

**Command:** `for t in tests/*.sh; do bash "$t"; done` (+ `tests/lint.sh --strict`)
**Source:** manual — option B. `/test`'s discovery table matched **nothing**
(no `.claude/config.yml`, `package.json`, `Makefile`, pytest config, `go.mod`
or `Cargo.toml`), so it falls through to "no test suite" despite 13 scripts in
`tests/`. Recording a skip would have been false; the durable fix is a
`.claude/config.yml` with `test_command`, already an open follow-up.
**Result:** ✅ PASSED — 12/12 locally, `--strict` clean. `tests/build.sh`, the
one script this host cannot run (needs `dnf` + the X11 toolchain; this box is
Arch), was executed **in the Fedora container** instead of skipped: all five
suckless programs built, exit 0. **13/13 executed, 0 failures.**

## Reviewer Gate

**Round 1 — BLOCK.** The assert step never checked that `chsh` actually
happened, while the same file's NOT-COVERED block claimed "getent confirms the
shell afterwards". A doc asserting a verification that did not exist — and the
uncovered path was precisely the one just patched for the `$USER: unbound
variable` bug, so the same class of regression would have shipped green.

Fixed by adding a `login shell` assertion that compares `getent`'s shell field
against `command -v zsh` (mirroring `install-services.sh`'s own comparison
rather than hardcoding a path), and by correcting the claim in both the
workflow and `TESTING.md`. Mutation **M8** — reverting root's shell to
`/bin/bash` — now fails the step. Assertions 22 → 23; mutations 7/7 → 8/8.

**Round 2 — READY.**

**Verdict:** READY
**Notes:** One BLOCK in round 1, resolved before commit (above). The finding is
worth carrying: the gap was not in code the audit examined but in a **claim**
made by a comment — the NOT-COVERED block described a check that was never
written. Four structured sweeps read the assertions and the prose separately
and neither noticed they disagreed.
