# Context — install-container-harness

## Background

`MASTER_PLAN.md` queue, "Framework parity with HyDE" block, opened 2026-08-12
from a fresh diff against the local HyDE clone (`8fa0073e`). HyDE ships
`Scripts/hydevm`; `TESTING.md` here tells a human to drive `podman`/`toolbox`
by hand, which is why "run `install-fedora.sh` end-to-end" has sat open since
2026-08-04. Acceptance is explicitly **not** "a script exists" — the harness
must run the installer to completion and assert.

## Prior Decisions

- **Dark-mode-only / scope-a, package tiers / rule 10, COPR-by-ask / rule 4** —
  untouched by this task.
- **2026-08-12, CI Fedora pin**: the matrix is `fedora:latest` + an
  oldest-supported pin (`fedora:43`). The pin must be **bumped, not deleted**.
  This task reuses that matrix and must not change the pin.
- **2026-08-10**: CI *invokes* `tests/lint.sh --strict` and `tests/build.sh`
  rather than reimplementing them, so the scripts cannot rot. A new job should
  respect that principle — but this task is **CI-job-only by decision this
  session**, so there is no script to invoke; the job body is the harness.
- **This session, decided by the user:** (a) `install-services.sh` gets a
  no-systemd fallback rather than the harness skipping the services stage;
  (b) no local `tests/install-container.sh`.

## References

- `.github/workflows/ci.yml` — `build-suckless` and `install-dry-run` are the
  two existing `container:` jobs; copy their cache + matrix convention.
- `scripts/install-fedora.sh:127-163` — the four stage dispatches.
- `scripts/install-fedora.sh:66-67` — tees everything to `install.log` at the
  repo root, ANSI-stripped. A ready-made assertion target.
- `scripts/install-services.sh` — the `chsh` fallback (already tolerant) and
  the bare `systemctl enable ly.service` (aborts under `set -e`).
- `packages/desktop.lst:32` — `ly`, which is what makes that line reachable.
- `TESTING.md:146-180` — the hand-driven podman/toolbox flow this supersedes.
- `.claude/changes/2026-08-12-ci-fedora-eol.md` — the pin's rationale.

## Notes

- **`install-dry-run` is misnamed**: it validates `packages/*.lst` against
  enabled repos with `dnf list --available` and never runs the installer.
  `MASTER_PLAN.md` says it "proves only that the orchestrator threads its
  flags" — that is too generous and should be corrected when this closes.
- Container runs as **root**, so `SUDO=()` is empty throughout — no sudo
  plumbing needed, and `install-pre.sh`'s privilege check passes.
- `chsh` is **not** a blocker: `elif chsh -s "$ZSH_BIN" 2>/dev/null` already
  degrades to a yellow line. Only `systemctl enable` aborts.
- The restore stage clones zinit and TPM over the network, and `install-pkg.sh`
  enables the `skidnik/clipmenu` COPR. Both need egress from the runner.
- This host has **docker**, not podman (checked); `TESTING.md` documents only
  podman/toolbox. Step 5's local verification therefore uses docker.
