# Review — install-uninstall-symmetry

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 2 fixed (beyond the planned mimeinfo fix): THEMEBACKUP originals never restored (row lacked the backup path) -> 4th field + uninstall_theme_backups; uninstall.sh / uninstall-apps.sh comments claimed a stale 230-line figure. Harness: one mutant was caught for the wrong reason (empty `then` = syntax error) — re-run with a no-op, caught for the right reason. |
| 2 | Size/Performance | ✅ | 0. uninstall_steps.sh 235 -> 196; uninstall-theme.sh 94; test 201 + lib 73; longest function 35. |
| 3 | Types/Validation | ✅ | 4 fixed: SC2015 x3 (A && B || C) -> if/else; one shfmt diff. |
| 4 | Dependencies | ✅ | 0. Only uninstall.sh sources the uninstall_* files; docs reference functions by name, still valid. |

Verification: both scenarios green; 6/6 sandboxed-repo mutations CAUGHT for the right reason (unclaimed cache, no refresh guard, no backup path, unclaimed APP file, CONFIG backup not restored, backup step dropped). Full run-tests (19 run) + lint green; real manifest untouched.

**Audit verdict:** ✅ READY

## Reviewer Gate
**Verdict:** READY (with warning) -> addressed
**Notes:** WARN — uninstall_theme_backups replaces the current file without a diff, so a post-install hand edit is discarded. Addressed by verification + disclosure rather than a diff: every THEMEBACKUP target is a theming-engine template target (checked each .dcol's line 1), rewritten wholesale on every wallpaper change, so such edits never persisted. The prompt now says the current copies are replaced and why; the header records the reasoning. Reviewer otherwise independently confirmed both fixes load-bearing, legacy 3-field rows handled, manifest consumers compatible.
