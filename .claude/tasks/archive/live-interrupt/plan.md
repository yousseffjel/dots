# Plan — live-interrupt

## Goal
Ctrl-C (or TERM) stops the whole install. From the live ISO, install-live.sh
must stop every process still running inside the target before it removes
the temporary sudo rule, so install-void.sh can never carry on orphaned and
sudo-less (seen in J-4). Run directly on an installed Void system,
install-void.sh must stop on Ctrl-C instead of treating the interrupted xbps
transaction as an ordinary failure and retrying package by package.

## Scope
- scripts/install-*.sh
- tests/**
- docs/LIVE-INSTALL.md
- CHANGELOG.md
- CLAUDE.md

## Allowed

## Forbidden
- .claude/tasks/MASTER_PLAN.md

## Steps
1. Reproduce: a direct install-void.sh run on the VM, Ctrl-C mid-transaction; record what carries on.
2. install-live.sh: the dots-stage exit path stops everything rooted in the target (live_dots_release), THEN revokes; INT/TERM say "interrupted".
3. install-void.sh + stages: an interrupt ends the run (exit 130/143), never "retry one at a time" — fix where step 1 shows it continues.
4. Tests: release-before-revoke on an interrupt (fake /proc only), and the stage stop (fake xbps killed by INT).
5. Docs: LIVE-INSTALL.md "Running it again", CHANGELOG Fixed line, CLAUDE.md map line if it changes.
6. VM: live run interrupted with a real Ctrl-C on the serial console during install-void.sh; nothing left in the target, rule gone, re-run converges.
7. Lint, the live tests, run-tests.

## Out of scope
- Other MASTER_PLAN items (nsxiv, CLAUDE.md Fedora text, the 0.5.0 release): their own slots.

## Risks
- A kill loop scanning the real /proc in a test — LIVE_PROC fake in every caller (memory).
- Bash defers a trap until the foreground child exits — prove with a real Ctrl-C, not only timeout.
