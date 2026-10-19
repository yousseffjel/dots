# Review — nsxiv-package

## Audit Loop
Tier Medium+ (51 files: 37 deleted with suckless/nsxiv, 14 edited, +52/-68 outside it).

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | Rule 10: nsxiv sits in extra.lst beside mpv/file-roller, the pure file handlers (deviation from the plan's desktop.lst, recorded). Rule 4's vendoring exception rewritten as history. A repo-wide grep finds no "built from suckless/nsxiv" left. 1 found, fixed: install-suckless.sh's header named desktop.lst. |
| 2 | Size/Performance | ✅ | Every edited file shrank or held (install-suckless 219, default-apps 109). 1 found, fixed: the new header line pushed the last header line out of `--help` (fixed `sed -n '2,9p'`); it now prints to the first blank line, so it cannot drift again. |
| 3 | Types/Validation | ✅ | The package was read, not assumed (rule 8): nsxiv-34_1.xbps file list, desktop file byte-identical, run_depends include libXft and libexif. Void's template uses no custom config.h; its one patch is Makefile plumbing. Existing clones: the root .gitignore covers suckless/nsxiv/ build leftovers (proven); update.sh ignores untracked files. 0 open. |
| 4 | Dependencies | ✅ | imlib2-devel and libexif-devel were nsxiv-only (no other suckless config.mk or Makefile names them), so they leave build.lst and the pacman/apt fallbacks. The imlib2 runtime still arrives through nsxiv's and feh's run_depends. ci-build-deps, void-pkgnames and pkglist pass. 0 open. |

Mutation check (scratch copies): 2/2 caught — nsxiv dropped from extra.lst (default-apps FAIL nsxiv.desktop); nsxiv back in PROGRAMS (build.sh "build failed: nsxiv").
Suite: run-tests rc=0 (93 OK) before the two audit fixes; lint ✓ after them.
Not verified: the package on the VM (installed by the install-container CI job on push).

**Audit verdict:** ✅ READY

## Reviewer Gate
**Verdict:** READY (with warning, fixed)
**Notes:** WARN: config/theme/templates/always/xresources.dcol:18 pointed at nsxiv's deleted PATCHES.md. Reworded to "reads these natively, no patch; Void's package". A repo-wide grep found no other pointer into the deleted tree. The reviewer confirmed the extra.lst placement and the existing-install behaviour (uninstall skips the old row; the /usr/local build shadows the package until the 0.5.0 migration). It changed nothing in the worktree.

## Test Gate
**Command:** tests/run-tests.sh
**Result:** ✅ PASSED (93 OK, rc 0; lint ✓)
