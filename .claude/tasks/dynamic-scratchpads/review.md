# Review — dynamic-scratchpads

## Audit Loop

Tier: **Medium+** (11 files, +690/-267 — `git add -N` first, since
`--shortstat` does not count untracked files). Sweeps run strictly 1 → 2 → 3 → 4.

| Sweep | Focus | Status | Findings |
|-------|-------|--------|----------|
| 1 | Architecture | ✅ | 0. No Forbidden path touched. The hand-edit is captured as `dwm-dynamicscratchpads-20260807-local.diff` per CLAUDE.md rule 5, and applying it to the pre-merge baseline reproduces both files byte-for-byte. A `scratchpad` hit in `config/sxhkd/sxhkdrc` turned out to be a comment describing what dwm owns, not a binding — so no dwm/sxhkd double-grab. |
| 2 | Size/Performance | ✅ | 0. Six new functions, largest 32 lines against the 60 cap. `dwm.c` 3044 → 3122. The 250-line file cap governs project-authored source, not the vendored suckless tree. |
| 3 | Types/Validation | ✅ | **2 found, 2 fixed — both mine, both about control flow being described wrongly.** (a) The inline comment on the second branch of `scratchpad_show()` said "the cursor names a window that is stashed again — re-show it"; the branch does the opposite, stashing a window that is currently showing. (b) `KEYBINDINGS.md` said `Mod`+`-` "brings back a stashed window; press again to cycle" — press-again *hides* it, and only a third press advances. Both corrected and the local diff regenerated, round-trip re-verified. Separately traced all 23 `free()` calls in `dwm.c`: the only ones taking a `Client *` are `unmanage()` (guarded) and two systray paths — one a freshly `calloc`'d icon never linked into the client list, one an icon from `systray->icons`. Icons are never in `selmon->clients` and never focusable, so neither can be `scratchpad_last_showed`. |
| 4 | Dependencies | ✅ | 0. `#include` set identical to the baseline, `LIBS` unchanged, all six declared symbols defined exactly once. `-std=c99 -pedantic -Wall` compiles with zero warnings. |

**Audit verdict:** ✅ READY

## Test Gate
**Command:** `bash tests/lint.sh && bash tests/pkglist.sh && bash tests/picom-lockstep.sh && bash tests/build.sh`
(repo convention — no config.yml, package.json or Makefile at the root)
**Result:** ✅ PASSED — all four exit 0.

- lint clean (shellcheck/shfmt/markdownlint); pkglist valid; picom lockstep
  still verified (untouched by this task, run as a regression check).
- `tests/build.sh` run after `rm -f suckless/dwm/config.h`, so `config.h` was
  regenerated from the edited `config.def.h` rather than reusing a stale copy:
  **all five suckless programs build with zero errors and zero warnings** under
  `-std=c99 -pedantic -Wall`, and the regenerated `config.h` carries the three
  new keybinds.
- **Symbol-level check on the linked binary** (`nm suckless/dwm/dwm`):
  `scratchpad_hide`, `scratchpad_show`, `scratchpad_show_client`,
  `scratchpad_show_first`, `scratchpad_remove` and the static
  `scratchpad_last_showed` are all present, and `togglescratch` is absent —
  so the old patch is gone from the artifact, not merely from the source.
  `scratchpad_last_showed_is_killed` does not appear; it was inlined by `-Os`,
  which is expected for a small static called from one site.
- **Round-trip check on the vendored diff:** applying
  `dwm-dynamicscratchpads-20260807-local.diff` to the pre-merge baseline
  reproduces `dwm.c` and `config.def.h` byte-for-byte. Re-verified after the
  audit's comment fix.
- **Tag arithmetic verified numerically** with a standalone program rather
  than reasoned about: `TAGMASK` 0x1FF, `SCRATCHPAD_MASK` 0x200, overlap
  0x000, `NumTags` guard passes, and `drawbar`'s loop stops one index short of
  the scratchpad bit.

**Not covered:** nothing has run in a live dwm. Stash / show / hide / cycle /
drop behaviour, and the interaction with pertag and hide_vacant_tags at
runtime, are verified by construction, symbol presence and tag maths only —
not by pressing the keys.

## Reviewer Gate
**Verdict:** READY
**Notes:** Clean first round, no issues raised. Pointed at the five things most
worth doubting on a C patch swap: whether the un-baking missed a site or broke
a patch that depended on it (specifically whether restoring vanilla `TAGMASK`
is safe given pertag and hide_vacant_tags), whether `scratchpad_last_showed`
can dangle, whether the captured diff is faithful enough to reproduce the tree
from a fresh vendored dwm, whether `scratchpad_show()`'s control flow matches
what KEYBINDINGS.md claims, and whether any behaviour was silently lost.
