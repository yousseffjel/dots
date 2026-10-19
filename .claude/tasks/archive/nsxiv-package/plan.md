# Plan — nsxiv-package

## Goal
nsxiv comes from Void's package, not the vendored build in suckless/nsxiv
(user 2026-10-19, "Void's package"). The package is upstream v34 with the
default config: the same version, desktop file, Xft bar, X resources and
EXIF support. The colour picker stays a script though Void packages xcolor
(user 2026-10-19, "Keep the script"); record both decisions.

## Scope
- suckless/nsxiv/**
- scripts/install-suckless.sh, scripts/install-pkg.sh
- packages/*.lst
- tests/**
- config/mimeapps.list
- docs/**, CLAUDE.md, CHANGELOG.md, ROADMAP.md, TESTING.md
- .claude/tasks/scope-i-void-port.md

## Forbidden
- .claude/tasks/MASTER_PLAN.md

## Steps
1. Delete suckless/nsxiv. Take nsxiv out of PROGRAMS/PROGRAM_BINS and drop PROGRAM_INSTALL_TARGETS (nsxiv was its only user); fix the comments and the pacman/apt fallbacks.
2. Packages: add nsxiv to desktop.lst with consequence text; drop imlib2-devel and libexif-devel from build.lst (nsxiv-only); fix the extra.lst note.
3. Tests: default-apps.sh maps nsxiv.desktop to the nsxiv package (drop the vendored-provider path); check build.sh and the pkgname tests still hold.
4. Docs: CLAUDE.md (intro, tech stack, map, rule 4's vendoring exception), THUNAR.md, TESTING.md, ROADMAP.md, mimeapps.list comments, CHANGELOG Changed; scope-i open question answered (nsxiv package, xcolor script).
5. Lint, run-tests, mutation check on scratch copies.

## Out of scope
- Removing an existing install's /usr/local nsxiv build and its SUCKLESS rows: the 0.4.0→0.5.0 migration in the release slot. Until then /usr/local/bin/nsxiv shadows /usr/bin/nsxiv; both are v34.
- The CLAUDE.md Fedora cleanup and the release: their own slots.

## Risks
- uninstall_steps.sh skips SUCKLESS rows whose suckless/<prog> has no Makefile, so an old install's nsxiv files stay until the migration removes them. Say so in the CHANGELOG.
- A stale "built from suckless/nsxiv" line left in a doc (enumeration drift): finish with a repo-wide grep.
