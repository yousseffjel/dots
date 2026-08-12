# Review — xsettingsd-theming

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 1/1 fixed — `themes/dark/theme.conf` appeared as a literal at three sites in the new file; extracted `THEME_CONF_REL`, kept repo-relative so it is safe at source time when `DOTS_DIR` may not be in scope yet. |
| 2 | Size/Performance | ✅ | 1/1 fixed — the file reached 286/250 (predicted by the plan). Split into `install-restore-theme-identity.sh`: 193 + 121. Every function under 60; `session_autostart_daemons()` at 57 is flagged below as a forward risk, not a violation. |
| 3 | Types/Validation | ✅ | 1/1 fixed — hoisting the reader would have carried `sed … \| head -1` into shared use, a **fourth** instance of the SIGPIPE/pipefail trap this repo has fixed three times. Rewritten pipe-free as `grep -m1`. Zero suppressions added. |
| 4 | Dependencies | ✅ | 0 — no new external command (`grep` only), no source cycle, sibling resolved from `BASH_SOURCE` so a test can source the parent with no `SCRIPT_DIR`. |

**Audit verdict:** ✅ READY

Tier: Medium+ (14 files, +336/-46) — full 4 sequential sweeps.

Evidence beyond reading:
- Generated config loaded by the **real xsettingsd 1.0.2** — "Loaded 9 settings" —
  and a deliberately malformed value was rejected loudly, so a bad render cannot
  fail silently. Run with `DISPLAY=:99`, which the binary reaches only after
  parsing, so the live session was never touched.
- Writer is idempotent: second run reports "already deployed by us".
- `uninstall.sh --yes` in a four-variable XDG sandbox removed the claimed path
  with no change to uninstall — the manifest claim is generic over THEME rows.
- Guard verified: with `themes/dark/theme.conf` absent, nothing is written.
- `reload.sh` fired `pkill -HUP -x xsettingsd` against a PATH shim; every
  mutating call hit a fake binary.
- `tests/autostart-daemons.sh` **caught the unpaired daemon on its own** before
  the roster was updated, and a mutant (removing the report branch) reproduces
  that failure — so the pairing guard is live, not decorative.
- Split proven behaviour-preserving: the same sandbox script, which sources the
  parent with no `SCRIPT_DIR` set, produced identical output before and after.
- Suite 10/10 + `lint.sh --strict`; dunst held PID 2652 throughout.

**Forward risk for sub-task 3:** `session_autostart_daemons()` is at 57 of 60.
udiskie + autorandr add two more daemons to that same function, so it will
breach the cap — plan the split with that sub-task, not during it.

## Test Gate
**Command:** `for t in tests/*.sh; do bash "$t"; done` (TESTING.md:13)
**Result:** ✅ PASSED — 10/10, exit 0

Run against the slot's checkout, so `build.sh` compiled the suckless programs
from this branch and `autostart-daemons.sh` verified the 7-daemon pairing on the
edited files rather than main's. dunst held PID 2652 throughout — no template
post-command and no `reload_xsettingsd` shim escaped its sandbox.

`lint.sh` ran here without `--strict`, the spelling the documented runner uses;
the `--strict` form CI passes was run separately during `/code` and also passed.

## Reviewer Gate
**Verdict:** READY
**Notes:** Clean first round. Brief pointed it at the highest-risk claims rather
than the diff at large: that the file split is behaviour-preserving (it ran its
own sandbox test and got identical output), that the `sed … | head -1` ->
`grep -m1` rewrite is equivalent for a key present once / absent / containing an
`=` / containing whitespace, that `line="$(grep …)" || return 0` is `set -e`-safe,
that nothing in `apply-templates.sh` expects xsettingsd to be a `.dcol` template,
and that the no-clobber rule survives so a pre-existing user file is never
claimed into a THEME row uninstall would delete.
