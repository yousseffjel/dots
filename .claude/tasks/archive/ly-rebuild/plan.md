# Plan — ly-rebuild (Medium)

## Goal
A raised LY_VERSION/LY_COMMIT reaches an existing install: rebuild, keep
/etc/ly/config.ini, drop files the new version no longer ships.

## Scope
scripts/install-services-ly.sh, scripts/install-services-ly-place.sh (new),
tests/ly-build.sh (or a split tests/ly-rebuild.sh), docs/THEMING.md,
CLAUDE.md map line, CHANGELOG [Unreleased].

## Steps
1. Record: `META ly_build v<version> <commit>` after a successful place.
   No record + LYBUILD rows = the first pin (1.4.1 afb1dc6, the only one
   ever shipped since f6e4948), recorded on that run without a rebuild.
2. ly_install: same record → "ok"; different → rebuild through the same
   checks; a failed rebuild leaves the old install untouched.
3. ly_place (moved to -place.sh): write via tmp + `mv -fT` (a running ly
   makes cp in place fail with ETXTBSY); on a rebuild keep an existing
   /etc/ly/config.ini (themed or edited) and say so.
4. ly_prune: old LYBUILD paths the new stage lacks are removed with their
   rows (config.ini never). Never restart ly: say the new one runs from
   the next boot.
5. Tests: record written; up-to-date no-op; no-record backfill; bump →
   rebuild, config.ini kept, stale file + row gone, new file added;
   failed rebuild keeps everything; dry-run. Mutations on copies.
6. Docs + CHANGELOG; lint, run-tests.

## Out of scope
Migrating config.ini keys across ly versions (whoever bumps the pin checks
ly-theme.sh's keys, as the 1.4.1 comment already says).
