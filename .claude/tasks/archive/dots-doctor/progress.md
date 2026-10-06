# Progress — dots-doctor

## Status
`done`

## Steps
- [x] 1. scripts/doctor.sh: args (--tsv, -h), report() with both formats, exit 1 on any fail
- [x] 2. Checks, reusing the sources of truth: read_pkg_list/load_consequences, symlinks.sh --list-links, manifest meta, session_autostart_report (daemon names AND which the user's autostart.sh lacks)
- [x] 3. Register in scripts/dots SUBCOMMANDS
- [x] 4. tests/doctor.sh: sealed PATH fakes; human vs tsv agree; fail paths exit 1
- [x] 5. Docs: README/CLAUDE.md/CHANGELOG + dwm-titus section correction

## Deviations
- Added two test overrides (DOTS_DOCTOR_RELEASE, DOTS_DOCTOR_BT_SYSFS) and a theme section; DAEMON_PROCESS / daemon_applies exceptions held to the report by the test.

## Blockers
