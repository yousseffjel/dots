# Plan — package-tiers

## Goal
Three tiers replacing core/extra — core (installer's next step breaks;
hard-fail), desktop (session unusable; loud, never aborts), extra — plus
`packages/build.lst` for the suckless build deps, closing rule 10 at
`install-suckless.sh:84`.

## Scope
- packages/*.lst
- scripts/install-{pkg,suckless,fedora}.sh
- tests/*.sh
- .github/workflows/ci.yml
- *.md, docs/*.md

## Forbidden
- config/
- suckless/
- scripts/uninstall*.sh
- scripts/symlinks.sh
- .claude/changes/

## Steps
1. `packages/build.lst` + `install-suckless.sh` reads it (drops inline array).
2. Classify the roster into core/desktop/extra; rewrite all three headers.
3. `install-pkg.sh`: tier-driven loop + end-of-run failure summary.
4. `tests/pkglist.sh`: glob every list, all-pairs overlap, non-empty.
5. New test: every desktop.lst package carries a consequence note.
6. `ci.yml` dry-run validation over all four lists.
7. Docs: CLAUDE.md map/rule 10/pending, TESTING.md, THUNAR.md, ROADMAP.md.

## Out of scope
- Verifying names against live dnf (no dnf on this Arch host).
- uninstall.sh — PACKAGE manifest rows are tier-agnostic.

## Risks
- An unverified name in core turns a degraded install into no install —
  mitigation: core stays minimal, promotions land in desktop.
- Four lists = four drift surfaces — mitigation: step 4 globs, never names.
- Step 5 needs a per-package consequence source; see context.md.
