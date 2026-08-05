# fedora-only-single-installer

## Session Date
2026-08-05

## Context
Follow-up, same day, to `.claude/changes/2026-08-05-clipmenu-copr-swap-fedora.md`.
The user asked to "clean the scripts install and make that project can be
installed just in fedora server and fedora workspace [workstation]", framed
around the idea of taking a bare Fedora Server box and getting the full
desktop (dwm + this repo's config) on it. Given the scope of the change
(deleting three of the repo's five top-level installer scripts, restructuring
the other two), two clarifying questions were asked before touching anything,
per the clarification-first protocol's destructive-operations and
architectural-impact triggers.

## What Was Requested
1. Narrow the project's supported install targets to just Fedora Server and
   Fedora Workstation.
2. Specifically: make it possible to take a Fedora Server install and get
   the full desktop config on it, the same as Fedora Workstation.
3. "Clean" the install scripts as part of this — implied cleanup/dedup, not
   just docs.

## Clarifications Asked and Answers
1. **What to do with the non-Fedora installers** (`install.sh` for
   Debian/Ubuntu, `install-arch.sh`, `install-macos.sh`)? User chose:
   **delete them entirely.**
2. **How should `install-fedora.sh` (desktop) and `install-fedora-server.sh`
   (headless, `--with-suckless` opt-in) relate**, given the desktop script
   already installs Xorg from scratch and doesn't actually require the
   Workstation spin? User chose: **"we need to have just one script that do
   install full desktop"** — i.e. merge down to a single installer, no
   separate headless-only path.

## What Was Implemented or Decided
- Deleted `scripts/install.sh`, `scripts/install-arch.sh`,
  `scripts/install-macos.sh`, and `scripts/install-fedora-server.sh`.
  `scripts/install-fedora.sh` is now the repo's sole installer — it already
  installed Xorg, ly, and the full suckless desktop from a bare `dnf`
  baseline, so it works unchanged on either a fresh Fedora Server or Fedora
  Workstation box; no functional/package-list changes were needed to make it
  cover both.
- `scripts/install-fedora.sh`: rewrote the header comment to state this is
  the one supported installer and explicitly document that it targets both
  Fedora Server and Fedora Workstation. Reworded the `--skip-suckless` flag
  doc for clarity (unchanged behavior). Removed a trailing comment that
  referenced the now-deleted `install.sh`'s server-oriented opt-in model.
- `scripts/install-suckless.sh`: updated the header comment that previously
  said it "runs standalone (Arch, Debian/Ubuntu, Fedora) or via `install.sh
  --with-suckless` / `install-fedora.sh --with-suckless`" (both flags never
  existed as written, and now referenced two deleted scripts) to correctly
  describe it as running standalone or as part of `install-fedora.sh`
  (which calls it unless run with `--skip-suckless`). Left the
  pacman/apt-get/dnf dependency-detection branches in `install_deps()`
  untouched — out of scope for this task (only the top-level bootstrap
  installers were narrowed to Fedora, not this shared builder's own
  multi-distro build-dep fallback), and harmless dead code otherwise.
- `CLAUDE.md`: updated the intro paragraph, tech-stack verification line,
  project map (`scripts/` tree now lists exactly `install-fedora.sh`,
  `install-suckless.sh`, `symlinks.sh`), entry-points paragraph, two
  roadmap-status bullets (one now explicitly documents the four deleted
  scripts as a scope note so a future reader isn't confused by ROADMAP.md's
  older multi-distro framing; the other drops a since-resolved
  Fedora-vs-Arch caveat), and project rules 4 and 8 (dropped
  Arch/AUR/`pacman -Si` specifics that no longer apply to any script in the
  repo).
- `ROADMAP.md`: fixed the one dangling reference to `install-arch.sh` in a
  package-list source comment (§4-area, near the picom/dunst desktop-core
  list) to point at `install-fedora.sh` only. Left every other `install.sh`
  mention in the file untouched — those describe HyDE-Project's own
  installer as the comparison subject, not this repo.
- Ran the `audit-loop` skill (Medium+ tier — 6 tracked files changed, 51
  insertions / 596 deletions per `git diff --shortstat`, plus edits to the
  two untracked-but-checked-in doc files). Iteration 3 (Types/Validation,
  substituted for this repo as quoting/error-propagation/data-safety
  equivalents) caught a real bug: `install-fedora.sh`'s `-h|--help` used a
  hardcoded `sed -n '2,18p'` to slice its own header comment for display,
  and the header-comment edits above shifted where the intended cutoff
  (the end of the Node.js note) actually falls, truncating `--help` output
  mid-sentence. Fixed by recomputing the correct range (`2,24p`) and
  verifying by actually executing `install-fedora.sh --help` and
  `install-suckless.sh --help`, confirming both print complete, correctly
  formatted text.
- Ran a final repo-wide `grep` for the four deleted scripts' filenames
  outside `.claude/changes/` (immutable) and `HyDE/` (untouched reference
  clone) — zero dangling references remained after the fixes above.
- Spawned the `reviewer` subagent gate: `READY` on first pass — independently
  confirmed the sed-range fix, confirmed no dangling references anywhere
  including Makefiles/CI (none exist in this repo), and confirmed the doc
  updates were consistent with the code changes.

## Files Modified
- `scripts/install.sh` (deleted)
- `scripts/install-arch.sh` (deleted)
- `scripts/install-macos.sh` (deleted)
- `scripts/install-fedora-server.sh` (deleted)
- `scripts/install-fedora.sh` (modified — comments + `--help` sed range fix)
- `scripts/install-suckless.sh` (modified — header comment only)
- `CLAUDE.md` (modified — untracked file, pre-existing content)
- `ROADMAP.md` (modified — untracked file, pre-existing content)

## Key Technical Decisions
1. **Fedora-only, no other distros.** Direct result of the first
   clarifying answer. If wrong: the deleted scripts are fully recoverable
   from git history (they were tracked, committed files before this
   session).
2. **One installer, not two.** `install-fedora.sh` already covered the
   "Fedora Server → full desktop" case with zero code changes needed — it
   installs Xorg itself and never checked for a pre-existing GUI, so the
   Workstation-vs-Server distinction was already cosmetic in its own logic.
   The actual work was deleting the redundant headless-only script and
   fixing every comment/doc that assumed it still existed. If wrong: a
   headless-only path can be reintroduced as a flag on `install-fedora.sh`
   (e.g. `--headless`, skipping the Xorg/ly/suckless blocks) rather than as
   a second file, to avoid reintroducing the duplicated
   symlinks/zinit/tpm/shell-default logic the two old scripts shared.
3. **`install-suckless.sh` left multi-distro internally.** Its
   `install_deps()` still detects pacman/apt-get/dnf. Not touched because
   the user's ask was about the top-level bootstrap installers narrowing to
   Fedora, not this shared low-level builder — and it's harmless,
   unreachable-in-practice generality now that no top-level script targets
   those package managers.

## Assumptions Made
- **Type C** — "fedora workspace" in the user's request was read as a typo
  for "Fedora Workstation" (the desktop spin), consistent with the rest of
  the sentence contrasting it with "fedora server."

## Trade-offs
- Didn't touch `install-suckless.sh`'s pacman/apt-get dependency branches
  even though the project is now Fedora-only end-to-end for its bootstrap
  path — left as unreachable-but-harmless generality rather than expanding
  scope beyond what was asked. Could be stripped in a future cleanup pass
  if the user wants the builder itself to assert Fedora-only too.

## Open Questions / Blockers
N/A

## Next Steps
- Not tested end-to-end on real Fedora hardware (same pre-existing gap
  noted in earlier logs — `install-fedora.sh` has never been run against a
  live Fedora Server or Workstation box in this environment). `bash -n`
  syntax checks and executing `--help` on both remaining scripts are the
  only verification performed here.
- Consider whether `install-suckless.sh`'s pacman/apt-get branches should
  be removed for full Fedora-only consistency (see Trade-offs) — left as an
  open call for the user, not assumed.
