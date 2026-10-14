# server-target
Date: 2026-10-14
Files: 8 | Lines: +150/-12

## What changed
- Docs: the `scripts/install-fedora.sh` header, the README intro, CLAUDE.md
  (project intro, entry points, Roadmap status) and a comment in
  drivers-laptop.sh now name **Fedora Server** as the one supported target.
  Fedora Workstation is stated as unsupported, with the reason.
- `scripts/install-pre.sh` prints a yellow note, never a refusal, when
  `systemctl is-enabled gdm.service` is `enabled`: Workstation is not a
  supported target, the install continues, and ly is enabled next to GDM,
  untested. Rule 2: a `yellow()` helper was added.
- New `tests/install-pre.sh`, the first test of the pre-flight stage:
  Server passes quietly; GDM gives the note and still passes; no dnf fails.
- CHANGELOG [Unreleased] → Changed.

## Why
The user (2026-10-14), asked whether Fedora Server is the target: yes,
"Server only". Workstation had been claimed since 0.1.0, but it was never
run, and nothing reconciles its pre-enabled GDM with the ly display manager
dots enables.

## Key Technical Decisions
- **DECISION:** Fedora Server is the one supported target. This narrows the
  long-standing "Server or Workstation" claim (CLAUDE.md intro, installer
  header).
- Warn, don't refuse: the rest of the install doesn't depend on it, and the
  user chose "keeps working, just unsupported".
- The CHANGELOG 0.1.0 text is release history and stays as written.

## Assumptions Made
- (C) GDM enabled is a reliable Workstation signal. Fedora Server ships no
  display manager, and dots enables ly, not GDM.

## Test coverage
- `tests/install-pre.sh` (new): 6 checks; disabling the note fails 2 of
  them. Full suite exit 0 (70). Lint passed. Reviewer READY.

## Follow-ups
- On main, after the merge: MASTER_PLAN's open queue item drops
  "Workstation as a target". Bare metal, a real GPU and a laptop remain.
