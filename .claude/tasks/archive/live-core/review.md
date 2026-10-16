# Review — live-core

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 1 fixed: install-live.sh header now says it writes no manifest rows |
| 2 | Size/Performance | ✅ | 0 (max file 203 lines, max function 42) |
| 3 | Types/Validation | ✅ | 1 fixed: the closing hint now says git is needed in the new system |
| 4 | Dependencies | ✅ | 1 fixed: the real-host lsblk check skips /dev/root (ubuntu runner) |

**Audit verdict:** ✅ READY (lint ✓, suite 84 OK, exit 0; VM run UEFI + BIOS passed)

## Reviewer Gate
**Verdict:** READY
**Notes:** Fixed before the gate: plain chpasswd silently set no password (found on the BIOS VM; now -c SHA512 plus a shadow read-back), dry-run 'ok' lines, the no-git hint, the /dev/root runner skip.
