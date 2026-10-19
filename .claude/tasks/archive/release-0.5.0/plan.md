# Plan — release-0.5.0

## Goal
Cut 0.5.0 (user 2026-10-19: "0.5.0", the last of "4 + 5 + 6"). The
migration's one job is to remove the nsxiv build that 0.4.0 vendored under
/usr/local (now Void's package) and its manifest rows, plus the repo's
suckless/nsxiv leftovers. Header refresh is NOT needed: every build already
does it (install-suckless-headers.sh, 2026-10-12).

## Scope
- scripts/migrations/0.4.0-to-0.5.0.sh
- tests/**
- VERSION, CHANGELOG.md, README.md, docs/**, CLAUDE.md

## Forbidden
- .claude/tasks/MASTER_PLAN.md

## Steps
1. Migration: if the manifest has SUCKLESS nsxiv rows, take the prefix from the …/bin/nsxiv row and remove exactly what the vendored `make uninstall` removed (sudo only when the prefix is not writable). Drop those rows. Delete $DOTS_DIR/suckless/nsxiv/ unless its config.h was edited (then keep it and say so). A no-op otherwise; idempotent.
2. Test tests/migration-0.5.0.sh: sandbox prefix + XDG; rows → files gone, rows gone, other rows kept; edited config.h kept; no rows → nothing touched; re-run no-op; never a real /usr/local.
3. Release: CHANGELOG [0.5.0] - 2026-10-19 + empty [Unreleased]; VERSION 0.5.0; CLAUDE.md map line for migrations if needed.
4. Lint, run-tests, mutations on scratch copies.
5. After merge: local tag v0.5.0 on main (not pushed).

## Out of scope
- Pushing main or the tag.

## Risks
- Deleting something not ours: only paths derived from our own manifest row, only the files make uninstall named; the row path must end in /bin/nsxiv.
- A migration that fails without sudo blocks the run: say so clearly; a re-run converges.
