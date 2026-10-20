# dots — Current Audit State

## Current Scope
Personal Fedora-only dotfiles + dwm/X11 desktop bootstrap repo. The
uninstall/versioning/migrations subsystem (below) and the CI/tooling setup
both landed 2026-08-05, concurrently, in the same working tree — see each
thread's dated log for the full collision account (mutually surfaced and
handled without data loss on either side). See recent dated logs in this
directory for the running history.
Since 2026-10-15 the target is Void Linux glibc (scope I): "Fedora-only"
above is history, kept verbatim from the pre-rotation snapshot.

## History Sources
- `.claude/changes/YYYY-MM-DD-*.md` — authoritative dated logs

## 2026-10-19 — nsxiv-package: nsxiv from Void's package (fast-forward)

- **`nsxiv-package`** (`30e9120`, log `2026-10-19-nsxiv-package.md`). User
  decisions: nsxiv comes from Void's package, and xcolor stays a script.
  - `suckless/nsxiv` deleted. nsxiv is out of `PROGRAMS`/`PROGRAM_BINS`, and
    `PROGRAM_INSTALL_TARGETS` is removed. `nsxiv` is in `extra.lst`;
    `imlib2-devel`/`libexif-devel` left `build.lst`.
  - `tests/default-apps.sh` maps `nsxiv.desktop` to the package.
  - The root `.gitignore` covers the old tree's build leftovers in existing
    clones. `install-suckless.sh --help` no longer truncates.
  - The package was verified from its .xbps and its void-packages template:
    the same v34, the same desktop file, Xft and libexif.
  - Suite 93 OK, lint ✓, 2/2 mutants, audit READY, reviewer WARN (a dead
    pointer, fixed).
- **Queued:** the 0.5.0 migration removes the `/usr/local` nsxiv build and
  its manifest rows.

## 2026-10-19 — claude-md-void: CLAUDE.md Fedora cleanup (fast-forward)

- **`claude-md-void`** (`45e575d`, log `2026-10-19-claude-md-void.md`).
  User item 6. Statements of current behaviour reconciled with the Void
  scripts; Fedora kept as marked history. Every new fact was checked
  against the repo or the .xbps. lint ✓, suite 93 OK, audit READY,
  reviewer READY.
- **Queued:** Void's `gnome-themes-extra(-gtk)` vs the vendored shim and
  the gtk2 template (a decision), and TESTING.md's Fedora sections. The
  0.5.0 release item is corrected: headers are already refreshed on every
  build, so the migration only removes the old nsxiv build.

## 2026-10-19 — release-0.5.0: cut 0.5.0 (fast-forward)

- **`release-0.5.0`** (`868a481`, log `2026-10-19-release-0.5.0.md`). User
  item 3, last part. VERSION 0.5.0, CHANGELOG `[0.5.0] - 2026-10-19` (two
  entries corrected for release), and the 0.4.0 → 0.5.0 migration: it
  removes the `/usr/local` nsxiv build only when a manifest row records it,
  drops the rows, and deletes unedited `suckless/nsxiv/` leftovers (an
  edited config.h is kept and named). sudo only for an unwritable prefix.
- `tests/migration-0.5.0.sh` (sandboxed, fake sudo); 7/7 mutants; suite
  94 OK; lint ✓; audit READY; reviewer READY.
- Local tag `v0.5.0` on main. Nothing pushed.

## 2026-10-19 — testing-void + ly-rebuild (fast-forward)

- **`testing-void`** (`863380a`, log `2026-10-19-testing-void.md`). User
  items 1 + 2. The GTK3 shim and gtk2 template stay by decision (facts read
  from the gnome-themes-extra 3.28_4 .xbps files); TESTING.md's Fedora-era
  statements reconciled (base-files 0.146 `usr/sbin -> bin`). Suite 94 OK,
  reviewer READY.
- **`ly-rebuild`** (`bb86190`, log `2026-10-19-ly-rebuild.md`). User item 3.
  `scripts/install-services-ly-place.sh`; a raised pin rebuilds, keeps
  config.ini, prunes stale paths, never restarts ly. 12 new checks in
  tests/ly-build.sh, 10/10 mutants, suite 94 OK, reviewer READY.

## 2026-10-20 — suite-host-hermetic (fast-forward)

- **`suite-host-hermetic`** (`324b6d6`, log `2026-10-20-suite-host-hermetic.md`).
  The suite failed 2 checks on the Arch dev host (CI green): dwm-display's
  tests reached the real autorandr, doctor's GTK3 case read /usr/share/themes.
  Sealed PATH + sandboxed XDG_DATA_DIRS. `--help` of install-void.sh and
  symlinks.sh prints the whole header (install-void.sh before its log tee);
  new tests/help-header.sh. Suite 95 OK on the host, 6/6 mutants, lint ✓,
  audit READY, reviewer READY. Nothing pushed.

## 2026-10-20 — CURRENT_AUDIT.md rotated

- Pre-rotation snapshot: `.claude/changes/CURRENT_AUDIT-2026-10-20.md`
  (2531 lines, every entry from 2026-08-05 on).
- Older entries are preserved there; this file now keeps only the
  trailing 5, oldest first as before.
- Same commit: the thirteen 2026-10-05 logs moved to `archive/` (14-day sweep).
