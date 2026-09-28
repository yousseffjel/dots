# Review — dwm-bin-tests

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 0. tests/lib precedent; fakes shared via sealed-path.sh, colour helpers stay per-script (rule 2). No config/dwm/bin edits. |
| 2 | Size/Performance | ✅ | 0. 208/142/167/141 + lib 35 lines; helpers <= 20. |
| 3 | Types/Validation | ✅ | 14 fixed: SC2015 x11; dmenu fake called unsealed `cat` (drafting); 2 weak assertions exposed by surviving mutants (brightness verbose-only failure; screenshot stop-at-validation + dest typo). |
| 4 | Dependencies | ✅ | 0. Sealed tools all exist on ubuntu-latest. |

Verification: 17/17 mutants CAUGHT on sandboxed copies after strengthening (each validation mutant re-applied by exact line after a range-sed hit two sites and a `$` grep matched nothing). Full run-tests + lint green.

**Audit verdict:** ✅ READY

## Reviewer Gate
**Verdict:** READY (with warning) -> fixed
**Notes:** WARN — the temp-file-absence clause in the screenshot typo-mode assertion was dead (the script's EXIT trap deletes its temp on every path). Removed; the comment now credits the real discriminator (no 'empty file' error), and the mode-validation mutant was re-verified CAUGHT after the edit. Reviewer independently confirmed fake formats (xrandr --verbose, xprop) against the real tools and caught an extra MIN-clamp mutant.
