# Review — hardware-drivers

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | fixed | 2: UNINSTALL.md 5d + uninstall-repos.sh header said ffmpeg was the only swap |
| 2 | Size/Performance | pass | 0 (max file 154 lines, all functions < 60; one repoquery per failed fw file accepted) |
| 3 | Types/Validation | fixed | 1: dnf repoquery failure read as "no package ships it" — now reported, test added |
| 4 | Dependencies | pass | 0 (acyclic sources; od/journalctl/awk/rpm/dnf all base Fedora) |

Type-B noted: per-hardware package names are inline (drivers-gpu.sh), following
install-pkg-repos.sh's precedent; rule 10 targets lists, not conditionals.

**Audit verdict:** ✅ READY

## Reviewer Gate
**Verdict:** READY
**Notes:** No issues raised by the reviewer. Issues fixed earlier in the round:
VM run (unreadable kernel log reported as clean), audit (dnf failure read as
"no package ships it"; stale swap wording in UNINSTALL.md / uninstall-repos.sh).

## Test Gate
**Command:** tests/run-tests.sh
**Result:** ✅ PASSED (63 test scripts OK, incl. drivers.sh, pkg-repos.sh, doctor.sh)
