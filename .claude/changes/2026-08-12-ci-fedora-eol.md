# ci-fedora-eol
Date: 2026-08-12
Files: 6 | Lines: +57/-10

## What changed

- **`.github/workflows/ci.yml`: both matrices `fedora:41` -> `fedora:43`.** The
  `build-suckless` and `install-dry-run` jobs each run on
  `["fedora:latest", "<pinned>"]`; the pin had been the long-dead 41.
- **A comment in both matrices explaining what the pin is FOR** — `latest`
  catches "broken on the newest Fedora", the pin catches "only works on the
  newest Fedora" — and that it must be **bumped, not deleted**, when 43 goes EOL.
- **Three restatements of the pin corrected**: `CLAUDE.md`'s description of the
  matrix, `TESTING.md`'s `toolbox create -i …/fedora:41` example, and a
  now-false "`ci.yml` still pins `fedora:41`" line in
  `.claude/tasks/scope-c-roster-gap-fill.md`.

## Why

Queue item, opened 2026-08-12 while verifying package availability: Fedora's
active branches are 43, 44 and Rawhide(45), so the matrix had been testing
against an image two releases past EOL.

43 rather than 44 because the pin's whole purpose is to be the *oldest
supported* release — with `latest` presumably resolving to 44, the matrix now
spans 44 + 43 rather than testing 44 twice.

## Assumptions

- **Type B — `fedora:43`, not `fedora:44` or a floating alias.** GitHub Actions
  matrices need a literal, so this cannot be derived; the mitigation for a
  hardcoded moving target is the comment saying what it is for, so the next
  person bumps it rather than deleting the entry as "redundant with latest".
- **Type C — `.claude/changes/*` left untouched.** Historical mentions of
  `fedora:41` in past logs are immutable per session-protocol.md and were
  deliberately excluded from the sweep; likewise the two explanatory references
  to 41 inside the new ci.yml comment, which exist to explain the bug.

## Test coverage

Suite **12/12** plus `tests/lint.sh --strict`. Nothing in `tests/` covers CI
config, so the meaningful verification was direct:

- **`fedora:43` actually exists** — queried Docker Hub's tag list rather than
  assuming: 43, 44 and 45 all present, last updated 2026-05-28. Given this task
  exists *because* a pin went stale, confirming the replacement resolves seemed
  the minimum bar.
- **The YAML parses and both matrices resolve** to
  `['fedora:latest', 'fedora:43']`, checked with a real parser rather than by
  reading the diff.
- No `fedora:41` remains anywhere outside the immutable change logs and the two
  deliberate historical references.

**Unproven, and unprovable from here:** CI has still never been observed
running. This repo is 18 commits ahead of origin, so neither this change nor
the 2026-08-10 job rewiring has executed once. The pin is correct on paper.

## Follow-ups

- **The audit corrected the queue entry's own rationale, which I had copied
  into the code comment.** The entry said the EOL image "will eventually stop
  resolving" — but `fedora:41` is still on Docker Hub (last updated
  2025-12-04). The real failure is that an EOL release's repos move to archive
  mirrors, so `dnf` starts erroring while the image still pulls fine. The
  reviewer confirmed this matters by checking what the jobs actually run:
  `dnf install` in build-suckless, `dnf list --available` in install-dry-run.
  The comment now states the true mechanism, which is what someone debugging a
  red job will need.
- **This pin needs bumping every Fedora release.** There is no test for it and
  no way to derive it in a matrix. The comment is the whole defence; if that
  proves insufficient, a small `tests/` check comparing the pin against Fedora's
  released-versions endpoint would be the next step.
- Queue after this: `@resurrect-dir`'s `$XDG_STATE_HOME`, then the two items
  blocked on a push and on real Fedora hardware.
