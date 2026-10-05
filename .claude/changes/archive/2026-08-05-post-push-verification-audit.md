# Post-push verification audit — uninstall/versioning/migrations + CI tooling

## Session Date
2026-08-05

## Context
User asked, after pushing the day's two concurrent sessions (uninstall/
versioning/migrations subsystem and CI/lint tooling — see
`2026-08-05-uninstall-versioning-migrations.md` and
`2026-08-05-ci-tooling-shellcheck-precommit.md`), to verify everything
landed correctly. Ran three parallel read-only audit agents (collision
damage, versioning/uninstall/migrations correctness, CI tooling
correctness), then fixed every confirmed bug and gap found, with the
user's explicit go-ahead to "fix everything."

## What Was Requested
Verify the two prior sessions' pushed work is correct; fix whatever the
verification turns up.

## What Was Implemented or Decided

### Collision check — clean
Both sessions' commits are correctly interleaved on `main`, already
pushed (`git ls-remote` confirmed local HEAD matches the real remote). No
conflict markers, no lost work, no garbled merges in the shared files
(`install-pkg.sh`, `install-services.sh`, `install-suckless.sh`,
`README.md`). No fix needed.

### Real bug — `scripts/version.sh` crashed on every real install (fixed)
`dwm -v` intentionally calls suckless `die()` → exit 1
(`suckless/dwm/dwm.c`). Under this script's `set -euo pipefail`, that exit
code silently killed `version.sh` with zero output the moment `dwm` was
actually on `$PATH` — i.e. on every real installed system, which is the
whole point of the script. The prior session's change log claimed this
exact scenario was "confirmed and handled with `2>&1 | head -1`" — it
wasn't; piping doesn't neutralize the exit code under `pipefail`. Fixed
with `|| true` on the assignment. Verified with a stub `dwm` binary that
mimics the real exit-1 behavior: script now completes with correct output
and exit 0.

### Latent same-class footgun — `scripts/install-restore.sh` (fixed)
`run_backup_dir="$(comm -13 <(...) <(ls ...| sort) | head -1)"` at line 62
had the identical `set -e`/`pipefail` fragility (head-closes-pipe-early
SIGPIPE-ing `comm`), currently masked only by luck (symlinks.sh creates at
most one backup dir per run, so the pipe never carries enough lines to
trigger it). Hardened with the same `|| true` fix pre-emptively.

### `.shellcheckrc` didn't do what its own comment claimed (fixed)
`external-sources=true` only permits shellcheck to follow paths outside
the given file set — it does not resolve a dynamic
`source "$SCRIPT_DIR/global_fn.sh"` on its own. Running shellcheck for
real (installed via `pipx install shellcheck-py` for this audit — neither
prior session had it available) produced SC1091 on the 7 scripts that
source `global_fn.sh`, non-zero exit. Added `source-path=SCRIPTDIR`.
Verified: `shellcheck` across every `*.sh` in the repo now exits 0.

### `shfmt` reported diffs in all 14 scripts (fixed)
Neither prior session had `shfmt` installed either (installed via
`go install mvdan.cc/sh/v3/cmd/shfmt@v3.13.1` — the exact version pinned
in `.pre-commit-config.yaml`/`ci.yml` — for this audit). Running the
pinned `shfmt -i 4 -ci -bn -d` against the real committed tree reported
diffs in **all 14** `.sh` files, contradicting the CI session's log
("All 7 scripts already use 4-space indent... consistently"). Ran
`shfmt -i 4 -ci -bn -w` repo-wide. Verified: `bash -n`, `shellcheck`, and
`tests/{pkglist,lint}.sh` all still pass after the reformat; behavior
unchanged (only whitespace/case-clause-splitting/redirect-spacing, no
logic touched).

