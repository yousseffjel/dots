# Context — dynamic-scratchpads

## Background

Epic sub-task 11, added 2026-08-07 mid sub-task 3. Asked whether the existing
scratchpads should switch from st to alacritty, the user wanted a different
model entirely: *"i who put which window of what browser or terminal or
anything so i need keybind to put the selected window on scratchpads and key
for show it and hide it and one to drop window from scratchpads."*

That is **dynamic** assignment — take the focused window, whatever it is, and
stash it — not the current "spawn this pre-declared command as scratchpad N".

## Prior Decisions

- Scope file locked `dynamicscratchpads`; `namedscratchpads` is not in play.
- CLAUDE.md rule 5 — patches are vendored `.diff` files, applied at build time;
  do not hand-edit vendored sources for something a patch covers. This task is
  the documented exception: the merge target is 11 patches deep, so the change
  is made in-source and re-diffed, exactly as `PATCHES.md` records for
  `dwm-xresources-20260805-local.diff`.
- Sub-task 4 split keybinds between dwm and sxhkd. These three stay in dwm —
  they invoke C functions, so they have nowhere else to live.

## Research findings (verified this session)

1. **The two patches are genuinely mutually exclusive.** Current:
   `NUMTAGS (LENGTH(tags) + LENGTH(scratchpads))`, `SPTAG(i) ((1 <<
   LENGTH(tags)) << (i))`, `SPTAGMASK`, so 3 scratchpads occupy bits 9-11 and
   `TAGMASK` is `(1 << 12) - 1`. Upstream dynamicscratchpads defines
   `SCRATCHPAD_MASK (1u << sizeof tags / sizeof * tags)` — bit 9, the same bit
   `SPTAG(0)` claims. Confirmed from the upstream diff, not assumed.
2. **`pertag` is NOT affected** — contrary to the scope file's warning. Its
   arrays are sized `LENGTH(tags) + 1` (`dwm.c:342-343`), never `NUMTAGS`. The
   only consumers of `NUMTAGS` are `TAGMASK` itself (`dwm.c:58-59`).
3. **`hide_vacant_tags` is NOT affected either.** `drawbar` loops
   `i < LENGTH(tags)` (`dwm.c:1049`), so bit 9 is never drawn regardless of
   which patch owns it. The `occ |= c->tags == TAGMASK ? 0 : c->tags` line
   tests for "shown on all tags" and is indifferent to the scratchpad bit.
4. **`XK_minus` and `XK_equal` are free in BOTH dwm and sxhkd**, so the
   patch's default bindings work untouched and there is no double-grab
   hazard. `config/sxhkd/sxhkdrc` therefore needs no edit and is Forbidden.
5. **Two of the three current scratchpads are already dead keybinds.**
   `ranger` and `keepassxc` are absent from `packages/*.lst` (verified, not
   taken from the scope file). Only `spterm` works, because st is vendored.
6. **`patch -p1` will not apply.** The upstream diff is
   `dwm-scratchpad-20200727-bb2e7222…`, cut against dwm 6.2-era source; this
   tree is dwm 6.8 with 11 patches baked in. Same situation `PATCHES.md`
   documents for xresources — hand-merge, then re-diff against the pre-merge
   baseline.
7. **Upstream's `NumTags` guard changes `> 31` to `> 30`** to make room for
   the scratchpad bit. This tree currently has `> 31` (`dwm.c:350`).

## Footprint to remove

- `dwm.c` — 13 matches for `scratch|SPTAG|spcmd`: the 3 macros (58-61),
  `togglescratch` declaration (261) and body (2334-2356), and 3 uses in
  `applyrules` (380, 396) and `manage`-adjacent code (2180).
- `config.def.h` — `Sp` typedef (49-52), `spcmd1..3` (53-55),
  `scratchpads[]` (56-61), 3 `rules[]` entries (74-76), 3 keybinds (170-172).

## References

- `suckless/dwm/patches/PATCHES.md` — the local-diff convention and the
  reasoning for hand-merging rather than applying.
- Upstream page: `dwm.suckless.org/patches/dynamicscratchpads/`; diff
  `dwm-scratchpad-20200727-bb2e7222baeec7776930354d0e9f210cc2aaad5f.diff`.
  Adds `scratchpad_hide`, `scratchpad_show`, `scratchpad_show_client`,
  `scratchpad_show_first`, `scratchpad_remove`,
  `scratchpad_last_showed_is_killed`.

## Notes

Behaviour loss to document: `Mod+y` currently opens an st scratchpad terminal
and works. Under the new model you spawn a terminal normally and stash it with
`Mod+Shift+minus`. Worth calling out in KEYBINDINGS.md rather than letting it
be discovered.

This needs a **dwm rebuild** on existing installs — `rm -f suckless/dwm/config.h`
then `scripts/install-suckless.sh --skip-deps`, same as sub-task 7's scroll
bindings.
