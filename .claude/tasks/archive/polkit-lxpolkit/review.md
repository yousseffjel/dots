# Review — polkit-lxpolkit

## Audit Loop

Tier: **Medium+** (7 files, +54/-50 — file count, not line count, sets the tier)
→ full 4 sweeps, sequential. Tier computed with `git diff --shortstat HEAD` and
**nothing staged**, after the previous task's stale-index BLOCK.

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 0. All four coupled sites moved together (desktop.lst / template / report / DAEMONS). The launch line matches the other five daemons' idiom exactly, and the agent now lives in `session_autostart_daemons()` — which is what that function is for, since `/usr/bin/lxpolkit` is on PATH. |
| 2 | Size/Performance | ✅ | 0. `_daemons` 41 → 54 lines, `_services` 39 → 19 (cap 60). All files far under 250. |
| 3 | Types/Validation | ✅ | 0. shellcheck `-x` and shfmt clean. The **generated** `autostart.sh` was produced from the shipped function and passes `bash -n`; launch order is preserved (agent still before `dwm-lock`). |
| 4 | Dependencies | ✅ | 0. `lxpolkit` declared in `desktop.lst` with its load-bearing consequence comment; `polkit-gnome` gone from every `.lst`; `procps-ng` (which provides `pgrep`) already declared. `pgrep -x lxpolkit` is valid because the package ships a `.build-id` entry — it is a compiled ELF, so `comm` is `lxpolkit` (8 chars, under the 15-char `comm` limit) rather than an interpreter name. |

**Audit verdict:** ✅ READY

A zero-issue sweep is what this skill says to distrust. The honest reading: this
is 7 files of substitution with no new logic, and the three real problems were
caught *during* implementation rather than by the sweeps — the function-boundary
move, the "spelled out below" cross-reference, and two stale counts. They are
recorded under Deviations in progress.md, not presented as a clean first draft.

Verification: **14/14 test scripts pass** (`build.sh` skipped — needs the X11
toolchain; CI runs it in the Fedora container). `tests/lint.sh` passes with
shellcheck and shfmt present; markdownlint is not installed here, so its "ok" is
a skip — CI's `--strict` is the gate on the two markdown files touched.

Mutation: **3/3 caught** on the coupling rule 6 exists to protect — template
updated without report, report updated without template, and `DAEMONS` left
naming the retired package. Each fails the build.

## Reviewer Gate
**Verdict:** READY (after one BLOCK, resolved)

**Notes:**

Round 1 — **BLOCK**, on a defect this task introduced: in `HANDOFF.md` the
"Superseded 2026-08-13" note had been spliced into the *middle* of the existing
sentence, leaving its original tail ("the same bug, reintroduced while fixing
it. Both paths are tried.") stranded after the closing paren. The paragraph
therefore asserted that the code still tries two libexec paths, when the
fallback had just been deleted.

Fixed by restoring the 2026-08-08 sentence intact and in the past tense, and
making the supersession a separate following paragraph that states plainly that
the fallback is gone and the block moved to `session_autostart_daemons()`. A
repo-wide grep for the same class of claim found only immutable
`.claude/changes/` history, this task's own plan files, and one past-tense
comment at `install-session-template.sh:157` — the reviewer confirmed that one
reads correctly.

Round 2 — **READY**: the fix matches the actual diff; ordering, `pgrep -x`, the
report-side advice and stray references all re-verified.

**Lesson:** this is the **third consecutive task** where the reviewer caught a
gap between a claim and the code, and the second where the claim was in prose
the four audit sweeps had read separately from the diff. Editing a historical
note in place is its own hazard — the safe shape is to leave the original
sentence whole and append a dated supersession, never to interleave.

Process note: the audit tier was computed with `git diff --shortstat HEAD` and
**nothing staged**, so the reviewer read the working tree. That was the fix for
the previous task's stale-index BLOCK, and it worked.
