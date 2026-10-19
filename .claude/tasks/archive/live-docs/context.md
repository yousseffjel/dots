# Context — live-docs

## Background
Scope J sub-task J-5 (`.claude/tasks/scope-j-live-install.md` row J-5): docs plus the full {UEFI,BIOS}×{plain,LUKS} matrix. J-1..J-4 done 2026-10-16.

## Prior Decisions
- Locked decisions in scope-j-live-install.md (disk layout table, LUKS2 argon2id, no crypttab, kernel args in GRUB_CMDLINE_LINUX).
- J-2 deferred its BIOS run to this matrix.

## References
- scripts/install-live.sh:1-47 (header usage), :90 (`--help`, one line only)
- scripts/install-live-answers.sh:10-37 (spec, LIVE_ANSWER_KEYS; first six required)
- scripts/install-live-validate.sh (validators)
- tests/xinitrc-report.sh:148 (only existing doc-vs-code test, the model for step 4)
- docs/HARDWARE.md, docs/UNINSTALL.md (page model)
- Logs: .claude/changes/2026-10-16-live-{core,dots,disk,luks}.md

## Notes
- Caveats to document: dhcpcd sends no hostname (lease shows `-`); spice-vdagent doctor warning on VNC; one dracut prompt with LUKS; a re-run resumes a mounted target / open mapping rather than erasing.
- Assumptions (Type B, user did not answer the explore questions): narrow CLAUDE.md fix; J-4 SIGINT bug deferred; example + test + full --help included (user prefers complete); MASTER_PLAN fold stays a post-merge chore.
- VM procedure: memory void-live-iso-vm-driving.md.
