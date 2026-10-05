# installer-stage-dispatcher-split

## Session Date
2026-08-05

## Context
Second sub-task of the "Installer framework, Package management, Config
restore" epic (see
`.claude/changes/2026-08-05-package-management-lst-extraction.md` for the
first sub-task and the epic-level context/scoping questions). User chose a
full stage-dispatcher split for `install-fedora.sh`, mirroring
HyDE-Project/HyDE's `install.sh` orchestrator pattern (pre/install/restore/
services stages, `--dry-run` threaded through, per-stage flags) adapted to
this repo's single-Fedora-target scope — HyDE's version additionally
handles nvidia detection, multi-distro package managers, and a versioned
migrations subsystem, none of which apply here.

## What Was Requested
Split `install-fedora.sh`'s monolithic flow into a thin orchestrator over
independently-runnable, idempotent stages, with `--dry-run` support and
per-stage flags — full split, not a lighter "add flags to the one file"
version.

## What Was Implemented or Decided
- New `scripts/install-pre.sh`: sanity checks (dnf present, sudo
  available). Accepts `--dry-run` for interface consistency, though nothing
  in this stage mutates state.
- New `scripts/install-pkg.sh`: the dnf-package half of the old "install"
  logic — C Dev Tools group, `packages/core.lst` (required, hard-fail),
  `packages/extra.lst` (best-effort), the clipmenu/clipnotify COPR
  enable+install, and the `fdfind -> fd` shim. Full `--dry-run` support
  (every `dnf`/`ln` call gated).
- New `scripts/install-restore.sh`: ZDOTDIR export to `~/.zshenv`, calls
  `symlinks.sh`, and the zinit/TPM plugin-manager bootstrap clones. Full
  `--dry-run` support, including passing `--dry-run` through to
  `symlinks.sh`.
- New `scripts/install-services.sh`: chsh to zsh, `ly.service` enable. Full
  `--dry-run` support. Also fixed a latent issue this split exposed: the
  original inline code did `ZSH_BIN="$(command -v zsh)"` with no
  guard — safe only because it always ran after the package-install step in
  the same monolithic script (so zsh, a required package, was guaranteed
  present). Once this became a standalone-runnable script, running it
  before the install stage (or on a system where zsh isn't installed yet)
  would abort with a cryptic `set -e` failure on the unguarded command
  substitution. Fixed with `command -v zsh || true` + an explicit
  "zsh not found — run the install stage first" warning branch.
- `scripts/install-suckless.sh`: added `--dry-run` (build-deps install,
  each program's `make clean`/`make`/`make install`/`chown`, dwmblocks
  block-script install, `autostart.sh` write, `.xinitrc` write — all
  gated). Caught during manual dry-run testing: the `mkdir -p
  "$AUTOSTART_DIR"` line ran unconditionally *before* the dry-run branch,
  so `--dry-run` was actually creating `~/.local/share/dwm` (empty, but a
  real mutation `--dry-run` must never make). Confirmed by testing on this
  machine — it created the directory — then fixed (`[[ $DRY_RUN -eq 1 ]] ||
  mkdir -p ...`) and removed the accidentally-created directory before
  re-testing clean.
- `scripts/symlinks.sh`: added `--dry-run` — each of the three outcomes in
  `link()` (already-correct symlink / wrong-target symlink / pre-existing
  non-symlink path / nothing there yet) has its own dry-run branch that
  returns before any mutation.
- `scripts/install-fedora.sh`: rewritten as a thin orchestrator. Flags:
  `--only-pre` / `--only-install` / `--only-restore` / `--only-services`
  (any combination; a stage runs if its flag is passed OR if no `--only-*`
  flag was passed at all — preserves the existing "no flags = full install"
  default), `--skip-suckless` (unchanged meaning, now scoped to the install
  stage specifically), `--dry-run` (built into a `dry_run_args` array,
  passed to every sub-script invocation). The `-h/--help` sed range needed
  updating twice — the header comment grew substantially with the new flag
  docs, first attempt (`2,34p`) truncated mid-flag-list; corrected to
  `2,50p` and verified against the actual header line count.
- `CLAUDE.md`: project map now lists all 4 new stage scripts plus the
  updated one-liners for `install-fedora.sh`/`install-suckless.sh`/
  `symlinks.sh`; the "Entry points" paragraph rewritten to describe the
  stage-dispatcher model and its flags.
- `ROADMAP.md`: fixed one stale comment (`§4`-area package list) that still
  said "see ... install-fedora.sh's package list" — packages moved to
  `packages/*.lst` in the prior sub-task, comment now points there.
- Ran the `audit-loop` skill (Medium+ tier — 9 files changed, +421/-147 per
  `git diff --cached --shortstat`; checklist substituted with shell/bash
  equivalents as in every prior session, since it's written for a React
  Native/FSD app). Iteration 4 caught both the CLAUDE.md project-map doc
  gap and the stale ROADMAP.md comment above; both fixed in the same pass.
- Manually verified: `bash -n` on all 7 touched/new scripts; `--help`
  output on `install-fedora.sh` renders complete and correctly formatted;
  `--dry-run` runs of `--only-restore` and `--only-services` on this
  (Arch) dev machine complete cleanly with zero filesystem mutation
  (checked `~/.config/dwm` did not get created, since it doesn't exist yet
  on this machine and the dry-run output correctly said "would link"
  instead of linking); a full `install-fedora.sh --dry-run` run correctly
  hard-fails at the pre stage's `dnf` check on this non-Fedora dev machine,
  proving the pre-stage gate still works as designed; unknown-argument
  handling (`--bogus`) still exits 1 with a clear error.
- Spawned the `reviewer` subagent gate against the staged diff: `READY` —
  independently re-verified the dry-run-purity fix in
  `install-suckless.sh`, the `symlinks.sh` `link()` branch structure, the
  orchestrator's flag-dispatch logic, the `--help` sed range, and confirmed
  no dangling references to the old monolithic structure remain.

## Files Modified
- `scripts/install-pre.sh` (new)
- `scripts/install-pkg.sh` (new)
- `scripts/install-restore.sh` (new)
- `scripts/install-services.sh` (new)
- `scripts/install-suckless.sh` (modified — added `--dry-run`)
- `scripts/symlinks.sh` (modified — added `--dry-run`)
- `scripts/install-fedora.sh` (rewritten — thin orchestrator)
- `CLAUDE.md` (modified — untracked file, pre-existing content)
- `ROADMAP.md` (modified — untracked file, pre-existing content)

## Key Technical Decisions
1. **Stage names/boundaries: pre / install / restore / services**, matching
   HyDE's terminology (the user's explicit reference point) rather than
   inventing new names, while mapping each stage to exactly this repo's
   existing step list with no orphaned or invented steps: pre = sanity
   checks; install = dnf packages + suckless build (HyDE's own "install"
   stage is itself multiple sub-scripts — `install_aur.sh`, `install_pkg.sh`,
   `install_pst.sh` — so grouping `install-pkg.sh` + `install-suckless.sh`
   under one orchestrator stage follows that same precedent); restore =
   config symlinks + ZDOTDIR + plugin-manager bootstrap (HyDE's
   `restore_cfg.sh` is the closest analog); services = chsh + `ly.service`
   (HyDE's `restore_svc.sh`/service-enable step). If wrong: stage
   boundaries are just which script the orchestrator calls in which
   group — trivial to regroup without touching the individual scripts'
   internal logic.
2. **Hyphenated script names** (`install-pre.sh`, not HyDE's
   `install_pre.sh`) — matches this repo's own existing convention
   (`install-fedora.sh`, `install-suckless.sh`), not HyDE's, since repo-
   internal consistency was judged more important than mirroring HyDE
   literally in naming.
3. **`--dry-run` passed as an explicit CLI flag to each sub-script
   invocation** (built into a `dry_run_args` array in the orchestrator),
   not an inherited environment variable — keeps every stage script fully
   standalone-testable with the exact same flag whether invoked directly
   by a user or via the orchestrator.
4. **No migrations/versioning subsystem.** HyDE has one
   (`~/.local/state/hyde/migration/applied`, versioned `migrations/vX.Y.Z.sh`
   files) for safely replaying upgrades. Not built here — nothing in this
   repo's install flow is order-dependent across versions in a way that
   would need it, and the user didn't ask for it. If wanted later: a
   natural home would be a new stage between `restore` and `services`.
5. **No AUR/multi-distro package-manager branching added to the new
   stage scripts** — `packages/core.lst`/`extra.lst` and `install-pkg.sh`
   are dnf-only, matching this repo's Fedora-only scope (established in
   `.claude/changes/2026-08-05-fedora-only-single-installer.md`).
   `install-suckless.sh`'s own `install_deps()` still has its pre-existing
   pacman/apt-get/dnf branches (out of scope for this task, same reasoning
   as the prior Fedora-only session — that function is a shared low-level
   builder, not a top-level bootstrap installer).

