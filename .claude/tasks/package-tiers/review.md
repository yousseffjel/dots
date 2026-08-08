# Review — package-tiers

## Audit Loop
| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 1 found, 1 fixed. No Forbidden path touched (`config/`, `suckless/`, `uninstall*`, `symlinks.sh`, `.claude/changes/` all clean). **Fixed:** `CLAUDE.md` rule 10 stated the inline-array ban absolutely, while `install_deps()` keeps inline arrays for its pacman and apt branches — a `.lst` holds one distro's names and those are different names for the same libraries. Rule 10 now records the exception explicitly rather than leaving code and doc disagreeing. `install-pkg-tiers.sh` defining no colour helpers is correct: it is sourced and inherits, same as `install-restore-theme.sh` and `install-session.sh`. |
| 2 | Size/Performance | ✅ | 2 found, 2 fixed. All files under the 250 cap (`install-pkg.sh` 181, `install-pkg-tiers.sh` 117, `install-suckless.sh` 195, `pkglist.sh` 115, `desktop-consequences.sh` 121) and all functions under 60 (largest: `install_tier` 34). **Fixed:** two dangling cross-references — `install-suckless.sh` and `tests/pkglist.sh` both pointed at `read_pkg_list() in scripts/install-pkg.sh`, which moved to `install-pkg-tiers.sh` during the step-3 split. `read_pkg_list` now has three copies plus an inline one in `ci.yml`; kept per CLAUDE.md rule 2 (per-script helpers over a shared sourced file), with each copy naming the canonical one. |
| 3 | Types/Validation | ✅ | 0 found. `set -euo pipefail` in every standalone script; `install-pkg-tiers.sh` documents that it inherits it. No `\| grep -q` or `\| head` introduced (the `pipefail` SIGPIPE trap). The one unguarded `overlap="$(comm ...)"` is the pre-existing line, and the new empty-list check runs before it so the degenerate input is caught first. `DNF_ERR="$(...)" \|\| return 1` is guarded. `${CONSEQUENCE[$pkg]:-...}` is safe under `set -u` and was exercised live (RUN E). |
| 4 | Dependencies | ✅ | 0 found. All five functions `install-pkg.sh` calls resolve in the file it sources; `DRY_RUN` (36), `PACKAGES_DIR` (28) and `SUDO` (62) are all set before the `source` at line 74, as are `global_fn.sh` (29) and the colour helpers (31–34). |

**Audit verdict:** ✅ READY

## Test Gate
**Command:** `for t in tests/*.sh; do bash "$t"; done`
**Result:** ✅ PASSED — 8/8 (autostart-daemons, build, desktop-consequences,
fastfetch-template, lint, picom-lockstep, pkglist, starship-template).
`build.sh` compiled all five suckless programs against this branch's sources;
`pkglist.sh` discovered all four tiers by glob and checked 6 pairs;
`desktop-consequences.sh` confirmed all 26 entries annotated. dunst held
PID 6329 throughout, so the theming-engine tests stayed sandboxed.

## Reviewer Gate
**Verdict:** READY
**Notes:** Clean first round. Probed specifically at the four risks named in the
brief and cleared each: no packages silently dropped in the 96 -> 102 re-tiering;
the consequence-comment parse is robust; toolchain sequencing survives `core.lst`
dropping to `git`+`zsh` (nothing between `install-pkg.sh` and `install-suckless.sh`
needs the compiler, and `install-suckless.sh` installs `build.lst` itself); every
piece of caller state `install-pkg-tiers.sh` uses is set before the `source` line.
Also confirmed the CI validation loop is glob-based and covers `build.lst`, and ran
a live simulated install to check the failure summary matches the documented
behaviour.