Two pre-existing info-level shellcheck findings surfaced once SC1091
cleared (`install-restore.sh`'s intentional single-quoted `.zshenv` write,
SC2016; its `ls -1 | sort` on a timestamp-only directory, SC2012) — both
genuine false positives in this context, silenced with scoped
`# shellcheck disable=` directives plus a one-line justification, per this
repo's existing "scoped disable + justification" convention.

### Uninstall coverage gaps (fixed)
Two categories `install-*.sh` deploys were untracked by the manifest and
therefore silently un-reversible by `uninstall.sh`, neither mentioned in
`docs/UNINSTALL.md`:
- **dwmblocks block scripts** (`dwm-cpu`/`dwm-mem`/`dwm-clock`/
  `dwm-colors`, deployed to `~/.local/bin` by `make install-scripts` — a
  separate target from `make install`, so the existing `SUCKLESS`-row
  uninstall step never touched them). Added a `SCRIPT` manifest category
  (written in `install-suckless.sh`, globbed from the same
  `scripts/dwm-*` the Makefile installs from — no hardcoded script list)
  and a new uninstall.sh step that removes each recorded path directly.
- **Login shell** (`install-services.sh`'s `chsh -s "$ZSH_BIN"` — no
  manifest row, so `uninstall.sh` could never revert it, and
  `docs/UNINSTALL.md`'s "what's kept" list didn't mention it at all,
  unlike the ZDOTDIR line which explicitly calls out that it's an
  intentional keep). Added a `SHELL` manifest row (previous shell → new
  shell), written only on the one run that actually changes it, and a new
  uninstall.sh step offering to `chsh` back to the recorded previous
  shell.

Both verified end-to-end in a sandboxed `$HOME`/`XDG_STATE_HOME`: manifest
rows write correctly, uninstall-side read-back reverses them correctly,
idempotent re-runs don't duplicate or corrupt rows.

### File-size cap hit — split `scripts/uninstall.sh` (fixed)
Adding the two new categories above pushed `uninstall.sh` from 213 to 277
lines, over this repo's 250-line cap (`file-architecture.md`). Split per
the `split-oversized-file` skill's intent, adapted to bash (no JS/FSD
layers here): extracted each of the seven confirm()-gated category blocks
verbatim into its own function in a new `scripts/uninstall_steps.sh`
(sourced by `uninstall.sh`, not standalone-runnable), leaving
`uninstall.sh` as a thin orchestrator (arg parsing, logging setup, banner,
then seven function calls in the original order). Result: `uninstall.sh`
116 lines, `uninstall_steps.sh` 191 lines, every function ≤ 33 lines — no
behavior change, verified with a full sandboxed `--yes --dry-run` run
exercising all seven categories end-to-end (exit 0, same output shape as
before the split).

### Addendum — correcting a stale record in a prior log
`2026-08-05-ci-tooling-shellcheck-precommit.md`'s "Files Modified" and
"Next Steps" sections state the SC2086 `$SUDO`-array fix to
`install-pkg.sh`/`install-services.sh`/`install-suckless.sh` was "applied
but not committed," pending a future follow-up commit or a request to the
other session to fold it in. In fact it was already folded into the other
session's commit `0068a70` ("feat(install): track install manifest across
all install stages") — confirmed via `git show 0068a70 -- scripts/install-pkg.sh`,
which contains both the array-form diff and the manifest-tracking diff
together. Per this repo's append-only change-log rule, that prior log is
left untouched; this entry is the correction of record. No code action
needed — the fix was already live and correct, only the two sessions'
own narrative of *how* it landed was out of sync.

## Files Modified
- `scripts/version.sh` — `dwm -v` pipefail fix
- `scripts/install-restore.sh` — `comm | head` pipefail fix, 2 scoped
  shellcheck disables
- `.shellcheckrc` — added `source-path=SCRIPTDIR`
- `scripts/install-suckless.sh` — SCRIPT manifest rows for dwmblocks block
  scripts
