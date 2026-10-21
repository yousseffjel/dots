# Plan — uninstall-dryrun-preview

## Goal
`dots uninstall --dry-run` is documented as "preview every action", but every
category is behind a y/N prompt first: without a terminal (or answering N)
it prints "skipped …" for all of them and previews nothing (Void VM,
2026-10-20). And uninstall_state ends on `[[ -n "$keep_path" ]] && echo`,
so "remove state: y / keep a copy of the log: N" exits 1 before
"✓ uninstall complete".

## Scope
- scripts/global_fn.sh
- scripts/uninstall_steps.sh
- scripts/uninstall.sh
- tests/uninstall-dry-run.sh
- CHANGELOG.md

## Allowed

## Forbidden

## Steps
1. tests/uninstall-dry-run.sh: sandbox restore (tests/lib/install-symmetry.sh),
   then `uninstall.sh --dry-run </dev/null`: exit 0, HOME byte-identical,
   sentinels silent, dconf + flatpak untouched, a "(dry-run) would" line and
   no "skipped"/"kept" line. Plus uninstall_state with y / N returns 0.
2. global_fn.sh confirm(): under DRY_RUN=1 answer yes without reading (the
   state step already skips its prompt in a dry run).
3. uninstall_steps.sh: uninstall_state's trailing `&&` becomes an if.
4. uninstall.sh header: "dnf packages" -> xbps.
5. CHANGELOG lines.

## Out of scope
- Rewording any section's own dry-run messages.

## Risks
- A confirmed section that ignores DRY_RUN would now act in a dry run — the
  sandbox test (snapshot + sentinels) and the per-section DRY_RUN tests cover it.
