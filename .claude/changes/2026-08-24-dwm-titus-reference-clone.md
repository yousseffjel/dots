# dwm-titus-reference-clone

## Session Date
2026-08-24

## Context
The user cloned `ChrisTitusTech/dwm-titus` into the repo root and asked for it
to be scanned, documented in `CLAUDE.md`, and assessed for what dots can take
from it. It is the closest external project to this one — Fedora-only, X11,
dwm, bash installer — so it is a far more direct comparison source than the
existing `HyDE/` clone (Arch + Hyprland + Wayland).

## What Was Requested
"i found a project that kind of what i want to build i want you to scan it (add
it to the Claude.md) and tell me what we can take from it" — repo
<https://github.com/ChrisTitusTech/dwm-titus>, docs <https://dwm.christitus.com>.

## What Was Implemented or Decided

**1. The clone is sanctioned as a second reference clone, on the HyDE precedent.**
A new `## Reference clones` section in `CLAUDE.md` covers both, and rule 9 was
widened from `HyDE/` alone to both clones. The dwm-titus entry records HEAD
(`e1f884e`, cloned 2026-08-24), the four structural differences that make its
code non-liftable (hard fork instead of vendored `.diff` patches; TOML runtime
config parsed by a linked-in `tomlparser.c`; a Quickshell/Qt6 shell layer; an
ISO/kickstart flow), the six places it is genuinely ahead, and the four where
dots is. It deliberately carries **no file or test enumerations** — it points
at `ls dwm-titus/tests/*.sh` and `grep '^check-' dwm-titus/Makefile` instead.

**2. Placing the clone in the repo root silently broke three lint paths.**
`HyDE/` had been excluded in four separate places; the new clone was in none of
them, and unlike HyDE it has root-level shell and markdown files, so it was
actually picked up rather than merely at risk:

- `.gitignore` — the clone was untracked and would have been committed.
- `.markdownlintignore` — `tests/lint.sh` globs `**/*.md`; the clone's ~30
  markdown files entered the local lint set.
- `.pre-commit-config.yaml` — its markdownlint `exclude:` regex is a second,
  hand-maintained copy of `.markdownlintignore`; same exposure.
- `tests/lint.sh` — `find . -maxdepth 2 -name '*.sh'` reached
  `dwm-titus/install.sh` (775 lines, foreign style). **Verified before the fix**:
  the file was in the lint set. HyDE escaped this for a year only because it
  happens to ship no root-level `*.sh`.

The `lint.sh` fix does not add a second directory name. It pipes the find
through `git check-ignore --stdin --non-matching --verbose`, so `.gitignore`
stays the single declaration of "not ours" and a third clone needs no edit
there.

## Files Modified
- `CLAUDE.md` — new `## Reference clones` section; project map gains
  `dwm-titus/`; rule 9 widened to both clones.
- `.gitignore` — `dwm-titus/` block, mirroring the `HyDE/` one.
- `.markdownlintignore` — `dwm-titus/` added.
- `.pre-commit-config.yaml` — `dwm-titus/` added to the markdownlint exclude regex.
- `tests/lint.sh` — shell-file discovery now filters `.gitignore`d paths via
  `git check-ignore`.
- `.github/workflows/ci.yml` — the comment above the lint step named `HyDE/`
  specifically; reworded to describe the mechanism instead of naming clones.
- `.claude/changes/2026-08-24-dwm-titus-reference-clone.md` — this log.

## Key Technical Decisions

1. **Fix `lint.sh` by deletion, not by extension.** Adding `-not -path
   './dwm-titus/*'` would have been one line, and would have been the third
   hand-written copy of the same list. `git check-ignore` reads `.gitignore`
   back instead. This is the same "delete the copy, don't extend it" move the
   repo has now made for daemon lists, package lists and the `dots` subcommand
   table.
2. **`|| true` around `git check-ignore`.** It exits 1 when *no* input path is
   ignored — the normal state on a machine with neither clone — and `set -o
   pipefail` would have turned that into an empty file list. Tested both ways
   (see Verification).
