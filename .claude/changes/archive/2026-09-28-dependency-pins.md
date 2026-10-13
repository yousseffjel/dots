# dependency-pins
Date: 2026-09-28
Files: 9 + task folder | Lines: ~+150/-100 (including a rename)

## What changed
- **`.github/dependabot.yml`**: monthly updates for `github-actions` (all
  `uses:`, grouped into one PR) and `pre-commit` (hook `rev:`s), with the
  `ci` commit prefix. Its header says what it cannot cover and why.
- **`tests/shellcheck-pin.sh` -> `tests/linter-pins.sh`** (`git mv`), extended
  from shellcheck alone to shfmt and markdownlint. It is now the gate for
  Dependabot's pre-commit PRs. The bot cannot edit `ci.yml`'s env-block
  versions, so a linter bump stays red until its twin moves on the same
  branch. Packaging revisions (`v0.11.0.1`, `v3.13.1-1`) and YAML quotes are
  normalized away.
- `CONTRIBUTING.md` "Keeping pins current" covers the bot, the lockstep, and
  the manual sweep for the two pins no ecosystem reads: the oldest-supported
  `fedora:` matrix image and the vendored suckless sources.
- References updated in `ci.yml` (the comment now covers all three pins),
  `tests/run-tests.sh`, TESTING.md, and CLAUDE.md (an appended note, not an
  edit of the 2026-08-14 sentence). There is also a CHANGELOG line.

## Why
This was the last HyDE-parity queue item. The entry itself asked for "what
can actually be automated here" to be scoped before adopting a tool. The
answer is Dependabot (no new third-party app) plus a test that turns its one
blind spot, the ci.yml mirrors, into a red PR instead of silent drift.

## Assumptions
- Type B: Dependabot over Renovate. Renovate's regex managers could bump
  `ci.yml`'s env vars too, but it is a third-party app and was not requested.
  The lockstep test covers the same gap.
- Type B: monthly, not weekly, for a personal repo.
- `pre-commit` support was confirmed on GitHub's supported-ecosystems page
  (2026-09-28): version updates only. `actions/checkout@v7` and
  `actions/cache@v6.1.0` were confirmed to exist on their release pages. The
  Fedora schedule/EOL pages sit behind a bot wall and could not be fetched,
  so CONTRIBUTING links the docs root.

## Test coverage
- 5/5 sandboxed mutations were CAUGHT: a bot-style bump of each of the three
  hooks, a renamed ci key, and a renamed hook repo. Controls: a
  packaging-only rev bump passes, a quoted-but-equal rev passes, and a quoted
  real bump fails.
- `lint.sh` and `run-tests.sh` pass. `dependabot.yml` parses.
- Reviewer: WARN (quoted revs would false-fail), fixed before commit.

## Follow-ups
- The first real Dependabot run happens only once pushed. Watch that the
  `pre-commit` ecosystem opens PRs as documented.
