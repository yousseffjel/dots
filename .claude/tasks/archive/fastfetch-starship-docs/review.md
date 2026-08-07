# Review — fastfetch-starship-docs

## Audit Loop

Tier: **Medium+** (16 files, +881/-88 at audit time) — full four sweeps.

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 0. Every Forbidden path verified untouched (`symlinks.sh`, `config/picom`, `config/dunst`, `packages/*.lst`, `suckless/`). No `config/fastfetch/` exists, and `symlinks.sh` has no fastfetch entry — the two invariants the template-only design depends on. Every file path and function name introduced in the docs was checked to resolve. |
| 2 | Size/Performance | ✅ | 1 found, 1 fixed. `tests/theme-templates.sh` reached **294 lines**, over the 250 cap, and it was the only shell script in the repo over it (next largest 246) — so no precedent for an exception. Split into `tests/starship-template.sh` (202) and `tests/fastfetch-template.sh` (203), duplicating a short harness, which is the same convention CLAUDE.md rule 2 sets for colour helpers. All 8 mutants re-verified after the split. Markdown over 250 (`THEMING.md` 333, `ROADMAP.md` 392) is long-standing repo precedent (`KEYBINDINGS.md` 422) and was left alone. |
| 3 | Types/Validation | ✅ | 0. `tests/lint.sh` clean (shellcheck + shfmt + markdownlint). `theme_claim_fastfetch` returns before any mutation under `DRY_RUN`, and is called before `theme_backup_preexisting`, so a pre-existing config is preserved before the template can overwrite it. |
| 4 | Dependencies | ✅ | 1 found, 1 fixed. The starship assertion counted warning lines but ignored exit status, so a `starship` that died silently was a **false pass** — proved by shimming it with `exit 127`. Now checks both; the shim is caught. Templates add no runtime dependency beyond coreutils; `starship`/`fastfetch`/`python3` in the tests are all `command -v` guarded and degrade to `skip`. |

**Audit verdict:** ✅ READY

## Test Gate
**Command:** `for t in tests/*.sh; do bash "$t"; done` (auto-detected — the
suite CI itself globs; no `config.yml`/`package.json`/`Makefile` target exists)
**Result:** ✅ PASSED — 6/6 scripts

| Script | Result |
|---|---|
| `build.sh` | pass — all five suckless programs, after `rm -f suckless/*/config.h` |
| `lint.sh` | pass — shellcheck + shfmt + markdownlint |
| `pkglist.sh` | pass |
| `picom-lockstep.sh` | pass — regression check, untouched by this task |
| `starship-template.sh` | pass — 7 assertions, 0 skipped |
| `fastfetch-template.sh` | pass — 9 assertions, 0 skipped |

`config.h` was deleted before `build.sh` so the build could not pass on a
stale generated header. This task changed no C, so that run is a pure
regression check.

## Reviewer Gate
**Verdict:** READY
**Notes:** Clean on the first round, no issues raised. The reviewer was
explicitly pointed at the documentation claims as the main risk in this task
(a confidently-worded but false statement in CLAUDE.md / ROADMAP.md /
THEMING.md) as well as at whether the two new tests would actually fail if
what they test broke. It confirmed the 250-line cap and the 60-line function
cap across the diff. Two issues had already been found and fixed by the audit
loop before this gate ran — the oversized test file and the starship
false-pass on exit status.

## Verification notes

- **16 assertions** across the two template tests, **8 mutants all caught**
  (wrong placeholder, broken sed range, removed marker guard, deleted palette
  table, unknown fastfetch module, unknown placeholder, malformed JSON,
  removed engine install-check).
- The engine install-check mutant was **initially not caught** — the assertion
  checked only that no file appeared, which is equally true when the engine
  errors as when it skips. Tightened to assert on the skip message.
- `starship.toml` refactor proved **byte-identical** across five prompt
  surfaces (plain dir ok/err, git repo with staged+modified+untracked, and
  both left and right prompts with a marker file for every kept language),
  with a cold `STARSHIP_CACHE`.
- `dunst` held PID 1704 across every engine invocation in this task.
- Full suite green: lint, pkglist, picom-lockstep, starship-template,
  fastfetch-template, build (after `rm -f suckless/*/config.h`).

## Not verified

- Nothing ran on a real Fedora box, and no wallpaper change was performed on
  the live desktop. The engine was only ever run against throwaway trees
  holding a single template.
- The rendered prompt and fetch output were checked on **Arch**, so the
  fastfetch `packages`/`wm` lines and the Fedora logo path are inferred for
  the target, not observed.
