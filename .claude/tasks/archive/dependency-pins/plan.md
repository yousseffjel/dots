# Plan — dependency-pins

## Goal
Close the last HyDE-parity queue item: "what can actually be automated" for
this repo's pins. Answer: Dependabot for GitHub Actions (`uses:`) and
pre-commit hook revs; a lockstep TEST so a bot bump of a linter rev goes red
until ci.yml's mirror pin moves too; and a documented manual sweep for the
two things no ecosystem covers (the fedora:<oldest> container pin, vendored
suckless diffs).

## Scope
- .github/dependabot.yml
- tests/linter-pins.sh (renamed from tests/shellcheck-pin.sh)
- .github/workflows/ci.yml (comments only)
- tests/run-tests.sh (comment only)
- CLAUDE.md, TESTING.md, CONTRIBUTING.md, CHANGELOG.md
- .claude/**

## Allowed
## Forbidden
- scripts/
- suckless/

## Steps
1. .github/dependabot.yml: github-actions + pre-commit, monthly, grouped
2. git mv shellcheck-pin.sh -> linter-pins.sh; extend to shfmt + markdownlint
3. Update every reference to the old test name
4. CONTRIBUTING: "Keeping pins current" (what the bot does, the lockstep, the manual sweep)
5. CHANGELOG [Unreleased]; TESTING entry; verify (mutations per linter, YAML valid)

## Out of scope
- Renovate (a regex manager could cover ci.yml env vars, but it is a new third-party app; not requested)

## Risks
- Dependabot `pre-commit` ecosystem support — confirmed on GitHub's supported-ecosystems page 2026-09-28