- `scripts/install-services.sh` — SHELL manifest row for the chsh change
- `scripts/uninstall.sh` — rewritten as a thin orchestrator; new
  "dwmblocks block scripts" and "login shell" categories added as part of
  the split below
- `scripts/uninstall_steps.sh` (new) — the 7 category functions extracted
  from `uninstall.sh` once it crossed the 250-line cap
- `docs/UNINSTALL.md` — documents both new uninstall steps
- All 14 pre-existing repo `*.sh` files — `shfmt -i 4 -ci -bn -w` reformat
  (whitespace/case-clause/redirect-spacing only, verified
  behavior-preserving)

## Key Technical Decisions
- `SCRIPT` and `SHELL` are new manifest row categories, following the
  same `manifest_append_row` "stable once written, append-if-missing"
  semantics as `PACKAGE`/`SERVICE`/`SUCKLESS` (not `manifest_upsert_row` —
  neither value legitimately changes across idempotent re-runs the way
  `CONFIG`'s backup path does).
- Fixed the two real `pipefail`/`set -e` footguns with `|| true` rather
  than restructuring the pipelines — smallest correct change, consistent
  with how the prior session fixed the same bug class in `uninstall.sh`'s
  `_log_line()`.
- Corrected the stale CI-session log via a new dated addendum rather than
  editing the original file, per `session-protocol.md`'s append-only
  invariant.

## Assumptions Made
- **Type B** — used `pipx install shellcheck-py` and
  `go install mvdan.cc/sh/v3/cmd/shfmt@v3.13.1` to get real, pinned-version
  tooling for this audit (neither was available in either prior session's
  sandbox) rather than continuing to rely on manual review — this is what
  actually surfaced the SC1091/shfmt-diff findings.
- **Type B** — added the login-shell revert step as a new confirm()-gated
  uninstall category (matching the existing services/packages pattern)
  rather than only documenting the gap — reversibility was judged to
  matter more here than for e.g. the zinit/TPM clones, which are
  explicitly left alone because they're not installer-specific state.

## Trade-offs
- Did not address two smaller, lower-impact gaps the versioning-audit
  agent flagged as unmentioned-but-untracked: the `fdfind → ~/.local/bin/fd`
  shim and the generated `autostart.sh`/`~/.xinitrc` files. Both are
  either idempotent/inert or trivially regenerable/user-owned by explicit
  design (`install-suckless.sh` never overwrites `autostart.sh`/`.xinitrc`
  once they exist — see `CLAUDE.md` rule 6), so the risk/impact of leaving
  them untracked is materially lower than the two fixed above. Flagged
  here for a future session rather than expanding this one's scope
  further.
- Did not re-verify `install-fedora.sh` end-to-end on real Fedora hardware
  or in a disposable container — this remains the same pre-existing,
  previously-logged gap (`2026-08-04-fedora-arch-install-scripts-verify-fix.md`).
  This audit's fixes were verified via sandboxed `$HOME`/`XDG_STATE_HOME`
  testing, stub binaries, and the real `shellcheck`/`shfmt` toolchain —
  not a live Fedora run.

## Open Questions / Blockers
None. Post-implementation audit-loop: ✅ READY (Medium+ tier, 4 sweeps —
1 issue found/fixed, `uninstall.sh` over the 250-line cap, split into
`uninstall.sh` + new `uninstall_steps.sh`). Independent `reviewer`
subagent verdict: READY.

## Next Steps
- Next session that has network + a Fedora box/container available:
  run `install-fedora.sh` end-to-end for the first time, and separately
  confirm the GitHub Actions `lint`/`build-suckless`/`install-dry-run`
  jobs actually pass on a real push (they've now been verified locally
  with the exact pinned tool versions, but never run inside GitHub's
  runners).
- Consider tracking the `fd` shim and generated `autostart.sh`/`.xinitrc`
  in the manifest too, if full uninstall symmetry is ever wanted (see
  Trade-offs above) — not urgent given their idempotent/user-owned nature.
