# Plan — update-stale-wording

## Goal
`dots update` printed "the last finished install ran from no finished install recorded" when no
`complete` stamp exists (seen on the VM, 2026-10-13). Say "no finished install is recorded yet"
in that case; keep the existing sentence when a stamp exists.

## Scope
- scripts/update.sh
- tests/dots-update.sh
- .claude/changes/*

## Allowed
## Forbidden

## Steps
1. stale_reason: branch on an empty stamp; two readable sentences.
2. tests/dots-update.sh: expect the new wording in the missing-manifest and interrupted cases.
3. Lint + suite.

## Out of scope
- Any other update.sh message.

## Risks
- A third caller of stale_reason reading oddly — check every call site.
