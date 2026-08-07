# Review — alacritty-main-terminal

## Audit Loop

Tier: **Medium+** — 13 files, +365/-12 (new files included), full 4 sweeps.

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 2 found / 1 fixed. Fixed: `KEYBINDINGS.md` cited `conf.d/20-path.zsh`, deleted in sub-task 1. Deferred (outside `## Allowed`, owned by sub-task 9): `ROADMAP.md` still calls alacritty optional; `docs/THEMING.md`'s themed-app list omits it. Uninstall coverage confirmed automatic via `uninstall_steps.sh:14` → `manifest_rows CONFIG`. |
| 2 | Size/Performance | ✅ | 1 found / 0 fixed. `suckless/st/config.def.h` is 479 lines, over the 250-line cap — **pre-existing vendored upstream source**, delta here is 5 comment lines. Splitting it would break CLAUDE.md rule 5's patch workflow. Reported, not self-excepted. New files: 94 and 67 lines. |
| 3 | Types/Validation | ✅ | 0 found. TOML parses; alacritty 0.17 loads config + rendered palette with zero errors/warnings/unused keys; template renders with no leftover `<wallbash_*>`; `bash -n`/`shfmt -d`/`shellcheck -x` clean; dwm/dmenu/st compile warning-free; `st -e true` exits 0; fresh `HOME` with no `.cache` starts clean. |
| 4 | Dependencies | ✅ | 1 found / 0 fixed. `alacritty` sits in `extra.lst` (best-effort) — a failed install leaves `Mod+Shift+Return` dead. `packages/` is in `## Forbidden`; promoting to `core.lst` is a follow-up. Bounded by st remaining in `install-suckless.sh`'s `PROGRAMS`. |

**Audit verdict:** ✅ READY

## Test Gate

**Command:** `tests/lint.sh`, `tests/pkglist.sh`, `tests/build.sh`
(no `test_command` key, no `Makefile`/`package.json` — `tests/` mirrors the
three CI jobs in `.github/workflows/ci.yml` and has no single runner)

**Result:** ✅ PASSED — all three, exit 0.

- `lint.sh` — shellcheck ok, shfmt format check ok, markdownlint ok.
- `pkglist.sh` — name format ok, no intra-file duplicates, no core/extra overlap.
- `build.sh` — all five suckless programs built (dwm, st, dmenu, dwmblocks,
  slock), including the two this task did not touch.

Run in the slot worktree (`branch=slot/alacritty-main-terminal` confirmed
before invoking, after the main-vs-slot mix-up in an earlier sub-task).
Build artifacts do not dirty the tree: `suckless/*/.gitignore` already covers
`config.h`, `*.o` and the binaries. Verified afterwards that the in-repo
generated headers carry the new values, not just the scratch-copy builds used
during `/code`.

## Reviewer Gate
**Verdict:** READY (round 2)

**Notes:** Round 1 returned WARN — `README.md`, `alacritty.dcol` and
`alacritty.toml` all asserted as settled fact that `live_config_reload`
picks up the *imported* palette (the justification for having no step in
`reload.sh`), while this task's own `context.md` recorded that behaviour as
inferred rather than observed. The shipped docs had dropped the hedge,
overclaiming confidence on the core theming mechanism.

Resolved by rewriting all three comment blocks to separate what was actually
verified against alacritty 0.17.0 — a missing import is non-fatal (confirmed
with a `HOME` holding no `.cache` at all), and `~` expands to `$HOME` but
does not follow `$XDG_CACHE_HOME` — from what is assumed: the live reload of
the imported file. Each site now names the recognisable symptom if the
assumption is wrong (open terminals keep the stale palette after a wallpaper
change while newly-launched ones are correct) and the remedy (add an
explicit reload step). Re-validated after the edits: TOML parses, alacritty
0.17 loads cleanly, template renders with no leftover tokens.

Round 2: READY, no new issues introduced.
