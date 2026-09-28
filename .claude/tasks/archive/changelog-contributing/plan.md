# Plan — changelog-contributing

## Goal
Close the HyDE-parity queue item "CHANGELOG.md + CONTRIBUTING.md". Release
boundary chosen by the user 2026-09-28: everything to date is 0.1.0 (never
tagged, VERSION unchanged), and [Unreleased] starts now. Guard the one fact
that can drift: VERSION vs the newest released CHANGELOG heading.

## Scope
- CHANGELOG.md
- CONTRIBUTING.md
- README.md
- tests/changelog-version.sh
- TESTING.md
- .markdownlint.yaml
- tests/tmux-xdg-paths.sh (mode only)
- CLAUDE.md
- .claude/**

## Allowed
## Forbidden
- VERSION
- scripts/

## Steps
1. CHANGELOG.md (Keep a Changelog; 0.1.0 grouped summary + [Unreleased] with today's slots)
2. CONTRIBUTING.md (workflow, conventions as pointers to CLAUDE.md rules/TESTING.md, release steps)
3. README.md: link both (Development + Versioning), no restated content
4. tests/changelog-version.sh: newest released heading == VERSION, [Unreleased] present above it
5. TESTING.md entry; verify markdownlint, mutations (VERSION bump, missing Unreleased)

## Out of scope
- Tagging v0.1.0 (user's call)
- VERSION bump

## Risks
- Restating rules in CONTRIBUTING creates a drift site — point at rule numbers/files instead of copying lists
