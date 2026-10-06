# Plan — dots-doctor

## Goal
`dots doctor`: one read-only health report for an installed desktop —
install state, packages, X session daemons, theme, audio/network/bluetooth,
the colour scheme — as human text or `--tsv`, from ONE code path (dwm-titus
harvest item #5). Purpose: one paste from the VM instead of many one-liners.
Also correct CLAUDE.md's stale dwm-titus "ahead of dots" list.

## Scope
- scripts/doctor*.sh, scripts/dots, tests/**, docs/**, README.md
- CLAUDE.md, CHANGELOG.md, TESTING.md, .claude/tasks/dots-doctor/**

## Allowed

## Forbidden
- HyDE/
- dwm-titus/

## Steps
1. scripts/doctor.sh: args (--tsv, -h), report() with both formats, exit 1 on any fail
2. Checks, reusing the sources of truth: read_pkg_list/load_consequences, symlinks.sh --list-links, manifest meta, session_autostart_report (daemon names AND which the user's autostart.sh lacks)
3. Register in scripts/dots SUBCOMMANDS
4. tests/doctor.sh: sealed PATH fakes; human vs tsv agree; fail paths exit 1
5. Docs: README/CLAUDE.md/CHANGELOG + dwm-titus section correction

## Out of scope
- Repair actions (doctor never changes anything)
- Running on a box without rpm beyond skipping the package section

## Risks
- pgrep -f self-match — doctor's own cmdline never contains a daemon name; patterns anchored
- noisy warnings for conditional daemons — distinguish "not in autostart.sh" from "started but not running"
