# Plan — live-docs

## Goal
Scope J, J-5: document the live-ISO installer for users (docs page, README, an example answers file, a full `--help`), correct CLAUDE.md where it contradicts the live path, guard the documented answer keys against the code with a test, and verify the whole thing with a VM matrix: {UEFI, BIOS} × {plain, LUKS}.

## Scope
- docs/**
- README.md
- CHANGELOG.md
- CLAUDE.md
- scripts/install-live.sh
- tests/live-docs.sh
- scripts/theme/ly-theme.sh
- tests/ly-theme.sh

## Allowed

## Forbidden
- .claude/tasks/MASTER_PLAN.md

## Steps
1. `--help` prints the header's full usage text, read from the script itself so the two cannot drift.
2. docs/live-answers.example: every key in LIVE_ANSWER_KEYS, commented, with placeholder hashes.
3. docs/LIVE-INSTALL.md, modelled on HARDWARE.md/UNINSTALL.md: quick start, flags, answers keys table, disk layout, LUKS, re-runs, caveats, testing.
4. tests/live-docs.sh: the doc's key table equals LIVE_ANSWER_KEYS, the example parses with the shipped parser, and every flag in the case statement appears in --help and in the doc.
5. README (drop the stale port banner, add a live-install section), CHANGELOG [Unreleased] line, CLAUDE.md (PORT IN PROGRESS paragraph, entry points, :83, :224).
6. VM matrix from the ISO, all 4 combinations (`dots-live-j3`/`-j3b`): booted to ly, `dots doctor` passing; record results in progress.md.
6b. (deviation 2026-10-19, user's choice) ly first-boot login: ly-theme.sh also writes `default_input = password`; originals file gains keys added later.
7. Lint (tests/lint.sh), the live tests, the run-tests suite.

## Out of scope
- A full Fedora-era rewrite of CLAUDE.md beyond the live-path spots.
- The open J-4 bug (after `timeout -s INT`, install-void.sh carries on with sudo revoked): becomes a follow-up.
- A LY_VERSION bump never rebuilds an existing install (ly_install skips on any LYBUILD row): follow-up.
- The MASTER_PLAN J-4/J-5 fold: main-side, post-merge chore(records).

## Risks
- The doc drifts from the code: step 4's test.
- The VM matrix is slow or flaky (serial console driving): one combination per run, logged as it goes.
