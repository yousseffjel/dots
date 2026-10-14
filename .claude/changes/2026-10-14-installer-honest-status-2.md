# installer-honest-status-2
Date: 2026-10-14
Files: 7 | Lines: +130/-62

## What changed
- The clipmenu COPR step moved from inline code in `scripts/install-pkg.sh`
  to `repos_add_clipmenu` in `scripts/install-pkg-repos.sh`, which now runs
  first in `repos_install`. It skips `dnf copr enable` when `dnf copr list`
  already shows `copr.fedorainfracloud.org/skidnik/clipmenu`. That list is
  captured first, not piped into `grep -q`; a disabled COPR is listed with
  " (disabled)" and so still gets enabled. clipmenu and clipnotify are
  skipped when installed and get a PACKAGE row only when installed now. A
  failure keeps the red tier and its consequence text.
- `repos_install_pkg` is deleted (a duplicate). sublime-text and ffmpeg now
  go through `drivers_pkg` (drivers-lib.sh), which skips installed packages
  and honours `--dry-run`.
- Tests: `tests/pkg-repos.sh`'s fake dnf learns `copr list/enable`. New
  checks: rows for clip*; a re-run makes no `dnf install` and no
  `copr enable`; a clipmenu that was already there gets no row; a COPR
  failure lands in the red tier with nothing attempted.
  `tests/default-apps.sh` now greps `drivers_pkg <name>`.
- CHANGELOG [Unreleased] → Fixed. The CLAUDE.md map moves the COPR to
  install-pkg-repos.sh.

## Why
The first 0.3.0 run on the VM still printed `installed: clipmenu`,
`clipnotify` and `sublime-text`, and Fedora's "Enabling a Copr repository"
notice, on every re-run. These were the two code paths installer-honest-status
had not touched.

## Key Technical Decisions
- One installer helper (`drivers_pkg`) for every repo-backed package, so
  "installed:" means the same thing in every step.
- The COPR step lives with the other third-party repos, where the test
  harness already is.

## Assumptions Made
- (C) `dnf copr list` (dnf5) prints `host/owner/project` per enabled COPR.
  Verified on the f44 VM: `copr.fedorainfracloud.org/skidnik/clipmenu`.

## Test coverage
- Mutations: 5 of 5 caught. Full suite exit 0 (69). Lint passed. Reviewer
  READY.
- VM (f44, everything installed): ran `repos_add_clipmenu` and
  `repos_add_sublime` with `SUDO=(false)`, so any privileged call would
  have failed. Real `dnf copr list` was recognised, no enable or install
  was attempted, no rows were written and nothing failed.

## Follow-ups
- Next: vm-picom (user, 2026-10-14). `drivers_chassis` gains `vm`, and
  picom's backend probe moves into a linked `dwm-picom` script with the
  rule "VM → xrender".