3. **`.markdownlintignore` / `.pre-commit-config.yaml` duplication was extended,
   not removed.** markdownlint-cli's `--ignore-path` would collapse the two into
   one, but `pre-commit` is not installed on this host, so the behaviour change
   could not be verified. Filed as a follow-up rather than shipped unproven.
4. **No dwm-titus content was copied into this repo.** Rule 9 makes the clone
   read-only; the CLAUDE.md section describes it and cites paths inside it, but
   nothing was lifted.

## Assumptions Made
- **Type C** — the new clone should be governed exactly as `HyDE/` is
  (untracked, gitignored, lint-excluded, never referenced from a script). Every
  site touched was found by grepping for existing `HyDE` references outside
  `.claude/` and the docs, so the treatment is derived from the precedent rather
  than invented.
- **Type B** — fixing the three lint regressions is in scope even though the
  request was "scan and document". Documenting the clone as sanctioned while
  leaving `tests/lint.sh` red on it would have shipped a known break. The
  alternative — report and stop — was rejected because the break is caused by
  the very act being documented.

## Trade-offs
- `tests/lint.sh` now depends on `git` at lint time. It is in `core.lst` (the
  hard-fail tier) and the script only ever runs inside a checkout, so this costs
  nothing real. If git were somehow absent, the existing empty-list guard fires
  red — loudly, though its message would misattribute the cause to the `find`.
- `CLAUDE.md` grew 201 → 274 lines. It is a context document, not a source file,
  so `file-architecture.md`'s 250-line cap does not apply (its hooks scan `src/`
  for `.ts`/`.tsx`). But it is loaded into every session, so the growth is a real
  recurring cost — noted, not acted on.

## Verification
- `bash tests/lint.sh` — **green** (shellcheck ok, shfmt ok, markdownlint ok).
  Ran red first on shfmt and was corrected with the repo's own
  `shfmt -i 4 -ci -bn -w`.
- The discovery fix was proven against both cases rather than reasoned about:
  with the clone present the list is **38 paths and contains no clone file**
  (39 including `dwm-titus/install.sh` before the change); in a scratch git repo
  with **no `.gitignore` at all** — the case where `git check-ignore` exits 1 —
  it returns **2 of 2** files rather than zero.
- Both YAML files re-parsed after editing (`yaml.safe_load`).
- No other test reads any changed file; the four that mention `CLAUDE.md` do so
  only in header prose.
- Audit: Medium+ tier (6 files / 97 lines), 4 sweeps, **✅ READY**. Three
  findings, all fixed during the sweep (the markdownlint, pre-commit and
  `lint.sh` exposures); two flags carried to Next Steps.
- **Reviewer gate not run** — this session's operating instructions forbid
  spawning subagents unless the user asks. Surfaced to the user rather than
  self-excepted or silently skipped.

## Open Questions / Blockers
- Reviewer gate is unrun by instruction conflict (above). The user can authorise
  it in one word.
- Nothing in the harvest list has been chosen yet — the assessment is delivered,
  the queue is not updated.

## Next Steps
1. **Decide which dwm-titus ideas to queue.** The three highest-value, ranked in
   chat: an Xvfb runtime test for dwm (dots has never executed dwm in a test);
   a staged `DESTDIR` install/uninstall symmetry check for the manifest; and
   CI installing dependencies by reading `packages/*.lst` rather than restating
   names. Only after that should `MASTER_PLAN.md` change.
2. **Collapse the markdownlint ignore duplication.** `.markdownlintignore` and
   `.pre-commit-config.yaml`'s `exclude:` regex are two copies of one list.
   Switching the hook to `--ignore-path .markdownlintignore` would leave one —
   needs `pre-commit` installed to verify.
3. Existing queue items are untouched: the `@resurrect-dir` XDG bug, the
   first-CI-run watch, and the still-never-done real-hardware install run.
