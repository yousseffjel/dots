# Review — udiskie-autorandr

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 1/1 fixed — `install_session_autostart()`'s dry-run and success strings enumerated the daemons by name and had **already** gone stale (xsettingsd was added last slot without them). Replaced with wording that cannot drift rather than adding two more names to a list nothing tests. |
| 2 | Size/Performance | ✅ | 1/1 fixed — `install-session.sh` reached **254 of 250** after both entries landed. The autostart body moved to `install-session-template.sh`: 97 + 179 + 107. Every function under 60 (largest `session_autostart_display()` at 53). |
| 3 | Types/Validation | ✅ | 0 — shellcheck clean on the new file; the generated `autostart.sh` parses under `/bin/sh` and carries no `set -e`, and both new entries are backgrounded, so neither a failing `autorandr --change` nor a missing profile can abort the rest of the session. |
| 4 | Dependencies | ✅ | 0 — nothing outside the sourced pair references the moved functions; sibling resolved from `BASH_SOURCE`; mode 644 matching `install-session-report.sh`. |

**Audit verdict:** ✅ READY

Tier: Medium+ (11 files, +352/-125) — full 4 sequential sweeps.

Evidence beyond reading:
- The function split was proven **output-equivalent by byte diff**, not by the
  test passing: 88 lines before and after, identical blank-line counts, and
  `sort`ed content identical — pure reordering. The diff also caught two things
  the green test did not: a doubled blank line at the seam, and that xsettingsd
  was still in the interaction half rather than the display half its new comment
  claimed. Both fixed.
- Final generated body: 10 backgrounded entries (8 + 2), the only additions
  being `udiskie …` and `autorandr --change`.
- **Three mutants, all caught**: dropping udiskie's report branch, dropping
  autorandr's report branch, and dropping autorandr's launch line each fail
  `tests/autostart-daemons.sh`. The guard is bidirectional, not one-way.
- Suite 10/10 + `lint.sh --strict`; dunst held PID 2652 throughout.

**Verification asymmetry, stated plainly:** udiskie's flags were checked against
a real binary — but the local one is **2.7.0** and Fedora ships **2.6.2**.
autorandr is not installed here at all and Fedora's package pages list no files,
so its shipped udev rule and XDG autostart file remain **assumed**. udiskie was
deliberately never *run*: `--automount` would have mounted real devices.

**Also unverified:** `--smart-tray` needs dwm's systray as a host, and that
pairing has not been exercised. If the icon never appears, automounting still
works — the tray is the optional half.

## Test Gate
**Command:** `for t in tests/*.sh; do bash "$t"; done` (TESTING.md:13)
**Result:** ✅ PASSED — 10/10, exit 0

Two counters moved with this slot, which is what shows the changes are under
test rather than merely alongside it: daemons **7 -> 9** and annotated packages
**30 -> 32**. Run against the slot's checkout, so `build.sh` compiled from this
branch. dunst held PID 2652 throughout.

`lint.sh` ran without `--strict` here, the spelling the documented runner uses;
the `--strict` form CI passes was run separately during `/code`, including after
the CLAUDE.md warning fix, and also passed.

## Reviewer Gate
**Verdict:** READY (with warning) — warning resolved before commit
**Notes:** WARN — CLAUDE.md was internally inconsistent with its own diff. The
rule 6 paragraph was written *before* the file split later forced by the 250-line
cap, so it attributed `session_autostart_display/_daemons/_services` to
`install-session.sh` when they had since moved to `install-session-template.sh`,
and the project map omitted the new file entirely. Both **fixed** rather than
carried as debt — shipping docs that contradict the same commit is the exact
staleness this slot removed elsewhere (the enumerated daemon list). Re-ran lint
and the pairing test after the fix; both green.

Everything else the reviewer checked came back correct: generated `autostart.sh`
content, the udiskie flags, autorandr's missing `pgrep` guard being defensible
for a one-shot, the test roster, and the size caps.
