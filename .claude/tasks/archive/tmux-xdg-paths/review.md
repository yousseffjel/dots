# Review — tmux-xdg-paths

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 0. Rules 2/3, set -euo; own -L socket + TMUX_TMPDIR, user's server untouched. |
| 2 | Size/Performance | ✅ | 1 fixed: fixed sleep before reading the ran-marker -> 3s poll. Test 141 lines. |
| 3 | Types/Validation | ✅ | 0. `|| true` sites backed by existence checks / positive assertions. |
| 4 | Dependencies | ✅ | 0. CI installs tmux for the tests job only. |

Verification: live run green (tmux 3.7c) both XDG set/unset; 4/4 sandboxed mutations CAUGHT (revert resurrect-dir, revert palette, double-quoted run-shell [live-only catch], wrong XDG var); tmux-tpm-lockstep still green; lint green.

**Audit verdict:** ✅ READY

## Reviewer Gate
**Verdict:** READY
**Notes:** Reviewer re-ran all 4 mutations and confirmed isolation. It also reported running `git checkout --` on the real worktree's 30-plugins.conf mid-review and reconstructing it. The implementer re-verified `git diff HEAD` on that file against the authored change, byte-identical, and re-ran the test green before commit.
