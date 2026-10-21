# dots-doctor
Date: 2026-10-06
Files: 10 | Lines: +639/-26 (five new files)

## What changed
- `scripts/doctor.sh` (new): argument parsing (`--tsv`, `--help`) and
  `report <status> <section> <id> <text>`, the only place output is
  formatted, in either human text or TSV. A closing verdict (human only);
  exits 1 when any check failed.
- `scripts/doctor-checks.sh` (new):
  - install: manifest present and version vs `VERSION`; the `dots` symlink;
    every pair from `symlinks.sh --list-links` (a warn if it cannot be
    read); login shell; every manifest SERVICE unit enabled.
  - packages: each `packages/*.lst` by glob through `read_pkg_list`. A
    missing package is a fail with its `load_consequences` text in desktop
    and core, a warn in any other tier. Skipped without
    `/etc/fedora-release`.
- `scripts/doctor-session.sh` (new):
  - session: dwm and `$DISPLAY`; daemons named by running the installer's
    `session_autostart_report`, once against `/dev/null` (every name) and
    once against the real `autostart.sh` (the ones it does not mention);
    picom backend; dwm X resources.
  - theme: cache, `.fehbg`, `.gtkrc-2.0` header, the dconf colour scheme.
  - system: pamixer, nmcli, bluetooth sysfs.
- `scripts/dots`: `doctor` row in `SUBCOMMANDS`.
- `tests/doctor.sh` + `tests/lib/doctor-sandbox.sh` (new, 34 checks, sealed
  PATH).
- `CLAUDE.md`: the dwm-titus "ahead of dots" list rewritten (see Why), the
  `dots` subcommand list, the project map. `README.md`, `CHANGELOG.md`.

## Why
The user picked this to replace "what is next" item 5, which rested on my
mistake: both of its tests (`tests/dwm-runtime.sh`,
`tests/install-uninstall-symmetry.sh`) had existed since September. I had
repeated CLAUDE.md's dwm-titus section, which still said "dots has never
executed dwm in a test", without checking the repo. That section now marks
each item harvested, with its date and file. The goal of the doctor: one
paste from the VM instead of a series of ssh one-liners.

## Key Technical Decisions
- **One code path.** Only `report()` knows the format, so a check cannot
  exist in one format and not the other. The test compares the status
  sequences of both formats.
- **No list restated.** Daemon names come from the installer's report;
  tiers, consequences, links and services from their declarations. Two
  small exception tables stay unavoidable:
  - `DAEMON_PROCESS`: `dwm-lock` runs as `xss-lock`; `autorandr` runs once
    and exits.
  - `daemon_applies`: `spice-vdagent` only in a VM; `blueman-applet` only
    with an adapter.

  The test fails if any of their names stops being a reported daemon.
- **Two kinds of daemon warning.** A daemon that `autostart.sh` never
  mentions is told to run the installer and paste the line it prints. One
  that is mentioned but not running is told it exited.
- **Fedora gate on packages.** The Arch dev host has an `rpm` binary over
  an empty database, and the first run reported 40 false FAILs.

## Assumptions
- Type B: running `dots doctor` from a terminal inside dwm gives it
  `DISPLAY`, and a `PATH` that includes `~/.config/dwm/bin`. That is true
  for any terminal started from dwm (`.zshenv`).
- Type C: `pgrep -f '(^|/)name( |$)'` matches every daemon as Fedora
  launches it (binaries, plus python/bash scripts). Checked against how
  `install-session-template.sh` starts each one, not observed live.

## Test coverage
- `bash tests/run-tests.sh`: 38/38 OK. `tests/lint.sh` passes.
- Mutation testing on scratch copies, 12/12 CAUGHT:
  - the tsv output skipping a check;
  - a missing desktop package only warning;
  - no consequence text;
  - fails not counted;
  - no process map;
  - no VM check;
  - the same advice for both daemon cases;
  - no X guard;
  - rpm trusted without Fedora;
  - services ignored;
  - links silent;
  - SERVICE read from field 3.
- **Reviewer BLOCK, round 1.** `check_services` read SERVICE field 3, but
  `install-services.sh` writes `SERVICE<TAB>unit`. The test fixture had
  hand-written a three-field row, so the test passed while the check could
  never run on a real install. Fixed: the doctor now reads field 2, and the
  fixture writes through `manifest_set_meta` / `manifest_append_row`.
  Round 2: READY.
- Audit findings, all fixed:
  - the sandbox had no `bash`, so the link checks never ran and passed
    vacuously; a count check now ties them to `--list-links`;
  - `shfmt` rewrote the unquoted key `[dwm-lock]` as `[dwm - lock]`.
- **Not verified:** a real run inside dwm on the VM, which is the point of
  the command.

## Follow-ups
- The user runs `dots doctor` on the VM and pastes the output.
- Possible later checks: night-light status, the portal process. Both are
  left out for now: the daemon check covers the night light, and the
  portal is D-Bus activated, so not running is normal.