## Assumptions Made
- **Type B** — grouped `install-suckless.sh`'s invocation under the
  orchestrator's "install" stage (called directly by `install-fedora.sh`
  after `install-pkg.sh`, not wrapped inside `install-pkg.sh` itself) so
  each script keeps single responsibility (dnf packages vs. suckless
  build) while the *stage* still groups them logically, matching how
  HyDE's own "install" operation is itself multiple sub-scripts. If wrong:
  trivial to nest the `install-suckless.sh` call inside `install-pkg.sh`
  instead.
- **Type C** — `install-pre.sh`'s `--dry-run` flag is accepted but is a
  no-op (nothing in that stage mutates state) — kept for interface
  uniformity across all 4 stage scripts rather than being the one stage
  script without the flag.

## Trade-offs
- `install-pkg.sh`/`install-restore.sh`/`install-services.sh` each
  independently re-detect `$SUDO` (duplicated 3-line pattern) rather than
  sharing a sourced helper file — matches this repo's existing convention
  of duplicating the `red`/`green`/`yellow`/`blue` logging helpers
  per-script (CLAUDE.md rule 2) rather than introducing a shared-sourced-
  file pattern that doesn't exist anywhere else in the repo yet.
- `install-pre.sh` and `install-services.sh` don't define
  `SCRIPT_DIR`/`DOTS_DIR` at all, since neither references another file by
  path — deviates from rule 3's letter ("every script computes its own
  location...") but not its intent (never hardcode a path); there's simply
  no path to compute in these two scripts.

## Open Questions / Blockers
N/A

## Next Steps
- Task 3 (this one) is done. Task 4 of the epic: config-restore/undo mode
  in `symlinks.sh` (add `--restore [timestamp]` to reverse a prior
  `~/.dotfiles-backup/<timestamp>/` snapshot back into place).
- Not tested against a live Fedora `dnf` — this dev machine is Arch, so the
  `pre` and `install` stages' `dnf`-dependent paths were verified only via
  `bash -n`, code review, and confirming the `pre` stage correctly
  hard-fails on this non-Fedora machine (proving the gate itself works).
  `--only-restore` and `--only-services --dry-run` *were* exercised live on
  this machine, end to end, with verified zero mutation.
- Consider whether `--only-pre`'s no-op `--dry-run` is worth keeping as
  every stage script grows, or whether it should be dropped if `pre` never
  ends up doing anything mutating.
