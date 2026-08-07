# Review — thunar-finalization

## Audit Loop

Tier: **Medium+** (17 files, +811/-9 — `git add -N` first, since `--shortstat`
does not count untracked files).

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 0. Copy-not-symlink invariant held (`symlinks.sh` untouched); sourced-file contract matches `install-restore-theme.sh` (no own `set -e`/`SCRIPT_DIR`, no redefined log helpers); all 5 deployed paths have an uninstall route via APP rows. |
| 2 | Size/Performance | ✅ | 0. Largest file 158/250 (`install-restore-apps.sh`); largest function 42/60 (`uninstall_apps`). `uninstall-apps.sh` is its own file precisely because `uninstall_steps.sh` is at 230/250. |
| 3 | Types/Validation | ✅ | **2 found, 2 fixed.** (a) `app_is_ours` piped into `grep -qxF`; grep's early exit SIGPIPEs `cut`, and under `set -o pipefail` the pipeline returns 141 even on a match — so a file we deployed is misreported as one to leave alone. Demonstrated 5/5 on a 200k-row manifest. Rewritten as a read loop. (b) `type` used as a variable, shadowing the shell builtin — renamed `ptype`. |
| 4 | Dependencies | ✅ | 0. `xfconf` and `desktop-file-utils` are not in `packages/*.lst`, but both are hard transitive deps of `thunar` (`thunar` → `libxfce4ui` → `xfconf`) and both call sites are `command -v` guarded with a yellow-warning fallback. Recorded as a follow-up for the queued core.lst pass, not a defect here. |

**Audit verdict:** ✅ READY

Sequencing note: the size and dependency probes were run before the types
sweep, with architecture run last. Reported in order above, but not executed
strictly 1→2→3→4.

## Test Gate
**Command:** `bash tests/lint.sh && bash tests/pkglist.sh && bash tests/build.sh`
(repo convention — there is no config.yml, package.json or Makefile at the root)
**Result:** ✅ PASSED — all three exit 0. shellcheck/shfmt/markdownlint clean;
package lists valid with `xfce4-settings` added; all five suckless programs
still build (untouched by this task, run as a regression check).

Plus the task's own scratchpad harness: **44 assertions across 9 scenarios**,
0 failures, with **6 injected mutants all caught** (5/6/5/2/5/2 failing
assertions each). Not part of `tests/`, so not re-run by CI.

## Reviewer Gate
**Verdict:** READY
**Notes:** Clean first round, no issues raised. Independently confirmed the four
points it was pointed at: the no-clobber contract holds (a manifest row is only
written on actual creation, so uninstall can never remove a pre-existing file),
the xfconf pass checks property existence before setting, uca.xml and the
desktop entry are well-formed, and the doc/header updates (UNINSTALL.md
renumbering, extra.lst header, install-restore.sh header) are consistent.
