# Plan — manifest-has-path

## Goal
Extract `manifest_has_path <TAG> <path>` into `global_fn.sh` and collapse the
three byte-identical read loops onto it. Closes queue item 2; subsumes item 1
by taking `install-restore-theme.sh` from 248 to ~218, unblocking roster-gap-fill.

## Scope
- scripts/global_fn.sh
- scripts/install-restore-theme.sh
- scripts/install-restore-apps.sh
- tests/manifest-has-path.sh

## Allowed
- scripts/global_fn.sh
- scripts/install-restore-theme.sh
- scripts/install-restore-apps.sh
- tests/manifest-has-path.sh
- CLAUDE.md

## Forbidden
- scripts/uninstall.sh
- scripts/version.sh
- scripts/migrate.sh

## Steps
1. Add `manifest_has_path` to global_fn.sh, carrying the pipefail/SIGPIPE rationale once.
2. Rewire `theme_is_ours` + `theme_backed_up` onto it in install-restore-theme.sh.
3. Rewire `app_is_ours` onto it in install-restore-apps.sh.
4. Verify the other 9 global_fn.sh consumers — no collision, no sourcing-order change.
5. Add tests/manifest-has-path.sh — mutant proving the old `| grep -qxF` shape fails.
6. Re-measure: install-restore-theme.sh < 250, every function < 60.
7. Run the full tests/ suite + `tests/lint.sh --strict`.

## Out of scope
- Splitting install-restore-theme.sh (item 1 subsumed, not performed).
- xsettingsd / roster work — separate slot.

## Risks
- global_fn.sh has 12 consumers — collision/arity slip breaks uninstall. Mitigation: grep shows zero prior `manifest_has_path`; dry-run version.sh + uninstall.sh sandboxed.
- Manifest lives under `$XDG_STATE_HOME` — a HOME-only sandbox writes the REAL manifest. Mitigation: set all four XDG vars.
- The pipefail rationale is load-bearing; losing it invites the bug back. Mitigation: comment moves once, test encodes it.
