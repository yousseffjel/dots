# Review — polkit-autostart-tiers

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 0 found. No Forbidden path touched. **CLAUDE.md rule 6 verified by inspection of control flow**, not assumption: `install_session_autostart()` calls `session_autostart_report` then `return 0`, so the single `>"$autostart"` write is unreachable when the file already exists. The new test sources `install-session.sh`; proved that is safe by running it in a clean `env -i` shell — emits nothing, `rc=0`, defines exactly 8 functions, and defines no colour helpers, so the test's own `red`/`green`/`blue` survive. |
| 2 | Size/Performance | ✅ | 0 found. Every function under 60 after the step-2 splits (largest `session_autostart_daemons` 44); every file under 250. **`scripts/install-session.sh` is at exactly 250 — the cap, with zero headroom.** A seventh daemon forces a file split, not just a function split. Recorded as a follow-up rather than pre-emptively split, which would be scope expansion. |
| 3 | Types/Validation | ✅ | 0 found. No `\| grep -q` or `\| head` introduced (the `pipefail` SIGPIPE trap); no unguarded `var="$(cmd)"` added. The `set -u` empty-array risk on `"${BACKGROUNDED[@]}"` was tested rather than reasoned about: a mutant stripping every backgrounded command yields a clear diagnostic and `rc=1`, no crash. |
| 4 | Dependencies | ✅ | 0 found. The test names only the two public entry points (`session_autostart_template`, `session_autostart_report`) and never the split halves, so a further restructure is invisible to it. `install-suckless.sh:190-191` still sources the file and calls `install_session`. All three new `desktop.lst` entries carry parseable consequence notes. |

**Audit verdict:** ✅ READY

## Test Gate
**Command:** `for t in tests/*.sh; do bash "$t"; done`
**Result:** ✅ PASSED — 8/8 (autostart-daemons, build, desktop-consequences,
fastfetch-template, lint, picom-lockstep, pkglist, starship-template).
The two tests this task touched both report the new numbers:
`autostart-daemons` pairs **6** daemons (was 5) with polkit-gnome launched on a
fresh install and reported on an existing one, and `desktop-consequences`
annotates **29** entries (was 26). `pkglist` still finds all four tiers by glob
with no cross-tier duplicate, confirming the move left no package in two lists.
`build.sh` compiled all five suckless programs against this branch. dunst held
PID 6788 throughout, so the theming-engine tests stayed sandboxed.

## Reviewer Gate
**Verdict:** READY
**Notes:** Clean first round. Cleared each risk named in the brief: rule 6 intact
(the early return on `-e` means an existing `autostart.sh` is only reported on,
never rewritten); the `<<'EOF'` heredocs stay quoted so
`${XDG_CONFIG_HOME:-$HOME/.config}` remains literal in the generated file;
package sets exactly conserved with only the tier reassigned; `install-session.sh`
at exactly 250 lines is at the cap, not over. Ran `tests/autostart-daemons.sh`
directly and confirmed all six daemons pair, in a sandbox that does not touch the
real `$HOME`. Its "87 packages" figure counts `desktop.lst` + `extra.lst` (29+58),
the two lists this task touched — consistent with the 102 total across all four.
