# nsxiv-package — nsxiv from Void's package; the colour picker stays a script
Date: 2026-10-19
Files: 52 (37 deleted with suckless/nsxiv) | Lines: +54/-8320 (+54/-70 outside the deleted tree)

## What changed
- **`suckless/nsxiv/` deleted** (upstream v34, vendored 2026-10-13 because
  Fedora did not package it).
- **`scripts/install-suckless.sh`**:
  - nsxiv is out of `PROGRAMS` and `PROGRAM_BINS`;
  - `PROGRAM_INSTALL_TARGETS` is gone (nsxiv was its only user), so the
    install line is plain `make install` again, as before 2026-10-13;
  - imlib2 and libexif are gone from the pacman/apt fallbacks and the hint;
  - `--help` now prints the header up to its first blank line instead of the
    fixed `sed -n '2,9p'`, which had cut its last line once the header grew.
- **Packages**: `nsxiv` added to `extra.lst` next to mpv, with the reason in
  the section comment. `imlib2-devel` and `libexif-devel` left `build.lst`:
  no other config.mk or Makefile uses them.
- **`tests/default-apps.sh`**: `nsxiv.desktop` maps to the `nsxiv` package.
  The vendored-provider path (suckless/<prog>/etc/<id> + PROGRAMS +
  install-desktop) and its check are removed: nsxiv was all it served.
- **`.gitignore`**: `suckless/nsxiv/`, with the reason. The deleted tree took
  its own `.gitignore` with it, so in an existing clone `git pull` would
  leave config.h, version.h, *.o and the binary showing as untracked.
  (Proved by recreating config.h: git status stays clean.)
- **Docs**:
  - CLAUDE.md: intro, tech stack, map entry removed, rule 4's vendoring
    exception rewritten as history;
  - THUNAR.md table, TESTING.md (build.sh's list), ROADMAP (the feh line,
    and the colour-picker row now records that Void packages xcolor);
  - mimeapps.list comments, and the xresources.dcol header (its pointer to
    nsxiv's PATCHES.md was dead).
- **CHANGELOG** [Unreleased] Changed: nsxiv is Void's package, and what an
  existing install keeps until the next release.
- **scope-i-void-port.md**: the open question "nsxiv 34 and xcolor" is
  answered.

## Why
User decision 2026-10-19 (AskUserQuestion): nsxiv = "Void's package
(Recommended)", xcolor = "Keep the script (Recommended)". The vendoring
existed only because Fedora lacked the package. Void's is the same program
(rule 8: read from the .xbps, not assumed):
- `nsxiv-34_1.x86_64.xbps` has /usr/bin/nsxiv, the man page, hicolor icons,
  the examples, and `/usr/share/applications/nsxiv.desktop`, byte-identical
  to the vendored `etc/nsxiv.desktop`;
- its run_depends include libXft (bar font, X resources) and libexif;
- void-packages' template builds `install-all` with no `files/config.h`
  (upstream's config.def.h), and its one patch is Makefile plumbing
  (`no-rebuild-options.patch`).

There is also a release reason: the vendored version.h came from `git
describe` of the dots repo, so the v0.5.0 tag would have made `nsxiv -v`
print the dots tag.

xcolor: `dwm-colorpicker` already works with what is installed, and its
header already said so.

## Assumptions
- Type B: `extra.lst`, not `desktop.lst` as the plan said. Rule 10's
  desktop tier is for a keybind, daemon or theming step that silently
  dies. nsxiv is a pure file handler like mpv and file-roller (extra), and
  without it GIO hands images to another app. The reviewer agreed.
- Type B: removing an existing install's `/usr/local` build (binary, man
  page, desktop file, icons, examples) and its SUCKLESS rows is left to the
  0.4.0 → 0.5.0 migration in the release slot. Until then it shadows
  `/usr/bin/nsxiv`, and both are v34. `uninstall_steps.sh` skips its row
  with "no Makefile".

## Test coverage
- `tests/run-tests.sh` rc 0 (93 OK); `tests/lint.sh` ✓. `tests/build.sh`
  built the five remaining programs.
- void-pkgnames, pkglist, ci-build-deps (17 packages), desktop-consequences
  and default-apps pass.
- Mutations on scratch copies, 2/2 caught:
  - nsxiv dropped from extra.lst → default-apps "FAIL nsxiv.desktop";
  - nsxiv back in PROGRAMS → build.sh "build failed: nsxiv".
- Not verified on the VM; the install-container CI job installs extra.lst
  on push.
- Audit READY (two findings fixed: a wrong list name in install-suckless.sh's
  header, and the --help truncation). Reviewer: WARN (a dead PATCHES.md
  pointer in xresources.dcol), fixed.

## Follow-ups
- Release slot: the 0.4.0 → 0.5.0 migration removes the `/usr/local`
  nsxiv files listed in this slot's context.md, the SUCKLESS nsxiv rows,
  and `$DOTS_DIR/suckless/nsxiv/` leftovers.
- `install-void.sh` (`sed -n '2,50p'`) and `symlinks.sh` (`'2,15p'`) print
  `--help` from a fixed line range too; not checked here.
