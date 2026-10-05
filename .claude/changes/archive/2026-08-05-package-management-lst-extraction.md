# package-management-lst-extraction

## Session Date
2026-08-05

## Context
First sub-task of a new epic: "Installer framework, Package management, and
Config restore" (user referenced HyDE-Project/HyDE as a reference point).
Explored `HyDE/` (untracked local reference clone) to ground design choices
— HyDE has two generations of package management: a legacy plain-text
`.lst` format and a newer Python+TOML system ("deez-dots"). Given this
repo's explicit constraint ("No package manager, framework, or build system
beyond `make` ... plain bash for orchestration"), the user chose the
plain-text `.lst` approach to avoid introducing a TOML-parser dependency.
User also chose to sequence the epic as package management -> installer
framework -> config restore (each stage consumable by the next), and to do
a full stage-dispatcher split for the installer framework in a later
sub-task (not this one).

Before starting, found and committed three sessions of pending uncommitted
work from earlier today (single-installer merge, dmenu-only switch,
clipmenu COPR swap) as a separate prior commit, to keep this epic's diff
isolated and reviewable. Also added `HyDE/` to `.gitignore` (was untracked
but not ignored — should never be tracked per `CLAUDE.md` rule 9).

## What Was Requested
1. Extract `install-fedora.sh`'s hardcoded `PACKAGES` array into external
   package-list files.
2. Format: plain-text `.lst` files (HyDE-legacy style), required vs
   best-effort split preserved/introduced.

## What Was Implemented or Decided
- New `packages/core.lst`: 6 required packages (`git`, `zsh`, `make`,
  `gcc`, `patch`, `pkgconf-pkg-config`) — pulled out of the old
  `PACKAGES` array's "shell & interface foundation" section. These are
  packages later steps in `install-fedora.sh` unconditionally depend on
  (git for the zinit/TPM bootstrap clones, zsh for the `chsh` step,
  make/gcc/patch/pkgconf-pkg-config for the suckless build that runs by
  default). Format: one package per line, `#` comments (whole-line or
  trailing), blank lines ignored.
- New `packages/extra.lst`: the remaining 75 packages from the old array,
  best-effort, with the original category comments preserved as section
  dividers (core system & display server; interface foundation; fonts &
  theming; desktop utilities; development stack; display manager).
- `scripts/install-fedora.sh`: replaced the inline `PACKAGES` array and
  single best-effort loop with a `read_pkg_list()` helper
  (`sed 's/#.*//' | tr -s '[:space:]' '\n' | grep -v '^$'`) and two loops:
  a required loop over `packages/core.lst` that `exit 1`s with a red error
  on any failed `dnf install`, and a best-effort loop over
  `packages/extra.lst` (unchanged behavior — yellow warning, continue).
  Also fixed a stale in-code comment that still referenced the deleted
  `PACKAGES` array name (near the `install-suckless.sh` invocation).
- `CLAUDE.md`: added `packages/` to the project map, a package-declarations
  line under Tech stack, updated rules 4 and 8 (both referenced the old
  `PACKAGES` array), and added rule 10 documenting the
  `packages/core.lst`/`packages/extra.lst` convention for future edits.
- Ran the `audit-loop` skill (Medium+ tier — 4 files, +138/-34 per
  `git diff --cached --shortstat`; checklist substituted with shell/bash
  equivalents as in prior sessions, since it's written for a React
  Native/FSD app). Iteration 1 flagged the CLAUDE.md doc gap (closed in the
  same pass, not deferred past this log). Iteration 4 caught the stale
  `PACKAGES`-array code comment (fixed). Verified via `git grep -n
  "PACKAGES\b"` that no other live script or doc references the deleted
  array — only immutable `.claude/changes/` history does.
- Manually verified `packages/extra.lst`'s package count (75) equals the
  original array's total (81) minus the 6 moved to `core.lst`, and spot-
  checked the parsed output of `read_pkg_list()` against both files.
- Spawned the `reviewer` subagent gate against the staged diff: `READY`.

## Files Modified
- `packages/core.lst` (new)
- `packages/extra.lst` (new)
- `scripts/install-fedora.sh` (modified)
- `CLAUDE.md` (modified — untracked file, pre-existing content)
- `.gitignore` (modified, prior commit — added `HyDE/`)

## Key Technical Decisions
1. **Plain-text `.lst`, not TOML.** Matches this repo's plain-bash-only
   constraint (no new parser dependency) and HyDE's own legacy format,
   which is the closer analog for a project this size. If wrong: HyDE's
   newer `dots-groups/*.toml` format (`Scripts/dots-groups/` in the
   reference clone) is the richer alternative, already includes a `dnf`
   package-manager template, but would need a TOML-parsing story (`yq` or
   similar) added to the repo first.
2. **Required-vs-best-effort split, not a single list.** The old single
   best-effort loop had a latent bug: if `git` or `zsh` failed to install
   (transient repo issue, renamed package, etc.), the loop would silently
   print a yellow "skipped" line and continue, then the script would
   `set -e`-abort later at the zinit/TPM `git clone` or `chsh` step with a
   confusing, seemingly-unrelated error. This exact bug was already caught
   and fixed for `install-arch.sh` in
   `.claude/changes/2026-08-04-fedora-server-arch-install-scripts.md`
   (`REQUIRED=(git zsh)` pulled out of that script's best-effort loop) but
   `install-fedora.sh` — which predates that fix and was never revisited —
   still had it. Extracting to `core.lst`/`extra.lst` was a natural point
   to fix it here too. If wrong: move packages back into a single list and
   drop the required loop's `exit 1`.
3. **`patch`/`pkgconf-pkg-config`/`make`/`gcc` treated as required
   unconditionally**, even though they're only strictly needed if
   `install-suckless.sh` actually runs (i.e., `--skip-suckless` wasn't
   passed). Kept simple rather than adding conditional-required-package
   logic keyed off a CLI flag — `--skip-suckless` is already documented as
   the less-common path, and installing these five extra packages
   unnecessarily in that path is low-cost. If wrong: gate the
   `make`/`gcc`/`patch`/`pkgconf-pkg-config` subset of core.lst's required
   loop behind `[[ $SKIP_SUCKLESS -eq 0 ]]`.

## Assumptions Made
- **Type C** — package *names* and their category groupings were carried
  over verbatim from the existing (already-verified-per-rule-8) array;
  no new package-name verification against packages.fedoraproject.org was
  performed since no names changed, only their storage location.
- **Type B** — chose `sed`/`tr`/`grep` for `read_pkg_list()` over a bash-
  native `while read` loop directly on the file (which would need its own
  comment-stripping logic inline at each call site) — a single reusable
  helper function was judged clearer and DRYer for two call sites.

## Trade-offs
- `packages/extra.lst`'s "interface foundation" section now only has 2
  entries (`sxhkd`, `kitty`) since the other 6 moved to `core.lst` — kept
  the section header as-is rather than renaming, since both remaining
  packages still fit the "interface foundation" description.

## Open Questions / Blockers
N/A

## Next Steps
- Task 3 of this epic: installer-framework stage-dispatcher split (thin
  orchestrator + sub-scripts for package install / config restore /
  services, per-stage flags, `--dry-run`), which will consume
  `packages/core.lst`/`extra.lst` from its own package-install stage.
- Task 4: config-restore/undo mode in `symlinks.sh`.
- Not tested against a live Fedora `dnf` — `bash -n`, manual parsing
  verification, and the reviewer pass are the only checks performed here
  (same pre-existing gap as every prior `install-fedora.sh` session).
