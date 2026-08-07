# Review — screenshot-maim-slop

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 1 — the `sxhkdrc` header asserted every binding is an `XF86*` key or in the `Super` space. `Print` is neither, so the claim was false the moment this task landed. Corrected. |
| 2 | Size/Performance | ✅ | 1 — file reached 249 of the 250-line cap while carrying the valid mode/destination lists twice. The unreachable `*)` arms in `capture()`/`deliver()` were removed, giving one source of truth and 246 lines. |
| 3 | Types/Validation | ✅ | 3 — `xclip` was required at startup although `--file` never touches the clipboard; `slop`'s stderr was discarded, making a failed pointer grab indistinguishable from a cancel *and* completely silent; `DEST` was validated only inside `deliver()`, i.e. after a capture (in region mode, after a whole selection drag). |
| 4 | Dependencies | ✅ | 0 — one new package (`xprop`), verified on packages.fedoraproject.org for F43/F44/rawhide. Every helper in the script is referenced; no dead code left. |

**Audit verdict:** ✅ READY

## Test Gate
**Command:** `tests/lint.sh && tests/pkglist.sh && tests/build.sh`
**Result:** ✅ PASSED

Beyond the suites: 70 assertions across 25 scenarios in a scratchpad harness
that fakes `maim`/`slop`/`xclip`/`xprop`/`xrdb`/`dmenu`/`notify-send` on an
isolated `PATH`, plus a real `sxhkd` 0.6.3 parse of `sxhkdrc` (validated by a
negative control first) and real-binary flag checks for `slop`/`maim`/`xrdb`.

## Reviewer Gate
**Verdict:** READY
**Notes:** Clean on the first round — no issues raised. Everything the audit
loop caught (the startup `xclip` gate, the discarded `slop` stderr, the
late destination validation, the duplicated valid-value lists) had already
been fixed before the reviewer saw the diff.
