# dynamic-scratchpads

Date: 2026-08-07
Files: 6 | Lines: +552/-264 (source only; +755/-267 incl. task folder + state)

Epic sub-task 11 of `.claude/tasks/scope-b-app-roster-finalization.md` — the
last implementation sub-task. Only 9 (docs) remains.

## What changed

- **The static `scratchpads` patch was un-baked from `dwm.c`**: `NUMTAGS`,
  `SPTAG`, `SPTAGMASK`, the `TAGMASK` redefinition, `togglescratch()` and its
  three call sites in `applyrules()` and `showhide()`. `TAGMASK` is back to
  vanilla `((1 << LENGTH(tags)) - 1)`.
- **And from `config.def.h`**: the `Sp` typedef, `spcmd1..3`, `scratchpads[]`,
  three `rules[]` entries and three keybinds (`Mod`+`y`/`u`/`x`).
- **`dynamicscratchpads` hand-merged in**: `SCRATCHPAD_MASK`, the static
  `scratchpad_last_showed` cursor, six functions, the `NumTags` guard moved
  from `> 31` to `> 30`, an `applyrules()` guard so a stashed client keeps its
  mask, and a cursor reset in `unmanage()`.
- **New keybinds**: `Mod`+`Shift`+`-` stash the focused window, `Mod`+`-`
  show/hide and cycle, `Mod`+`=` drop out of the set.
- **`suckless/dwm/patches/`**: `dwm-scratchpads-20200414-728d397b.diff`
  deleted, `dwm-dynamicscratchpads-20260807-local.diff` added (292 lines),
  `PATCHES.md` gained a full entry for it.
- **`KEYBINDINGS.md`**: rewritten Scratchpads section, the removed bindings,
  two inherited behaviours, and the rebuild note.

## Why

The user asked for dynamic assignment — *"i need keybind to put the selected
window on scratchpads and key for show it and hide it and one to drop window
from scratchpads"* — rather than the old model of spawning pre-declared
commands as scratchpad N.

The two patches cannot coexist: the old defined
`SPTAG(i) ((1 << LENGTH(tags)) << (i))` and the new defines
`SCRATCHPAD_MASK (1u << LENGTH(tags))`, so both claim bit `LENGTH(tags)` of
the tag bitmask. Hence a swap, and hence a single diff that removes as much as
it adds.

Two of the three old scratchpads were already dead keys: neither `ranger` nor
`keepassxc` is in `packages/*.lst`. Only `Mod`+`y` (an `st` terminal) worked,
because st is vendored — that is the one real capability lost, and
`KEYBINDINGS.md` says so rather than leaving it to be discovered.

## Assumptions

- **(Type C) The scope file's risk assessment was verified, not trusted, and
  two of its three warnings did not hold.** It says the swap "must be checked
  against `pertag` and `hide_vacant_tags`, both of which read the tag bitmask
  the current patch steals from." `pertag` does not — its arrays are sized
  `LENGTH(tags) + 1`, never `NUMTAGS`, so removing that macro touches nothing
  there. `hide_vacant_tags` does not either — `drawbar()` loops
  `i < LENGTH(tags)`, so the scratchpad bit is never drawn whichever patch
  owns it. The third warning (that `patch -p1` will not apply) was correct.
- **(Type C) `XK_minus` and `XK_equal` were free in both dwm and sxhkd**, so
  upstream's default bindings were kept as-is and `config/sxhkd/sxhkdrc`
  needed no edit — it stayed in the plan's Forbidden list. Checked because
  dwm and sxhkd both `XGrabKey` and a doubly-bound key dies silently.
- **(Type B) Four deliberate deviations from upstream**, all recorded in
  `PATCHES.md`: `(const Arg *)` signatures instead of upstream's empty
  parameter lists (dwm's `Key` struct needs that prototype, and relying on
  pre-C99 function-pointer compatibility under `-pedantic` is not worth it);
  `int` instead of `_Bool`; dwm house style instead of the author's
  `selmon -> sel` spacing, so future patches' diff context still matches; and
  `LENGTH(tags)` instead of `sizeof tags / sizeof * tags`.

