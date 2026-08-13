# Review — hyde-parity

## Audit Loop

Tier: **Medium+** (37 files, +1886/-69) → full 4 sweeps, sequential.

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 0. Rules 1/2/3 upheld. The single rule-3 departure — `readlink -f` in `scripts/dots` — is required (the command is reached through a symlink, so `cd "$(dirname …)"` would resolve `~/.local/bin`, not the repo) and documented in situ, in CLAUDE.md, and in the test that proves it. Both new sourced helpers correctly omit `set -euo pipefail` and inherit the caller's colour helpers, matching the four existing sourced helpers. Source graph is an acyclic tree. |
| 2 | Size/Performance | ✅ | 1 found, 1 fixed. `restore_cursor_theme` was **exactly** at the 60-line cap — compliant but one line from a hard stop, in a repo with a documented history of splitting under that pressure. Extracted `cursor_select_tarball` (60 → 47 lines); all six behavioural paths re-proved identical afterwards. All files within 250. |
| 3 | Types/Validation | ✅ | 1 found, 1 fixed. `mkdir -p` / `ln -s` in `restore_dots_bin` were unguarded; under the caller's `set -e` a failure would have **aborted the entire restore stage** — every later step skipped — over a convenience symlink. Now degrades loudly, verified against a read-only `~/.local/bin`. No new shellcheck suppressions; no SIGPIPE-prone pipelines; every `var=$(cmd)` either guarded or the repo's standard top-level idiom. |
| 4 | Dependencies | ✅ | 1 found, 1 fixed. **`xz` was declared nowhere.** GNU tar's `-J` filters through the external `xz` binary rather than linking liblzma, so `tar -xJf` fails without it and the cursor theme never deploys. Added to `desktop.lst` with its load-bearing consequence comment; package name verified against packages.fedoraproject.org (HTTP 200, current releases). |

**Audit verdict:** ✅ READY

Verification at audit close: **14/14 test scripts pass** (`build.sh` skipped — needs the X11 toolchain, and is run by CI's `build-suckless` job inside the Fedora container). `tests/lint.sh` passes with shellcheck and shfmt present; **markdownlint is not installed on this host, so its "ok" is a skip, not a check** — CI's `--strict` is what actually enforces it.

Mutation testing: **19/19 caught** across the two new suites. Two first-pass entries were harness bugs, not survivors (one anchor never matched due to backslash escaping; one "mutation" was a no-op replacement) — both re-run correctly and both died.

## Reviewer Gate
**Verdict:** READY (after one BLOCK, resolved)

**Notes:**

Round 1 — **BLOCK**: `packages/desktop.lst` was absent from the staged diff
while the staged `install-restore-cursor.sh` unconditionally called
`tar -xJf`, so the committed changeset would have shipped the cursor feature
with its `xz` dependency undeclared.

The finding was correct about the *committed* state and the cause was a process
bug, not a missing change: `git add -A` had been run to compute the audit tier
**before** the audit fixes were written, leaving a stale index. Four paths were
unstaged — `desktop.lst`, `install-restore-bin.sh`, `install-restore-cursor.sh`
and this file — meaning the reviewer had also not seen the 60-line split or the
`ln` guard. Everything was staged and the same reviewer re-ran against the full
38-file changeset.

Round 2 — **READY**: "Docs match code precisely; no unsupported claims. All
five questions check out against the fully staged diff." The five challenges
put to it were the DOTS_CMD sed-substitution mechanism, the not-ours guards in
both `restore_dots_bin` and `restore_cursor_theme`, comment/doc claims the code
does not perform, the completion's flag parsing against a non-zero-exit
`--help`, and the `xz` tier plus desktop.lst's consequence-comment contract.

**Lesson worth carrying:** stage after fixing, not before auditing — the gate
reads the index, so a stale one has it reviewing something nobody is about to
commit. This is the second consecutive task where the reviewer caught a
discrepancy between what was *claimed* and what was actually there.
