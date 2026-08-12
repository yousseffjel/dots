# Review — dwm-bin-tests

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 1/1 fixed — a bug in my own test: `expect_failure "unknown option"` was called without passing the bad option, so the picker ran with no args, succeeded, and the case asserted nothing. Fixed, plus a `--no-notify` counterpart so "everything is rejected" cannot pass for the wrong reason. |
| 2 | Size/Performance | ✅ | 0 — 206 + 215 lines. One combined file would have been 421, so the two-file split follows the fastfetch/starship precedent out of necessity, not style. |
| 3 | Types/Validation | ✅ | 0 — shellcheck clean on both. `rc` propagation proven rather than assumed: 11 mutants were applied and each failing one made the suite exit non-zero, which it could not do if the assertion loops ran in subshells. |
| 4 | Dependencies | ✅ | 1/1 addressed — the `convert` (ImageMagick 6) branch was never exercised, since only IM7 exists locally. Verified reachable with a forwarding shim: the test reports "using ImageMagick via 'convert'" and passes, exit 0. **IM6 itself remains untested** and is recorded as such rather than claimed. |

**Audit verdict:** ✅ READY

Tier: Medium+ (9 files, +582/-5) — full 4 sequential sweeps.

**Mutation results — the point of the whole task.** A test that cannot fail is
worse than no test, so both were measured, not assumed:

*dwm-colorpicker (5 mutants, 4 caught):*
- drop `-alpha off -depth 8` — the original production bug — **caught**
- drop `-alpha off` alone (RGBA case) — **caught**
- drop `-depth 8` alone (16-bit case) — **caught**
- `-alpha off` -> `-alpha remove -background white` (composites) — **caught**
- loosen `^[0-9A-Fa-f]{6}$` to `{6,8}` — **SURVIVED.** Not a hole worth faking a
  fix for: with normalisation intact, no input tried (RGBA, 16-bit, palette,
  grayscale, CMYK) yields anything but six digits, so the strict regex is a
  second layer that never fires. Killing it would mean asserting on the script's
  source text. Documented in the test header instead.

*dwm-display (6 mutants, 6 caught):* bare `/connected/` match letting a
disconnected output through; `only X` forgetting the others; **labels correct
but the command wrong** (`--off` -> `--auto`) — the case a label-only test would
sail past; autorandr profiles no longer first; extend/mirror offered on a single
monitor; Escape treated as an error.

Both scripts under test were restored byte-for-byte afterwards
(`git status --porcelain config/dwm/bin/` empty), and `## Forbidden` held
throughout — this task tested them as they are and changed neither.

**CI conditions verified directly**, not inferred: on a PATH containing only
bash + coreutils, `dwm-display.sh` passes in full and `dwm-colorpicker.sh` skips
**loudly** with exit 0. That skip is deliberate — faking ImageMagick would leave
the test asserting against its own fixture generator — and it is loud because a
silent skip is the green-job-that-checked-nothing failure `--strict` exists for.

**Live side effects avoided:** `xclip` and `notify-send` are faked or the tests
would overwrite the real clipboard and post real notifications; `xrandr` is
faked or it would reconfigure the tester's displays. The real display was
confirmed still connected after the run.

## Test Gate
**Command:** `for t in tests/*.sh; do bash "$t"; done` (TESTING.md:13)
**Result:** ✅ PASSED — 12/12, exit 0

Suite 10 -> 12, and this is the first slot where the two new entries ARE the
deliverable rather than a side effect: `dwm-colorpicker.sh` and
`dwm-display.sh` appear in the runner because `tests/*.sh` is a glob, so CI
picks them up with no workflow change. dunst held PID 2652 throughout, and the
real display was still connected afterwards.

Unlike the previous slot, the green run here is meaningful for the thing being
delivered — 12 of 13 mutations against the two scripts under test fail the
suite, which is what makes these assertions load-bearing rather than decorative.

## Reviewer Gate
**Verdict:** READY (with warning) — warning resolved before commit

**WARN:** `tests/dwm-display.sh` never asserted `--primary`. Dropping it from
the "only X" preset survived all 17 assertions — a plausible silent regression
that my claimed 6/6 coverage missed. The reviewer found it by trying a mutation
I had not, which is exactly what it was asked to do and the right check for a
task whose entire premise is whether these tests can fail.

**Resolved rather than carried.** Three assertions added, covering `--primary`
on the only/extend/mirror presets. Both the reviewer's exact mutation and the
related extend/mirror variant are now **caught**. Suite 12/12, `--strict` clean,
scripts restored unmodified.

Worth recording *why* it slipped: my mutants all targeted behaviour I had just
written and was therefore already thinking about. The gap was in a flag I had
treated as incidental. Mutation testing only covers the mutations you imagine —
which is the argument for the independent gate, not against the technique.