## Trade-offs

**Two inherited behaviours documented rather than fixed.** Stashing sets the
window floating and nothing restores that, so a tiled window comes back
floating; and the cycle scans only the current monitor's client list, so a
window stashed on one monitor is not reachable from another. Both are upstream
semantics. Changing either means diverging further from a patch that is
already hand-merged, which raises the cost of any future re-vendor — not worth
it for behaviour that is reasonable once known. Both are in `KEYBINDINGS.md`.

**The audit caught two errors, both mine, both descriptions of control flow
rather than the flow itself.** An inline comment claimed the second branch of
`scratchpad_show()` re-shows a stashed window when it does the opposite —
stashing one that is currently visible, which is precisely what makes one key
both show and hide. And `KEYBINDINGS.md` said press-again cycles when
press-again hides and only a third press advances. Fixed, and the vendored
diff regenerated and round-trip re-verified afterwards.

## Test coverage

- `tests/lint.sh`, `tests/pkglist.sh`, `tests/picom-lockstep.sh`,
  `tests/build.sh` — all exit 0. The last two run as regression checks.
- **`build.sh` run after `rm -f suckless/dwm/config.h`.** That file is
  gitignored and generated once, so a stale copy would have compiled the old
  keybinds and passed; forcing regeneration is what makes the build prove the
  edited `config.def.h` compiled. All five programs build with **zero errors
  and zero warnings** under `-std=c99 -pedantic -Wall`.
- **Symbol check on the linked binary** (`nm suckless/dwm/dwm`):
  `scratchpad_hide`, `scratchpad_show`, `scratchpad_show_client`,
  `scratchpad_show_first`, `scratchpad_remove` and the static
  `scratchpad_last_showed` all present; `togglescratch` **absent**. The old
  patch is gone from the artifact, not merely from the source — which a green
  `make` alone would not show. `scratchpad_last_showed_is_killed` does not
  appear, having been inlined at `-Os`.
- **Round-trip on the vendored diff:** applying
  `dwm-dynamicscratchpads-20260807-local.diff` to the pre-merge baseline
  reproduces `dwm.c` and `config.def.h` byte-for-byte. Re-verified after the
  audit fix. This matters more than usual — the diff is the only record of the
  swap that survives a re-vendor.
- **Tag arithmetic verified numerically**, with a standalone program rather
  than by reasoning: `TAGMASK` 0x1FF, `SCRATCHPAD_MASK` 0x200, overlap 0x000,
  `NumTags` guard passes, `drawbar`'s loop stops one index short of the bit.
- **All 23 `free()` calls in `dwm.c` traced.** Only three take a `Client *`:
  `unmanage()` (guarded), a freshly `calloc`'d systray icon never linked into
  the client list, and an icon removed from `systray->icons`. Icons are never
  in `selmon->clients` and never focusable, so neither can be the cursor.

**Not covered:** nothing has run in a live dwm. Stash / show / hide / cycle /
drop, and the runtime interaction with pertag and hide_vacant_tags, are
verified by construction, symbol presence and tag arithmetic only — not by
pressing the keys.

## Follow-ups

- **Needs a dwm rebuild on existing installs**: `rm -f suckless/dwm/config.h`
  then `scripts/install-suckless.sh --skip-deps`. Same dance as sub-task 7's
  scroll bindings. Documented inline in `KEYBINDINGS.md`.
- **`Mod`+`y`, `Mod`+`u` and `Mod`+`x` are now unbound** and free to reuse.
- **Verify on real hardware**: that the three keys are actually grabbed
  (`xev`), that stashing and cycling behave as documented, and that a stashed
  window really is invisible to every tag view.
- **Closes a follow-up from sub-task 4** — `KEYBINDINGS.md` still listed the
  `st -n spterm` / ranger / keepassxc scratchpads.
- **`CLAUDE.md`'s patch roster still names `scratchpads`** in its
  "Already done" list. Sub-task 9 owns that reconciliation, along with the
  five others queued for it.
