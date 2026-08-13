# install-container-harness
Date: 2026-08-13
Files: 14 | Lines: +772/-33
(of which the harness and the two fixes are 9 files, +397/-33 — the rest is
this log and the task folder)

## What changed

- **`.github/workflows/install-container.yml`** — a new workflow whose single
  job runs `scripts/install-fedora.sh` to completion in `fedora:latest` and the
  pinned oldest-supported image, then makes **23 assertions** about what landed.
  It is the only thing in this repo that has ever executed the installer:
  `install-dry-run` validates the installer's *inputs* and never invokes it
  (`grep -c install-fedora ci.yml` was **0**), and `build-suckless` compiles the
  C programs without installing anything around them.
- **Every expectation is derived from a shipped source of truth**, never
  restated in the workflow: stage banners are extracted from
  `install-fedora.sh` itself, the link set from `symlinks.sh --list-links`, the
  binaries and the enabled unit from the manifest's own `SUCKLESS`/`SERVICE`
  rows, and package failures from the red closing summary `install-pkg.sh`
  already prints. Adding a stage, a symlink pair or a suckless program is
  covered with no edit here.
- **A NOT-COVERED report step**, printed on every run, naming what a container
  cannot prove (ly actually starting; anything graphical) and — after being
  corrected twice against evidence — what it *can* (`chsh`, and
  `systemctl enable`, which is offline symlink creation).
- **`scripts/install-services.sh`, two production bugs found by the harness on
  its first real run** (see Why).
- Docs reconciled: `TESTING.md` (the container section now leads with the job),
  `CLAUDE.md`, `README.md`, `ROADMAP.md`, `docs/UNINSTALL.md`,
  `scripts/install-fedora.sh`'s header and closing hint.

## Why

`MASTER_PLAN.md`'s "Framework parity with HyDE" block: a harness that actually
runs the installer, because "run `install-fedora.sh` end-to-end" had sat open
since 2026-08-04 and `TESTING.md` only told a human to drive podman by hand.
Acceptance was explicitly *not* "a script exists" — it is that the harness runs
the installer to completion and asserts.

It paid for itself immediately. **Two bugs, both live on real hardware:**

1. **`$USER` was unbound under `set -u`** (`install-services.sh:62`). Unset in
   any container, cron job or `su -c`, so the services stage aborted after
   every earlier stage had succeeded. Now `id -un`, with `|| true` on the
   getent pipeline — under `pipefail` a passwd miss aborts on the *assignment*,
   printing nothing.
2. **It enabled `ly.service`, which does not exist.** Fedora's `ly` ships a
   **templated** `ly@.service` (`Conflicts=getty@%i.service`) with no `Alias=`.
   `systemctl enable ly.service` fails with "Unit ly.service does not exist" —
   meaning **no display manager had ever been enabled by this installer, on any
   machine**, and nothing had ever executed that line to find out. Now
   `ly@tty2.service`; the unit's own `Conflicts=` releases tty2 from its getty,
   and tty1's getty is deliberately left as a rescue login.

## Assumptions

- **Type B — the guard degrades rather than aborts.** `systemctl enable`
  failure now yields a yellow "run manually" line, mirroring the `chsh` call
  above it. This changes production behaviour to serve a test, which is why the
  wrong-unit bug above had to be fixed in the same task: without it the guard
  would quietly hide a display manager that never gets enabled. Unlike `chsh`,
  stderr is **not** suppressed — systemctl's own message is what identified the
  bug.
- **Type B — tty2, not tty1.** Upstream ly's recommendation, and it keeps a
  getty on tty1 as a rescue login. `install-fedora.sh`'s closing hint about
  "disable getty@tty1 first" was written for the old assumption and is now
  wrong, so it was corrected.
- **Type B — CI-job-only, no local `tests/install-container.sh`**, and later
  **split into its own workflow file** rather than extracted to a script. Both
  chosen by the user from presented options. Consequences are recorded under
  Follow-ups rather than papered over.
- **Type C — assertions derive from shipped sources** rather than enumerating,
  per the repo's repeated experience with stale hand-written lists.

