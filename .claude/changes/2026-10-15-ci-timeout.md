# ci-timeout — install-container timeout 90 → 20 minutes

## What changed
- `.github/workflows/install-container.yml`: `timeout-minutes: 90` → `20`; both
  comments rewritten with measured figures.
- `CLAUDE.md`: the two "~30 min per leg" mentions → "~3 min".
- `CHANGELOG.md`: [Unreleased] Changed line.

## Why
Since dnf-speed (one transaction per tier) a leg takes ~3 minutes, so a hung
run held a runner for 90 minutes before failing.

## Key Technical Decisions
- 20 minutes: ~6x the slowest measured leg and above the ~8-minute
  per-package CI legs, so a slow mirror does not fail the job.

## Assumptions Made
- Type B: run a1f8054's legs (2:38 fedora:43, 3:25 fedora:latest, from the
  public GitHub API) are representative; a cold image pull or slow mirror
  stays well under 20 minutes.

## Test coverage
- YAML parses; `tests/lint.sh` passes. The value itself is proven only by the
  next install-container run.
- Reviewer WARN (comments gave ~30 and ~8 for per-package runs without
  saying which was local and which CI) fixed: both comments now name the source.

## Follow-ups
- Check the next install-container run passes inside 20 minutes after push.
