# Plan — ci-fedora-eol

## Goal
`.github/workflows/ci.yml` pins `fedora:41` in two matrices. Fedora 41 and 42
are both EOL — the active branches are 43, 44 and Rawhide — so that image will
eventually stop resolving and take both jobs with it. Replace it with the
oldest *supported* release and fix the three places that restate the pin.

## Scope
- .github/workflows/ci.yml
- CLAUDE.md
- TESTING.md
- .claude/tasks/scope-c-roster-gap-fill.md

## Allowed

## Forbidden
- tests/
- scripts/

## Steps
1. `ci.yml`: both matrices `fedora:41` -> `fedora:43`, with a comment saying
   WHY an older release is pinned alongside `latest` and what to do when 43 EOLs.
2. `CLAUDE.md`, `TESTING.md` (toolbox example), and the scope file's now-false
   "still pins `fedora:41`" note.
3. Verify no `fedora:41` remains outside the immutable change logs; check the
   YAML still parses.

## Out of scope
- Adding or removing matrix entries beyond replacing the EOL one.
- Anything that would need CI to actually run to verify.

## Risks
- The real fix is a moving target: 43 will EOL too. Mitigation is a comment
  saying what the entry is FOR, so the next person updates rather than deletes.
- Cannot be verified here — no `act`, no runner, and the repo is unpushed. The
  change log must say the pin is unproven until a push.
- `.claude/changes/*` is immutable; historical mentions of `fedora:41` there
  stay as they are and must not be swept up by a bulk replace.