## Test coverage

**13/13 test scripts executed, 0 failures.** 12 locally plus
`tests/lint.sh --strict`; `tests/build.sh` — the one this Arch host cannot run
— was executed **inside the Fedora container** rather than skipped, and built
all five suckless programs.

The harness itself was verified against a live `fedora:latest` container, not
reasoned about:

- Installer ran to completion, **exit 0**, all five stage banners plus
  `✓ install complete`. A second full run (**also exit 0**) doubles as the
  rule-1 idempotency check.
- Assert step: **23 OK assertions**, exiting 1 on the one genuine finding. The
  step was extracted verbatim from the workflow each time, never paraphrased.
- **8/8 deliberate mutations caught**: removed symlink, repointed symlink,
  deleted suckless binary, stripped ZDOTDIR, truncated `install.log`, stripped
  the `SERVICE` row (wrong-unit-name proxy), an *added* stage banner, and
  `chsh -s /bin/bash` (the reviewer's finding).
- **Cold install measured at 32 minutes**, which is what set
  `timeout-minutes: 90` — one dnf transaction per package means wall-clock
  tracks package count, not download size.

## Follow-ups

- **`polkit-gnome` is retired on Fedora 44** and `dnf list --available` does not
  resolve it, so **`install-dry-run` will go red on it too**, independently of
  this task. It is in `desktop.lst`, so a fresh install today ships with no
  PolicyKit agent. Replacements present on F44: `lxpolkit`, `mate-polkit`,
  `xfce-polkit`, `polkit-kde`. Fixing it is a three-file change per rule 6
  (`desktop.lst` + the absolute libexec path in `install-session-template.sh`
  and `install-session-report.sh`). **Queue this on main.**
- **Accepted debt, deliberately not fixed:** the ~110-line assert body is inline
  in YAML and `tests/lint.sh` does **not** lint bash inside YAML (it covers
  `scripts/`, `tests/` and root `*.sh`). It is shellcheck-clean only because it
  was extracted and checked by hand. The workflow header says so and says what
  to do when editing it.
- `install-container.yml` is 287 lines, over the 250 this repo enforces on
  `scripts/*.sh`. That cap has never been applied to a workflow (`ci.yml` sat at
  210 unexamined), so it is flagged rather than treated as a violation.
- `/test`'s discovery table still matches nothing here — no `.claude/config.yml`
  with `test_command` — so every task falls through to "no test suite" despite
  13 scripts. Recording that skip would be false; this task used option B.
- **Still unproven, and unchanged by this task:** `install-fedora.sh` has never
  run on real hardware. ly has been *enabled*, never *started*; nothing
  graphical has run. The harness narrows the oldest risk in this repo without
  closing it.

## Lessons

- **The harness found a bug nothing else could have.** `ly.service` was wrong
  from the day it was written, survived every lint, every review and a
  package-name validation job, and was invisible to all of them because none of
  them ever *ran* the line. Verification that inspects inputs cannot find a
  wrong output.
- **Three of my own claims were corrected by evidence, in the same direction
  each time: I assumed a container could do less than it can.** `chsh` works;
  `systemctl enable` works (offline symlink creation needs the unit *file*, not
  a running systemd) — and that second fact is precisely *why* the job catches a
  wrong unit name. The NOT-COVERED block was rewritten twice.
- **The reviewer's BLOCK was on a claim, not on code.** A comment said "getent
  confirms the shell afterwards" and no such check existed — so a regression in
  the very `chsh` path this task had just patched would have shipped green. Four
  structured audit sweeps read the assertions and the prose separately and never
  noticed they disagreed. **Assertions and the prose describing them are two
  places stating one fact**, which is the drift shape this repo keeps
  rediscovering.
- **A test that fails for the wrong reason is not a passing test.** The first
  mutation run "died" because the mutant could not find `global_fn.sh` from the
  scratchpad, not because of the bug under test. Re-run in place, it died
  correctly. Same session, the `sudo` shim was missing so a fake `systemctl`
  was never reached — the assertion passed while testing nothing.
